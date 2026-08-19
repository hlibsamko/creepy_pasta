from __future__ import annotations

import hmac
import sqlite3
import time
import urllib.parse
import uuid
from dataclasses import dataclass
from typing import Any, Callable

from .config import Config
from .db import Database
from .google import (
    GOOGLE_AUTHORIZATION_ENDPOINT,
    CodeExchanger,
    GoogleAuthError,
    GoogleCodeExchanger,
    GoogleIdTokenVerifier,
    GoogleIdentity,
    IdTokenVerifier,
)
from .security import (
    TOKEN_RE,
    canonical_pair,
    pkce_challenge,
    pkce_verifier,
    random_friend_code,
    random_token,
    random_uuid,
    token_hash,
    valid_achievement_code,
    valid_event_id,
    valid_friend_code,
)


class ApiError(RuntimeError):
    def __init__(self, status: int, code: str, message: str | None = None) -> None:
        super().__init__(message or code)
        self.status = status
        self.code = code
        self.message = message or code.replace("_", " ")


@dataclass(frozen=True, slots=True)
class AuthContext:
    session_id: str
    user_id: str


def _default_clock() -> int:
    return int(time.time())


def _valid_uuid(value: object) -> str | None:
    if not isinstance(value, str) or len(value) != 36:
        return None
    try:
        parsed = uuid.UUID(value)
    except ValueError:
        return None
    normalized = str(parsed)
    return normalized if value == normalized else None


class AccountService:
    def __init__(
        self,
        config: Config,
        database: Database | None = None,
        exchanger: CodeExchanger | None = None,
        verifier: IdTokenVerifier | None = None,
        clock: Callable[[], int] = _default_clock,
    ) -> None:
        self.config = config
        self.db = database or Database(config.db_path)
        self.clock = clock
        self.db.initialize()
        if exchanger is not None:
            self.exchanger = exchanger
        elif config.google_client_id and config.google_client_secret:
            self.exchanger = GoogleCodeExchanger(
                config.google_client_id,
                config.google_client_secret,
                config.google_http_timeout_seconds,
            )
        else:
            self.exchanger = None
        self.verifier = verifier or GoogleIdTokenVerifier(config.google_http_timeout_seconds)

    def readiness(self) -> tuple[bool, dict[str, Any]]:
        if not self.db.is_ready():
            return False, {"status": "database_unavailable"}
        missing = list(self.config.missing_setup)
        if missing:
            return False, {"status": "setup_pending", "missing": missing}
        return True, {"status": "ready"}

    def _require_google_setup(self) -> tuple[str, CodeExchanger]:
        if self.config.missing_setup or self.exchanger is None or not self.config.google_client_id:
            raise ApiError(503, "setup_pending", "Google authentication is not configured")
        return self.config.google_client_id, self.exchanger

    def start_google_login(self) -> dict[str, Any]:
        client_id, _ = self._require_google_setup()
        now = self.clock()
        login_id = random_uuid()
        state = random_token("cps")
        poll_token = random_token("cpp")
        nonce = random_token("cpn")
        verifier = pkce_verifier()
        expires_at = now + self.config.login_ttl_seconds
        with self.db.transaction() as connection:
            connection.execute(
                "DELETE FROM oauth_login_attempts WHERE expires_at < ?",
                (now - 24 * 60 * 60,),
            )
            connection.execute(
                """
                INSERT INTO oauth_login_attempts(
                    id, state_hash, poll_token_hash, nonce, code_verifier, status,
                    created_at, expires_at
                ) VALUES (?, ?, ?, ?, ?, 'pending', ?, ?)
                """,
                (
                    login_id,
                    token_hash(state),
                    token_hash(poll_token),
                    nonce,
                    verifier,
                    now,
                    expires_at,
                ),
            )
        query = urllib.parse.urlencode(
            {
                "client_id": client_id,
                "redirect_uri": self.config.google_callback_url,
                "response_type": "code",
                "scope": "openid email profile",
                "state": state,
                "nonce": nonce,
                "code_challenge": pkce_challenge(verifier),
                "code_challenge_method": "S256",
                "access_type": "online",
                "include_granted_scopes": "false",
            },
            quote_via=urllib.parse.quote,
        )
        return {
            "login_id": login_id,
            "poll_token": poll_token,
            "authorization_url": f"{GOOGLE_AUTHORIZATION_ENDPOINT}?{query}",
            "expires_in": self.config.login_ttl_seconds,
        }

    def _claim_login_state(self, state: str) -> sqlite3.Row:
        if not isinstance(state, str) or not 32 <= len(state) <= 512:
            raise ApiError(400, "invalid_login_state")
        now = self.clock()
        state_digest = token_hash(state)
        with self.db.transaction() as connection:
            cursor = connection.execute(
                """
                UPDATE oauth_login_attempts
                SET status = 'exchanging'
                WHERE state_hash = ? AND status = 'pending' AND expires_at > ?
                """,
                (state_digest, now),
            )
            if cursor.rowcount != 1:
                raise ApiError(400, "invalid_login_state")
            row = connection.execute(
                "SELECT * FROM oauth_login_attempts WHERE state_hash = ?",
                (state_digest,),
            ).fetchone()
            if row is None:
                raise ApiError(400, "invalid_login_state")
            return row

    def fail_google_callback(self, state: str, provider_error: str) -> None:
        row = self._claim_login_state(state)
        safe_error = "access_denied" if provider_error == "access_denied" else "provider_error"
        now = self.clock()
        with self.db.transaction() as connection:
            connection.execute(
                """
                UPDATE oauth_login_attempts
                SET status = 'failed', error_code = ?, completed_at = ?
                WHERE id = ? AND status = 'exchanging'
                """,
                (safe_error, now, row["id"]),
            )

    def complete_google_callback(self, state: str, code: str) -> None:
        client_id, exchanger = self._require_google_setup()
        if not isinstance(code, str) or not 8 <= len(code) <= 4096:
            raise ApiError(400, "invalid_authorization_code")
        row = self._claim_login_state(state)
        try:
            id_token = exchanger.exchange(code, self.config.google_callback_url, row["code_verifier"])
            identity = self.verifier.verify(id_token, client_id, row["nonce"], self.clock())
        except GoogleAuthError as exc:
            with self.db.transaction() as connection:
                connection.execute(
                    """
                    UPDATE oauth_login_attempts
                    SET status = 'failed', error_code = 'verification_failed', completed_at = ?
                    WHERE id = ? AND status = 'exchanging'
                    """,
                    (self.clock(), row["id"]),
                )
            raise ApiError(400, "authentication_failed", "Google authentication failed") from exc
        self._complete_login_identity(row["id"], identity)

    def _complete_login_identity(self, login_id: str, identity: GoogleIdentity) -> None:
        now = self.clock()
        account_disabled = False
        with self.db.transaction() as connection:
            existing = connection.execute(
                """
                SELECT i.user_id, u.status
                FROM oauth_identities i
                JOIN users u ON u.id = i.user_id
                WHERE i.provider = 'google' AND i.provider_subject = ?
                """,
                (identity.subject,),
            ).fetchone()
            if existing is not None:
                if existing["status"] != "active":
                    connection.execute(
                        """
                        UPDATE oauth_login_attempts
                        SET status = 'failed', error_code = 'account_disabled', completed_at = ?
                        WHERE id = ? AND status = 'exchanging'
                        """,
                        (now, login_id),
                    )
                    account_disabled = True
                    user_id = existing["user_id"]
                else:
                    user_id = existing["user_id"]
                    connection.execute(
                        """
                        UPDATE users
                        SET display_name = ?, avatar_url = ?, updated_at = ?, last_login_at = ?
                        WHERE id = ?
                        """,
                        (identity.display_name, identity.avatar_url, now, now, user_id),
                    )
                    connection.execute(
                        """
                        UPDATE oauth_identities
                        SET email_snapshot = ?, email_verified = 1, last_login_at = ?
                        WHERE provider = 'google' AND provider_subject = ?
                        """,
                        (identity.email, now, identity.subject),
                    )
            else:
                user_id = random_uuid()
                for _ in range(8):
                    friend_code = random_friend_code()
                    try:
                        connection.execute(
                            """
                            INSERT INTO users(
                                id, display_name, avatar_url, friend_code, status,
                                created_at, updated_at, last_login_at
                            ) VALUES (?, ?, ?, ?, 'active', ?, ?, ?)
                            """,
                            (
                                user_id,
                                identity.display_name,
                                identity.avatar_url,
                                friend_code,
                                now,
                                now,
                                now,
                            ),
                        )
                    except sqlite3.IntegrityError:
                        continue
                    break
                else:
                    raise RuntimeError("could not allocate a unique friend code")
                connection.execute(
                    """
                    INSERT INTO oauth_identities(
                        provider, provider_subject, user_id, email_snapshot,
                        email_verified, created_at, last_login_at
                    ) VALUES ('google', ?, ?, ?, 1, ?, ?)
                    """,
                    (identity.subject, user_id, identity.email, now, now),
                )
                connection.execute(
                    """
                    INSERT INTO player_stats(user_id, verified_playtime_seconds, death_count, updated_at)
                    VALUES (?, 0, 0, ?)
                    """,
                    (user_id, now),
                )
            if not account_disabled:
                cursor = connection.execute(
                    """
                    UPDATE oauth_login_attempts
                    SET status = 'complete', user_id = ?, completed_at = ?, error_code = NULL
                    WHERE id = ? AND status = 'exchanging'
                    """,
                    (user_id, now, login_id),
                )
                if cursor.rowcount != 1:
                    raise ApiError(409, "login_already_completed")
        if account_disabled:
            raise ApiError(403, "account_disabled")

    def _insert_auth_session(
        self,
        connection: sqlite3.Connection,
        user_id: str,
        now: int,
        family_id: str | None = None,
    ) -> tuple[dict[str, Any], str]:
        session_id = random_uuid()
        family = family_id or random_uuid()
        access_token = random_token("cpa")
        refresh_token = random_token("cpr")
        connection.execute(
            """
            INSERT INTO auth_sessions(
                id, user_id, access_token_hash, refresh_token_hash,
                access_expires_at, refresh_expires_at, token_family_id,
                created_at, last_used_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            (
                session_id,
                user_id,
                token_hash(access_token),
                token_hash(refresh_token),
                now + self.config.access_ttl_seconds,
                now + self.config.refresh_ttl_seconds,
                family,
                now,
                now,
            ),
        )
        payload = {
            "access_token": access_token,
            "access_expires_in": self.config.access_ttl_seconds,
            "refresh_token": refresh_token,
            "refresh_expires_in": self.config.refresh_ttl_seconds,
        }
        return payload, session_id

    def poll_google_login(self, login_id: object, poll_token: object) -> tuple[int, dict[str, Any]]:
        valid_login_id = _valid_uuid(login_id)
        if valid_login_id is None or not isinstance(poll_token, str) or not TOKEN_RE.fullmatch(poll_token):
            raise ApiError(400, "invalid_login_poll")
        now = self.clock()
        with self.db.transaction() as connection:
            row = connection.execute(
                "SELECT * FROM oauth_login_attempts WHERE id = ?",
                (valid_login_id,),
            ).fetchone()
            if row is None or not hmac.compare_digest(row["poll_token_hash"], token_hash(poll_token)):
                raise ApiError(404, "login_not_found")
            if row["expires_at"] <= now:
                if row["status"] in {"pending", "exchanging"}:
                    connection.execute(
                        """
                        UPDATE oauth_login_attempts
                        SET status = 'failed', error_code = 'expired', completed_at = ?
                        WHERE id = ?
                        """,
                        (now, valid_login_id),
                    )
                raise ApiError(410, "login_expired")
            if row["consumed_at"] is not None:
                raise ApiError(410, "login_consumed")
            if row["status"] in {"pending", "exchanging"}:
                return 202, {"status": "pending"}
            if row["status"] == "failed":
                raise ApiError(400, "authentication_failed", "Google authentication failed")
            if row["status"] != "complete" or row["user_id"] is None:
                raise ApiError(409, "invalid_login_status")
            token_payload, _ = self._insert_auth_session(connection, row["user_id"], now)
            cursor = connection.execute(
                "UPDATE oauth_login_attempts SET consumed_at = ? WHERE id = ? AND consumed_at IS NULL",
                (now, valid_login_id),
            )
            if cursor.rowcount != 1:
                raise ApiError(410, "login_consumed")
            user = self._user_by_id(connection, row["user_id"], include_email=True)
            return 200, {"status": "complete", **token_payload, "user": user}

    def authenticate(self, access_token: object) -> AuthContext:
        if not isinstance(access_token, str) or not TOKEN_RE.fullmatch(access_token) or not access_token.startswith("cpa_"):
            raise ApiError(401, "invalid_access_token")
        now = self.clock()
        with self.db.transaction() as connection:
            row = connection.execute(
                """
                SELECT s.id, s.user_id, s.access_expires_at, s.revoked_at, u.status
                FROM auth_sessions s
                JOIN users u ON u.id = s.user_id
                WHERE s.access_token_hash = ?
                """,
                (token_hash(access_token),),
            ).fetchone()
            if (
                row is None
                or row["revoked_at"] is not None
                or row["access_expires_at"] <= now
                or row["status"] != "active"
            ):
                raise ApiError(401, "invalid_access_token")
            connection.execute(
                "UPDATE auth_sessions SET last_used_at = ? WHERE id = ?",
                (now, row["id"]),
            )
            return AuthContext(session_id=row["id"], user_id=row["user_id"])

    def refresh_session(self, refresh_token: object) -> dict[str, Any]:
        if not isinstance(refresh_token, str) or not TOKEN_RE.fullmatch(refresh_token) or not refresh_token.startswith("cpr_"):
            raise ApiError(401, "invalid_refresh_token")
        now = self.clock()
        failure: ApiError | None = None
        result: dict[str, Any] | None = None
        with self.db.transaction() as connection:
            row = connection.execute(
                """
                SELECT s.*, u.status
                FROM auth_sessions s
                JOIN users u ON u.id = s.user_id
                WHERE s.refresh_token_hash = ?
                """,
                (token_hash(refresh_token),),
            ).fetchone()
            if row is None or row["status"] != "active":
                raise ApiError(401, "invalid_refresh_token")
            if row["revoked_at"] is not None:
                if row["replaced_by"] is not None:
                    connection.execute(
                        "UPDATE auth_sessions SET revoked_at = COALESCE(revoked_at, ?) WHERE token_family_id = ?",
                        (now, row["token_family_id"]),
                    )
                failure = ApiError(401, "invalid_refresh_token")
            elif row["refresh_expires_at"] <= now:
                connection.execute(
                    "UPDATE auth_sessions SET revoked_at = ? WHERE id = ?",
                    (now, row["id"]),
                )
                failure = ApiError(401, "invalid_refresh_token")
            else:
                payload, replacement_id = self._insert_auth_session(
                    connection,
                    row["user_id"],
                    now,
                    row["token_family_id"],
                )
                connection.execute(
                    "UPDATE auth_sessions SET revoked_at = ?, replaced_by = ? WHERE id = ?",
                    (now, replacement_id, row["id"]),
                )
                result = {
                    **payload,
                    "user": self._user_by_id(connection, row["user_id"], True),
                }
        if failure is not None:
            raise failure
        if result is None:
            raise ApiError(401, "invalid_refresh_token")
        return result

    def logout(self, auth: AuthContext) -> None:
        with self.db.transaction() as connection:
            connection.execute(
                "UPDATE auth_sessions SET revoked_at = COALESCE(revoked_at, ?) WHERE id = ?",
                (self.clock(), auth.session_id),
            )

    def _user_by_id(
        self, connection: sqlite3.Connection, user_id: str, include_email: bool = False
    ) -> dict[str, Any]:
        row = connection.execute(
            """
            SELECT u.id, u.display_name, u.avatar_url, u.friend_code,
                   i.email_snapshot AS email
            FROM users u
            LEFT JOIN oauth_identities i
              ON i.user_id = u.id AND i.provider = 'google'
            WHERE u.id = ? AND u.status = 'active'
            """,
            (user_id,),
        ).fetchone()
        if row is None:
            raise ApiError(404, "user_not_found")
        result: dict[str, Any] = {
            "id": row["id"],
            "display_name": row["display_name"],
            "avatar_url": row["avatar_url"],
            "friend_code": row["friend_code"],
        }
        if include_email:
            result["email"] = row["email"]
        return result

    def me(self, auth: AuthContext) -> dict[str, Any]:
        with self.db.connection() as connection:
            return self._user_by_id(connection, auth.user_id, include_email=True)

    def progress(self, auth: AuthContext) -> dict[str, Any]:
        with self.db.connection() as connection:
            stats = connection.execute(
                "SELECT verified_playtime_seconds, death_count FROM player_stats WHERE user_id = ?",
                (auth.user_id,),
            ).fetchone()
            if stats is None:
                raise ApiError(404, "user_not_found")
            achievements = [
                {
                    "code": row["code"],
                    "title": row["title"],
                    "description": row["description"],
                    "unlocked_at": row["unlocked_at"],
                }
                for row in connection.execute(
                    """
                    SELECT d.code, d.title, d.description, a.unlocked_at
                    FROM user_achievements a
                    JOIN achievement_definitions d ON d.code = a.achievement_code
                    WHERE a.user_id = ?
                    ORDER BY a.unlocked_at, d.code
                    """,
                    (auth.user_id,),
                )
            ]
            return {
                "verified_playtime_seconds": stats["verified_playtime_seconds"],
                # Compatibility names used by the current Godot account panel.
                "verified_play_seconds": stats["verified_playtime_seconds"],
                "death_count": stats["death_count"],
                "deaths": stats["death_count"],
                "achievements": achievements,
            }

    @staticmethod
    def _friend_view(row: sqlite3.Row) -> dict[str, Any]:
        return {
            "id": row["id"],
            "display_name": row["display_name"],
            "avatar_url": row["avatar_url"],
            "friend_code": row["friend_code"],
        }

    def list_friends(self, auth: AuthContext) -> dict[str, Any]:
        with self.db.connection() as connection:
            rows = connection.execute(
                """
                SELECT u.id, u.display_name, u.avatar_url, u.friend_code, f.created_at
                FROM friendships f
                JOIN users u ON u.id = CASE
                    WHEN f.user_low_id = ? THEN f.user_high_id ELSE f.user_low_id END
                WHERE (f.user_low_id = ? OR f.user_high_id = ?) AND u.status = 'active'
                ORDER BY lower(u.display_name), u.id
                """,
                (auth.user_id, auth.user_id, auth.user_id),
            ).fetchall()
            return {
                "friends": [
                    {**self._friend_view(row), "friends_since": row["created_at"]} for row in rows
                ]
            }

    def list_friend_requests(self, auth: AuthContext) -> dict[str, Any]:
        with self.db.connection() as connection:
            incoming = connection.execute(
                """
                SELECT u.id, u.display_name, u.avatar_url, u.friend_code, r.created_at
                FROM friend_requests r
                JOIN users u ON u.id = r.requester_id
                WHERE r.recipient_id = ? AND r.status = 'pending' AND u.status = 'active'
                ORDER BY r.created_at, r.id
                """,
                (auth.user_id,),
            ).fetchall()
            outgoing = connection.execute(
                """
                SELECT u.id, u.display_name, u.avatar_url, u.friend_code, r.created_at
                FROM friend_requests r
                JOIN users u ON u.id = r.recipient_id
                WHERE r.requester_id = ? AND r.status = 'pending' AND u.status = 'active'
                ORDER BY r.created_at, r.id
                """,
                (auth.user_id,),
            ).fetchall()
            serialize = lambda row: {**self._friend_view(row), "requested_at": row["created_at"]}
            return {
                "friend_requests": [serialize(row) for row in incoming],
                "incoming": [serialize(row) for row in incoming],
                "outgoing": [serialize(row) for row in outgoing],
            }

    def create_friend_request(self, auth: AuthContext, friend_code: object) -> tuple[int, dict[str, Any]]:
        code = valid_friend_code(friend_code)
        if code is None:
            raise ApiError(400, "invalid_friend_code")
        now = self.clock()
        with self.db.transaction() as connection:
            target = connection.execute(
                "SELECT id, display_name, avatar_url, friend_code FROM users WHERE friend_code = ? AND status = 'active'",
                (code,),
            ).fetchone()
            if target is None:
                raise ApiError(404, "friend_code_not_found")
            if target["id"] == auth.user_id:
                raise ApiError(400, "cannot_friend_self")
            low, high = canonical_pair(auth.user_id, target["id"])
            friendship = connection.execute(
                "SELECT 1 FROM friendships WHERE user_low_id = ? AND user_high_id = ?",
                (low, high),
            ).fetchone()
            if friendship is not None:
                raise ApiError(409, "already_friends")
            blocked = connection.execute(
                """
                SELECT 1 FROM user_blocks
                WHERE (blocker_id = ? AND blocked_id = ?) OR (blocker_id = ? AND blocked_id = ?)
                """,
                (auth.user_id, target["id"], target["id"], auth.user_id),
            ).fetchone()
            if blocked is not None:
                raise ApiError(404, "friend_code_not_found")
            pending = connection.execute(
                """
                SELECT requester_id FROM friend_requests
                WHERE pair_low_id = ? AND pair_high_id = ? AND status = 'pending'
                """,
                (low, high),
            ).fetchone()
            if pending is not None:
                if pending["requester_id"] == auth.user_id:
                    return 200, {"status": "pending", "created": False, "user": self._friend_view(target)}
                raise ApiError(409, "incoming_friend_request_exists")
            connection.execute(
                """
                INSERT INTO friend_requests(
                    id, requester_id, recipient_id, pair_low_id, pair_high_id,
                    status, created_at, updated_at
                ) VALUES (?, ?, ?, ?, ?, 'pending', ?, ?)
                """,
                (random_uuid(), auth.user_id, target["id"], low, high, now, now),
            )
            return 201, {"status": "pending", "created": True, "user": self._friend_view(target)}

    def _respond_friend_request(
        self, auth: AuthContext, friend_code: object, accept: bool
    ) -> dict[str, Any]:
        code = valid_friend_code(friend_code)
        if code is None:
            raise ApiError(400, "invalid_friend_code")
        now = self.clock()
        with self.db.transaction() as connection:
            target = connection.execute(
                "SELECT id, display_name, avatar_url, friend_code FROM users WHERE friend_code = ? AND status = 'active'",
                (code,),
            ).fetchone()
            if target is None:
                raise ApiError(404, "friend_request_not_found")
            request = connection.execute(
                """
                SELECT id, pair_low_id, pair_high_id FROM friend_requests
                WHERE requester_id = ? AND recipient_id = ? AND status = 'pending'
                """,
                (target["id"], auth.user_id),
            ).fetchone()
            if request is None:
                raise ApiError(404, "friend_request_not_found")
            status = "accepted" if accept else "declined"
            cursor = connection.execute(
                """
                UPDATE friend_requests
                SET status = ?, updated_at = ?, responded_at = ?
                WHERE id = ? AND status = 'pending'
                """,
                (status, now, now, request["id"]),
            )
            if cursor.rowcount != 1:
                raise ApiError(409, "friend_request_already_resolved")
            if accept:
                connection.execute(
                    """
                    INSERT OR IGNORE INTO friendships(user_low_id, user_high_id, created_at)
                    VALUES (?, ?, ?)
                    """,
                    (request["pair_low_id"], request["pair_high_id"], now),
                )
            return {"status": status, "user": self._friend_view(target)}

    def accept_friend_request(self, auth: AuthContext, friend_code: object) -> dict[str, Any]:
        return self._respond_friend_request(auth, friend_code, True)

    def decline_friend_request(self, auth: AuthContext, friend_code: object) -> dict[str, Any]:
        return self._respond_friend_request(auth, friend_code, False)

    def remove_friend(self, auth: AuthContext, friend_code: object) -> None:
        code = valid_friend_code(friend_code)
        if code is None:
            raise ApiError(400, "invalid_friend_code")
        with self.db.transaction() as connection:
            target = connection.execute(
                "SELECT id FROM users WHERE friend_code = ? AND status = 'active'",
                (code,),
            ).fetchone()
            if target is None or target["id"] == auth.user_id:
                raise ApiError(404, "friendship_not_found")
            low, high = canonical_pair(auth.user_id, target["id"])
            cursor = connection.execute(
                "DELETE FROM friendships WHERE user_low_id = ? AND user_high_id = ?",
                (low, high),
            )
            if cursor.rowcount != 1:
                raise ApiError(404, "friendship_not_found")

    def create_game_ticket(self, auth: AuthContext) -> dict[str, Any]:
        now = self.clock()
        ticket = random_token("cpt")
        with self.db.transaction() as connection:
            connection.execute(
                "DELETE FROM game_tickets WHERE expires_at < ?",
                (now - 24 * 60 * 60,),
            )
            connection.execute(
                """
                INSERT INTO game_tickets(token_hash, user_id, created_at, expires_at)
                VALUES (?, ?, ?, ?)
                """,
                (token_hash(ticket), auth.user_id, now, now + self.config.ticket_ttl_seconds),
            )
        return {
            "ticket": ticket,
            "expires_in": self.config.ticket_ttl_seconds,
            "expires_at": now + self.config.ticket_ttl_seconds,
        }

    def redeem_game_ticket(self, ticket: object, game_server_id: str = "oracle-primary") -> dict[str, Any]:
        if not isinstance(ticket, str) or not TOKEN_RE.fullmatch(ticket) or not ticket.startswith("cpt_"):
            raise ApiError(401, "invalid_game_ticket")
        if not isinstance(game_server_id, str) or not 1 <= len(game_server_id) <= 64 or not all(
            character.isalnum() or character in "._:-" for character in game_server_id
        ):
            raise ApiError(400, "invalid_game_server_id")
        now = self.clock()
        play_session_id = random_uuid()
        with self.db.transaction() as connection:
            row = connection.execute(
                """
                SELECT t.user_id, t.expires_at, t.consumed_at, u.status
                FROM game_tickets t
                JOIN users u ON u.id = t.user_id
                WHERE t.token_hash = ?
                """,
                (token_hash(ticket),),
            ).fetchone()
            if (
                row is None
                or row["consumed_at"] is not None
                or row["expires_at"] <= now
                or row["status"] != "active"
            ):
                raise ApiError(401, "invalid_game_ticket")
            cursor = connection.execute(
                """
                UPDATE game_tickets SET consumed_at = ?
                WHERE token_hash = ? AND consumed_at IS NULL AND expires_at > ?
                """,
                (now, token_hash(ticket), now),
            )
            if cursor.rowcount != 1:
                raise ApiError(401, "invalid_game_ticket")

            previous = connection.execute(
                "SELECT * FROM play_sessions WHERE user_id = ? AND ended_at IS NULL",
                (row["user_id"],),
            ).fetchone()
            if previous is not None:
                # A reconnect supersedes the prior connection instead of rejecting
                # the new ticket. Credit only the bounded, still-live interval once;
                # an idle-expired session receives no unattended credit.
                if not self._play_session_expired(previous, now):
                    self._advance_play_session(connection, previous, now)
                connection.execute(
                    "UPDATE play_sessions SET ended_at = ? WHERE id = ? AND ended_at IS NULL",
                    (now, previous["id"]),
                )
            connection.execute(
                """
                INSERT INTO play_sessions(
                    id, user_id, game_server_id, started_at,
                    last_heartbeat_at, last_credited_at, credited_seconds
                ) VALUES (?, ?, ?, ?, ?, ?, 0)
                """,
                (play_session_id, row["user_id"], game_server_id, now, now, now),
            )
            user = self._user_by_id(connection, row["user_id"], include_email=False)
            return {"user": user, "play_session_id": play_session_id}

    def _advance_play_session(
        self,
        connection: sqlite3.Connection,
        row: sqlite3.Row,
        now: int,
        active: bool | None = None,
    ) -> tuple[int, int]:
        # Do not move persisted timestamps backwards if the host clock is corrected.
        effective_now = max(now, row["last_heartbeat_at"], row["last_credited_at"])
        elapsed = effective_now - row["last_credited_at"]
        previous_active = bool(row["crediting_active"])
        next_active = previous_active if active is None else active
        credit = (
            min(elapsed, self.config.heartbeat_credit_cap_seconds)
            if previous_active
            else 0
        )
        connection.execute(
            """
            UPDATE play_sessions
            SET last_heartbeat_at = ?, last_credited_at = ?,
                credited_seconds = credited_seconds + ?, crediting_active = ?
            WHERE id = ?
            """,
            (effective_now, effective_now, credit, int(next_active), row["id"]),
        )
        connection.execute(
            """
            UPDATE player_stats
            SET verified_playtime_seconds = verified_playtime_seconds + ?, updated_at = ?
            WHERE user_id = ?
            """,
            (credit, effective_now, row["user_id"]),
        )
        total = connection.execute(
            "SELECT verified_playtime_seconds FROM player_stats WHERE user_id = ?",
            (row["user_id"],),
        ).fetchone()[0]
        return credit, total

    def _play_session_expired(self, row: sqlite3.Row, now: int) -> bool:
        return row["last_heartbeat_at"] + self.config.play_session_idle_ttl_seconds <= now

    def heartbeat_play_session(
        self, play_session_id: object, active: object
    ) -> dict[str, Any]:
        session_id = _valid_uuid(play_session_id)
        if session_id is None:
            raise ApiError(400, "invalid_play_session_id")
        if type(active) is not bool:
            raise ApiError(400, "invalid_active_state")
        now = self.clock()
        with self.db.transaction() as connection:
            row = connection.execute(
                "SELECT * FROM play_sessions WHERE id = ?",
                (session_id,),
            ).fetchone()
            if row is None:
                raise ApiError(404, "play_session_not_found")
            if row["ended_at"] is not None:
                raise ApiError(409, "play_session_ended")
            if self._play_session_expired(row, now):
                raise ApiError(410, "play_session_expired")
            credit, total = self._advance_play_session(connection, row, now, active)
            return {
                "active": active,
                "credited_seconds": credit,
                "session_credited_seconds": row["credited_seconds"] + credit,
                "verified_playtime_seconds": total,
            }

    def end_play_session(self, play_session_id: object) -> dict[str, Any]:
        session_id = _valid_uuid(play_session_id)
        if session_id is None:
            raise ApiError(400, "invalid_play_session_id")
        now = self.clock()
        with self.db.transaction() as connection:
            row = connection.execute(
                "SELECT * FROM play_sessions WHERE id = ?",
                (session_id,),
            ).fetchone()
            if row is None:
                raise ApiError(404, "play_session_not_found")
            if row["ended_at"] is not None:
                total = connection.execute(
                    "SELECT verified_playtime_seconds FROM player_stats WHERE user_id = ?",
                    (row["user_id"],),
                ).fetchone()[0]
                return {
                    "ended": True,
                    "credited_seconds": 0,
                    "session_credited_seconds": row["credited_seconds"],
                    "verified_playtime_seconds": total,
                }
            if self._play_session_expired(row, now):
                connection.execute(
                    "UPDATE play_sessions SET ended_at = ? WHERE id = ? AND ended_at IS NULL",
                    (now, session_id),
                )
                total = connection.execute(
                    "SELECT verified_playtime_seconds FROM player_stats WHERE user_id = ?",
                    (row["user_id"],),
                ).fetchone()[0]
                return {
                    "ended": True,
                    "expired": True,
                    "credited_seconds": 0,
                    "session_credited_seconds": row["credited_seconds"],
                    "verified_playtime_seconds": total,
                }
            credit, total = self._advance_play_session(connection, row, now)
            connection.execute(
                "UPDATE play_sessions SET ended_at = ? WHERE id = ? AND ended_at IS NULL",
                (now, session_id),
            )
            return {
                "ended": True,
                "credited_seconds": credit,
                "session_credited_seconds": row["credited_seconds"] + credit,
                "verified_playtime_seconds": total,
            }

    def record_progress_event(
        self,
        play_session_id: object,
        event_id: object,
        event_type: object,
        achievement_code: object = None,
    ) -> dict[str, Any]:
        session_id = _valid_uuid(play_session_id)
        safe_event_id = valid_event_id(event_id)
        if session_id is None:
            raise ApiError(400, "invalid_play_session_id")
        if safe_event_id is None:
            raise ApiError(400, "invalid_event_id")
        if event_type not in {"death", "achievement"}:
            raise ApiError(400, "invalid_event_type")
        if event_type == "death" and achievement_code is not None:
            raise ApiError(400, "unexpected_achievement_code")
        safe_achievement: str | None = None
        if event_type == "achievement":
            safe_achievement = valid_achievement_code(achievement_code)
            if safe_achievement is None:
                raise ApiError(400, "invalid_achievement_code")
        now = self.clock()
        with self.db.transaction() as connection:
            play = connection.execute(
                "SELECT id, user_id, last_heartbeat_at, ended_at FROM play_sessions WHERE id = ?",
                (session_id,),
            ).fetchone()
            if play is None:
                raise ApiError(404, "play_session_not_found")
            if play["ended_at"] is not None:
                raise ApiError(409, "play_session_ended")
            if self._play_session_expired(play, now):
                raise ApiError(410, "play_session_expired")
            if safe_achievement is not None:
                definition = connection.execute(
                    "SELECT 1 FROM achievement_definitions WHERE code = ? AND active = 1",
                    (safe_achievement,),
                ).fetchone()
                if definition is None:
                    # Unknown/stale achievement hooks are deliberately non-fatal to the game server.
                    return {
                        "applied": False,
                        "duplicate": False,
                        "reason": "unknown_achievement",
                    }
            cursor = connection.execute(
                """
                INSERT OR IGNORE INTO progress_events(
                    play_session_id, event_id, user_id, event_type, achievement_code, created_at
                ) VALUES (?, ?, ?, ?, ?, ?)
                """,
                (session_id, safe_event_id, play["user_id"], event_type, safe_achievement, now),
            )
            if cursor.rowcount != 1:
                return {"applied": False, "duplicate": True}
            if event_type == "death":
                connection.execute(
                    "UPDATE player_stats SET death_count = death_count + 1, updated_at = ? WHERE user_id = ?",
                    (now, play["user_id"]),
                )
                unlocked = connection.execute(
                    """
                    INSERT OR IGNORE INTO user_achievements(
                        user_id, achievement_code, unlocked_at, source_event_id
                    ) VALUES (?, 'first_death', ?, ?)
                    """,
                    (play["user_id"], now, safe_event_id),
                ).rowcount == 1
                return {
                    "applied": True,
                    "duplicate": False,
                    "achievement_unlocked": unlocked,
                }
            unlocked = connection.execute(
                """
                INSERT OR IGNORE INTO user_achievements(
                    user_id, achievement_code, unlocked_at, source_event_id
                ) VALUES (?, ?, ?, ?)
                """,
                (play["user_id"], safe_achievement, now, safe_event_id),
            ).rowcount == 1
            return {"applied": True, "duplicate": False, "achievement_unlocked": unlocked}

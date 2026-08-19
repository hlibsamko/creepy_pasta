from __future__ import annotations

import html
import ipaddress
import json
import logging
import re
import secrets
import threading
import time
import urllib.parse
from collections.abc import Callable
from http import HTTPStatus
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from typing import Any

from .security import secure_equal
from .service import AccountService, ApiError, AuthContext


LOGGER = logging.getLogger("creepy_accounts.http")
PLAY_SESSION_ROUTE = re.compile(
    r"\A/internal/v1/play-sessions/([0-9a-f-]{36})/(heartbeat|events|end)\Z"
)
FRIEND_REMOVE_ROUTE = re.compile(r"\A/api/v1/friends/(CP-[A-Z2-7]{16})\Z")


class DuplicateJsonKey(ValueError):
    pass


def _json_object_pairs(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
    result: dict[str, Any] = {}
    for key, value in pairs:
        if key in result:
            raise DuplicateJsonKey(key)
        result[key] = value
    return result


class RateLimiter:
    def __init__(
        self,
        clock: Callable[[], float] = time.monotonic,
        max_buckets: int = 10_000,
    ) -> None:
        if max_buckets < 1:
            raise ValueError("max_buckets must be positive")
        self.clock = clock
        self.max_buckets = max_buckets
        self._buckets: dict[tuple[str, str], tuple[float, int]] = {}
        self._lock = threading.Lock()

    def allow(self, client_key: str, group: str, limit: int, window_seconds: int = 60) -> bool:
        now = self.clock()
        key = (client_key, group)
        with self._lock:
            if key not in self._buckets and len(self._buckets) >= self.max_buckets:
                self._buckets = {
                    bucket_key: bucket
                    for bucket_key, bucket in self._buckets.items()
                    if bucket[0] > now
                }
                if len(self._buckets) >= self.max_buckets:
                    return False
            reset_at, count = self._buckets.get(key, (now + window_seconds, 0))
            if now >= reset_at:
                reset_at, count = now + window_seconds, 0
            count += 1
            self._buckets[key] = (reset_at, count)
            return count <= limit


class AccountHttpServer(ThreadingHTTPServer):
    daemon_threads = True
    allow_reuse_address = True
    request_queue_size = 64

    def get_request(self) -> tuple[Any, Any]:
        request, client_address = super().get_request()
        request.settimeout(15.0)
        return request, client_address


def _handler_factory(service: AccountService, rate_limiter: RateLimiter) -> type[BaseHTTPRequestHandler]:
    class AccountRequestHandler(BaseHTTPRequestHandler):
        protocol_version = "HTTP/1.1"
        server_version = "CreepyPastaAccounts"
        sys_version = ""

        def log_message(self, _format: str, *args: object) -> None:
            # BaseHTTPRequestHandler logs query strings. OAuth callbacks contain a
            # one-time authorization code, so request logging is handled explicitly.
            return

        def version_string(self) -> str:
            return "CreepyPastaAccounts"

        def do_GET(self) -> None:
            self._handle("GET")

        def do_POST(self) -> None:
            self._handle("POST")

        def do_DELETE(self) -> None:
            self._handle("DELETE")

        def do_OPTIONS(self) -> None:
            request_id = secrets.token_hex(8)
            try:
                self._reject_unexpected_body()
                path = self._safe_path()
                if not path.startswith("/api/v1/"):
                    raise ApiError(404, "not_found")
                origin_values = self.headers.get_all("Origin", failobj=[])
                if len(origin_values) != 1:
                    raise ApiError(403, "origin_not_allowed")
                origin = origin_values[0]
                if origin is None or origin not in service.config.allowed_origins:
                    raise ApiError(403, "origin_not_allowed")
                requested_method = self.headers.get("Access-Control-Request-Method", "")
                if requested_method not in {"GET", "POST", "DELETE"}:
                    raise ApiError(405, "method_not_allowed")
                requested_headers = {
                    part.strip().lower()
                    for part in self.headers.get("Access-Control-Request-Headers", "").split(",")
                    if part.strip()
                }
                if not requested_headers.issubset({"authorization", "content-type"}):
                    raise ApiError(403, "headers_not_allowed")
                self.send_response(204)
                self._security_headers(origin)
                self.send_header("Access-Control-Allow-Methods", "GET, POST, DELETE")
                self.send_header("Access-Control-Allow-Headers", "Authorization, Content-Type")
                self.send_header("Access-Control-Max-Age", "600")
                self.send_header("Content-Length", "0")
                self.end_headers()
            except ApiError as exc:
                self._send_error(exc, request_id)

        def do_HEAD(self) -> None:
            self._handle("HEAD")

        def do_PUT(self) -> None:
            self._handle("PUT")

        def do_PATCH(self) -> None:
            self._handle("PATCH")

        def do_TRACE(self) -> None:
            self._handle("TRACE")

        def do_CONNECT(self) -> None:
            self._handle("CONNECT")

        def _handle(self, method: str) -> None:
            request_id = secrets.token_hex(8)
            path_for_log = "/invalid"
            status = 500
            try:
                if method != "POST":
                    self._reject_unexpected_body()
                path_for_log = self._safe_path()
                if urllib.parse.urlsplit(self.path).query and path_for_log != "/api/v1/auth/google/callback":
                    raise ApiError(400, "unexpected_query")
                self._check_origin()
                self._apply_rate_limit(path_for_log)
                status = self._dispatch(method, path_for_log, request_id)
            except ApiError as exc:
                status = exc.status
                self._send_error(exc, request_id)
            except (ConnectionError, TimeoutError):
                status = 408
                try:
                    self._send_error(ApiError(408, "request_timeout"), request_id)
                except OSError:
                    pass
            except Exception:
                status = 500
                LOGGER.exception("request_id=%s method=%s path=%s", request_id, method, path_for_log)
                try:
                    self._send_error(ApiError(500, "internal_error", "Internal server error"), request_id)
                except OSError:
                    pass
            finally:
                LOGGER.info(
                    "request_id=%s method=%s path=%s status=%d",
                    request_id,
                    method,
                    path_for_log,
                    status,
                )

        def _safe_path(self) -> str:
            if len(self.path) > 8192:
                raise ApiError(414, "uri_too_long")
            try:
                split = urllib.parse.urlsplit(self.path)
            except ValueError as exc:
                raise ApiError(400, "invalid_uri") from exc
            if split.scheme or split.netloc or not split.path.startswith("/"):
                raise ApiError(400, "invalid_uri")
            try:
                path = urllib.parse.unquote(split.path, errors="strict")
            except UnicodeDecodeError as exc:
                raise ApiError(400, "invalid_uri") from exc
            if "\x00" in path or "//" in path or "/../" in path or path.endswith("/.."):
                raise ApiError(400, "invalid_uri")
            return path

        def _query(self) -> dict[str, list[str]]:
            split = urllib.parse.urlsplit(self.path)
            try:
                return urllib.parse.parse_qs(
                    split.query,
                    keep_blank_values=True,
                    strict_parsing=True,
                    max_num_fields=12,
                )
            except (ValueError, UnicodeDecodeError) as exc:
                raise ApiError(400, "invalid_query") from exc

        def _check_origin(self) -> None:
            origin_values = self.headers.get_all("Origin", failobj=[])
            if len(origin_values) > 1:
                raise ApiError(403, "origin_not_allowed")
            origin = origin_values[0] if origin_values else None
            if origin is not None and origin not in service.config.allowed_origins:
                raise ApiError(403, "origin_not_allowed")

        def _response_origin(self) -> str | None:
            origin_values = self.headers.get_all("Origin", failobj=[])
            return origin_values[0] if len(origin_values) == 1 else None

        def _rate_client_ip(self) -> str:
            peer = ipaddress.ip_address(self.client_address[0])
            forwarded_values = self.headers.get_all("X-Forwarded-For", failobj=[])
            forwarded = forwarded_values[0] if len(forwarded_values) == 1 else None
            if peer.is_loopback and forwarded and len(forwarded) <= 512:
                first = forwarded.split(",", 1)[0].strip()
                try:
                    return str(ipaddress.ip_address(first))
                except ValueError:
                    pass
            return str(peer)

        def _apply_rate_limit(self, path: str) -> None:
            if path == "/healthz" or path == "/readyz":
                group, limit = "health", 300
            elif path == "/api/v1/auth/google/start":
                group, limit = "login_start", 10
            elif path == "/api/v1/auth/google/poll":
                group, limit = "login_poll", 180
            elif path == "/api/v1/auth/google/callback":
                group, limit = "login_callback", 30
            elif path.startswith("/internal/v1/"):
                group, limit = "internal", 1200
            else:
                group, limit = "api", 180
            if not rate_limiter.allow(self._rate_client_ip(), group, limit):
                raise ApiError(429, "rate_limited", "Too many requests")

        def _read_json(self) -> dict[str, Any]:
            content_lengths = self.headers.get_all("Content-Length", failobj=[])
            if len(content_lengths) != 1:
                raise ApiError(400, "invalid_content_length")
            if len(self.headers.get_all("Content-Type", failobj=[])) != 1:
                raise ApiError(415, "json_required")
            if self.headers.get("Transfer-Encoding") is not None:
                raise ApiError(400, "unsupported_transfer_encoding")
            if self.headers.get("Content-Encoding") not in {None, "identity"}:
                raise ApiError(415, "unsupported_content_encoding")
            content_type = self.headers.get_content_type()
            charset = self.headers.get_content_charset("utf-8")
            if content_type != "application/json" or charset.lower() != "utf-8":
                raise ApiError(415, "json_required")
            raw_length = self.headers.get("Content-Length")
            if raw_length is None:
                raise ApiError(411, "content_length_required")
            try:
                length = int(raw_length)
            except ValueError as exc:
                raise ApiError(400, "invalid_content_length") from exc
            if length < 0:
                raise ApiError(400, "invalid_content_length")
            if length > service.config.max_body_bytes:
                raise ApiError(413, "body_too_large")
            payload = self.rfile.read(length)
            if len(payload) != length:
                raise ApiError(400, "incomplete_body")
            try:
                parsed = json.loads(
                    payload.decode("utf-8"),
                    object_pairs_hook=_json_object_pairs,
                    parse_constant=lambda value: (_ for _ in ()).throw(ValueError(value)),
                )
            except (UnicodeDecodeError, json.JSONDecodeError, DuplicateJsonKey, ValueError) as exc:
                raise ApiError(400, "invalid_json") from exc
            if not isinstance(parsed, dict):
                raise ApiError(400, "json_object_required")
            return parsed

        def _reject_unexpected_body(self) -> None:
            content_lengths = self.headers.get_all("Content-Length", failobj=[])
            if len(content_lengths) > 1:
                raise ApiError(400, "invalid_content_length")
            if self.headers.get("Transfer-Encoding") is not None:
                raise ApiError(400, "unsupported_transfer_encoding")
            if not content_lengths:
                return
            try:
                length = int(content_lengths[0])
            except ValueError as exc:
                raise ApiError(400, "invalid_content_length") from exc
            if length < 0:
                raise ApiError(400, "invalid_content_length")
            if length != 0:
                raise ApiError(400, "unexpected_body")

        @staticmethod
        def _fields(
            payload: dict[str, Any], allowed: set[str], required: set[str] | None = None
        ) -> None:
            unexpected = set(payload) - allowed
            missing = (required or set()) - set(payload)
            if unexpected:
                raise ApiError(400, "unexpected_fields")
            if missing:
                raise ApiError(400, "missing_fields")

        def _bearer(self) -> AuthContext:
            if len(self.headers.get_all("Authorization", failobj=[])) != 1:
                raise ApiError(401, "bearer_token_required")
            authorization = self.headers.get("Authorization", "")
            if not authorization.startswith("Bearer ") or authorization.count(" ") != 1:
                raise ApiError(401, "bearer_token_required")
            return service.authenticate(authorization[7:])

        def _internal(self) -> None:
            try:
                peer = ipaddress.ip_address(self.client_address[0])
            except ValueError as exc:
                raise ApiError(403, "internal_only") from exc
            if not peer.is_loopback:
                raise ApiError(403, "internal_only")
            if len(self.headers.get_all("X-Internal-Secret", failobj=[])) != 1:
                raise ApiError(401, "invalid_internal_secret")
            supplied = self.headers.get("X-Internal-Secret", "")
            if not secure_equal(supplied, service.config.internal_secret):
                raise ApiError(401, "invalid_internal_secret")

        def _dispatch(self, method: str, path: str, request_id: str) -> int:
            if method == "GET" and path == "/healthz":
                self._send_json(200, {"status": "ok"}, request_id)
                return 200
            if method == "GET" and path == "/readyz":
                ready, payload = service.readiness()
                status = 200 if ready else 503
                self._send_json(status, payload, request_id)
                return status
            if method == "GET" and path in {"/privacy", "/api/v1/privacy"}:
                self._send_html(200, self._privacy_page(), request_id)
                return 200
            if method == "GET" and path in {"/terms", "/api/v1/terms"}:
                self._send_html(200, self._terms_page(), request_id)
                return 200
            if method == "GET" and path == "/api/v1/auth/google/callback":
                return self._google_callback(request_id)

            if method == "POST" and path == "/api/v1/auth/google/start":
                payload = self._read_json()
                self._fields(payload, set())
                self._send_json(201, service.start_google_login(), request_id)
                return 201
            if method == "POST" and path == "/api/v1/auth/google/poll":
                payload = self._read_json()
                self._fields(payload, {"login_id", "poll_token"}, {"login_id", "poll_token"})
                status, response = service.poll_google_login(
                    payload["login_id"], payload["poll_token"]
                )
                self._send_json(status, response, request_id, retry_after=2 if status == 202 else None)
                return status
            if method == "POST" and path == "/api/v1/auth/refresh":
                payload = self._read_json()
                self._fields(payload, {"refresh_token"}, {"refresh_token"})
                self._send_json(200, service.refresh_session(payload["refresh_token"]), request_id)
                return 200
            if method == "POST" and path in {"/api/v1/auth/logout", "/api/v1/logout"}:
                payload = self._read_json()
                self._fields(payload, set())
                service.logout(self._bearer())
                self._send_empty(204, request_id)
                return 204
            if method == "GET" and path == "/api/v1/me":
                self._send_json(200, service.me(self._bearer()), request_id)
                return 200
            if method == "GET" and path == "/api/v1/me/progress":
                self._send_json(200, service.progress(self._bearer()), request_id)
                return 200
            if method == "POST" and path == "/api/v1/game-tickets":
                payload = self._read_json()
                self._fields(payload, set())
                self._send_json(201, service.create_game_ticket(self._bearer()), request_id)
                return 201
            if method == "GET" and path == "/api/v1/friends":
                self._send_json(200, service.list_friends(self._bearer()), request_id)
                return 200
            if method == "GET" and path == "/api/v1/friend-requests":
                self._send_json(200, service.list_friend_requests(self._bearer()), request_id)
                return 200
            if method == "POST" and path == "/api/v1/friend-requests":
                payload = self._read_json()
                self._fields(payload, {"friend_code"}, {"friend_code"})
                status, response = service.create_friend_request(
                    self._bearer(), payload["friend_code"]
                )
                self._send_json(status, response, request_id)
                return status
            if method == "POST" and path in {
                "/api/v1/friend-requests/accept",
                "/api/v1/friend-requests/decline",
            }:
                payload = self._read_json()
                self._fields(payload, {"friend_code"}, {"friend_code"})
                auth = self._bearer()
                if path.endswith("/accept"):
                    response = service.accept_friend_request(auth, payload["friend_code"])
                else:
                    response = service.decline_friend_request(auth, payload["friend_code"])
                self._send_json(200, response, request_id)
                return 200
            friend_match = FRIEND_REMOVE_ROUTE.fullmatch(path)
            if method == "DELETE" and friend_match:
                service.remove_friend(self._bearer(), friend_match.group(1))
                self._send_empty(204, request_id)
                return 204

            if method == "POST" and path == "/internal/v1/game-tickets/redeem":
                self._internal()
                payload = self._read_json()
                self._fields(payload, {"ticket"}, {"ticket"})
                if len(self.headers.get_all("X-Game-Server-ID", failobj=[])) > 1:
                    raise ApiError(400, "invalid_game_server_id")
                game_server_id = self.headers.get("X-Game-Server-ID", "oracle-primary")
                self._send_json(
                    200,
                    service.redeem_game_ticket(payload["ticket"], game_server_id),
                    request_id,
                )
                return 200
            play_match = PLAY_SESSION_ROUTE.fullmatch(path)
            if method == "POST" and play_match:
                self._internal()
                payload = self._read_json()
                action = play_match.group(2)
                if action == "heartbeat":
                    self._fields(payload, {"active"}, {"active"})
                    response = service.heartbeat_play_session(
                        play_match.group(1), payload["active"]
                    )
                elif action == "end":
                    self._fields(payload, set())
                    response = service.end_play_session(play_match.group(1))
                else:
                    self._fields(
                        payload,
                        {"event_id", "type", "achievement_code"},
                        {"event_id", "type"},
                    )
                    response = service.record_progress_event(
                        play_match.group(1),
                        payload["event_id"],
                        payload["type"],
                        payload.get("achievement_code"),
                    )
                self._send_json(200, response, request_id)
                return 200

            known_path = path in {
                "/healthz",
                "/readyz",
                "/privacy",
                "/terms",
                "/api/v1/privacy",
                "/api/v1/terms",
                "/api/v1/auth/google/callback",
                "/api/v1/auth/google/start",
                "/api/v1/auth/google/poll",
                "/api/v1/auth/refresh",
                "/api/v1/auth/logout",
                "/api/v1/logout",
                "/api/v1/me",
                "/api/v1/me/progress",
                "/api/v1/game-tickets",
                "/api/v1/friends",
                "/api/v1/friend-requests",
                "/api/v1/friend-requests/accept",
                "/api/v1/friend-requests/decline",
                "/internal/v1/game-tickets/redeem",
            } or friend_match is not None or play_match is not None
            if known_path:
                raise ApiError(405, "method_not_allowed")
            raise ApiError(404, "not_found")

        def _google_callback(self, request_id: str) -> int:
            query = self._query()
            allowed = {
                "state",
                "code",
                "error",
                "error_description",
                "error_uri",
                "scope",
                "authuser",
                "prompt",
                "hd",
                "iss",
            }
            if set(query) - allowed or any(len(values) != 1 for values in query.values()):
                raise ApiError(400, "invalid_query")
            if "iss" in query and query["iss"][0] not in {
                "https://accounts.google.com",
                "accounts.google.com",
            }:
                raise ApiError(400, "invalid_provider_issuer")
            state_values = query.get("state")
            if not state_values or not state_values[0]:
                raise ApiError(400, "invalid_login_state")
            if "error" in query:
                service.fail_google_callback(state_values[0], query["error"][0])
                self._send_html(
                    200,
                    self._callback_page("Sign-in cancelled", "Return to Creepy Pasta and try again."),
                    request_id,
                )
                return 200
            code_values = query.get("code")
            if not code_values or not code_values[0]:
                raise ApiError(400, "invalid_authorization_code")
            try:
                service.complete_google_callback(state_values[0], code_values[0])
            except ApiError as exc:
                if exc.code == "authentication_failed":
                    self._send_html(
                        400,
                        self._callback_page(
                            "Sign-in failed", "Return to Creepy Pasta and start a new sign-in."
                        ),
                        request_id,
                    )
                    return 400
                raise
            self._send_html(
                200,
                self._callback_page(
                    "Sign-in complete", "You can close this browser tab and return to Creepy Pasta."
                ),
                request_id,
            )
            return 200

        def _security_headers(self, origin: str | None = None) -> None:
            self.send_header("X-Content-Type-Options", "nosniff")
            self.send_header("X-Frame-Options", "DENY")
            self.send_header("Referrer-Policy", "no-referrer")
            self.send_header("Permissions-Policy", "camera=(), microphone=(), geolocation=()")
            self.send_header("Content-Security-Policy", "default-src 'none'; frame-ancestors 'none'; base-uri 'none'; form-action 'none'")
            self.send_header("Cache-Control", "no-store")
            if service.config.public_base_url.startswith("https://"):
                self.send_header("Strict-Transport-Security", "max-age=31536000; includeSubDomains")
            if origin is not None and origin in service.config.allowed_origins:
                self.send_header("Access-Control-Allow-Origin", origin)
                self.send_header("Vary", "Origin")

        def _send_json(
            self,
            status: int,
            payload: dict[str, Any],
            request_id: str,
            retry_after: int | None = None,
        ) -> None:
            encoded = json.dumps(
                payload,
                ensure_ascii=False,
                allow_nan=False,
                separators=(",", ":"),
            ).encode("utf-8")
            self.send_response(status)
            self._security_headers(self._response_origin())
            self.send_header("Content-Type", "application/json; charset=utf-8")
            self.send_header("X-Request-ID", request_id)
            if retry_after is not None:
                self.send_header("Retry-After", str(retry_after))
            if self.close_connection:
                self.send_header("Connection", "close")
            self.send_header("Content-Length", str(len(encoded)))
            self.end_headers()
            if self.command != "HEAD":
                self.wfile.write(encoded)

        def _send_html(self, status: int, document: str, request_id: str) -> None:
            encoded = document.encode("utf-8")
            self.send_response(status)
            self._security_headers(self._response_origin())
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.send_header("X-Request-ID", request_id)
            self.send_header("Content-Length", str(len(encoded)))
            self.end_headers()
            if self.command != "HEAD":
                self.wfile.write(encoded)

        def _send_empty(self, status: int, request_id: str) -> None:
            self.send_response(status)
            self._security_headers(self._response_origin())
            self.send_header("X-Request-ID", request_id)
            self.send_header("Content-Length", "0")
            self.end_headers()

        def _send_error(self, error: ApiError, request_id: str) -> None:
            payload = {
                "error": error.code,
                "message": error.message,
                "request_id": request_id,
            }
            try:
                # Many failures happen before a request body is consumed. Closing
                # prevents those bytes from becoming a second request on keep-alive.
                self.close_connection = True
                self._send_json(error.status, payload, request_id, retry_after=60 if error.status == 429 else None)
            except (BrokenPipeError, ConnectionResetError):
                return

        @staticmethod
        def _callback_page(title: str, message: str) -> str:
            return (
                "<!doctype html><html lang=\"en\"><head><meta charset=\"utf-8\">"
                f"<title>{html.escape(title)}</title></head><body>"
                f"<main><h1>{html.escape(title)}</h1><p>{html.escape(message)}</p></main>"
                "</body></html>"
            )

        @staticmethod
        def _privacy_page() -> str:
            contact = service.config.contact_email
            contact_html = (
                f'<a href="mailto:{html.escape(contact, quote=True)}">{html.escape(contact)}</a>'
                if contact
                else "the operator through the official Creepy Pasta website"
            )
            return (
                "<!doctype html><html lang=\"en\"><head><meta charset=\"utf-8\">"
                "<title>Creepy Pasta Privacy Notice</title></head><body><main>"
                "<h1>Creepy Pasta Privacy Notice</h1>"
                "<p>Last updated: 12 August 2026.</p>"
                "<p>We use Google sign-in to receive your Google account identifier, verified email, "
                "display name, and profile image. Your password is never received.</p>"
                "<p>We store your account identifier, profile, friend relationships and requests, "
                "verified online play time, deaths, achievements, login sessions, and security logs "
                "needed to operate and protect the game.</p>"
                "<p>Your verified email is private. Other players can see your display name, profile "
                "image, and friend code when necessary for friend features. We do not sell personal data.</p>"
                "<p>Authentication attempts and expired credentials are removed or anonymized when no "
                "longer needed. Account progress remains until deletion is requested or required by law.</p>"
                f"<p>For access or deletion requests, contact {contact_html}.</p>"
                "</main></body></html>"
            )

        @staticmethod
        def _terms_page() -> str:
            contact = service.config.contact_email
            contact_text = contact if contact else "the operator through the official website"
            return (
                "<!doctype html><html lang=\"en\"><head><meta charset=\"utf-8\">"
                "<title>Creepy Pasta Terms</title></head><body><main>"
                "<h1>Creepy Pasta Terms of Service</h1>"
                "<p>Last updated: 12 August 2026.</p>"
                "<p>Use the service lawfully and do not automate abuse, impersonate another player, "
                "probe private interfaces, evade access controls, or manipulate account progress.</p>"
                "<p>Accounts may be limited or disabled to protect players and the service. Game "
                "availability, progress features, and these terms may change as the project develops.</p>"
                "<p>The service is provided as available without a promise of uninterrupted operation. "
                "Nothing here excludes rights or remedies that cannot legally be excluded.</p>"
                f"<p>Questions may be sent to {html.escape(contact_text)}.</p>"
                "</main></body></html>"
            )

    return AccountRequestHandler


def create_http_server(
    service: AccountService,
    host: str | None = None,
    port: int | None = None,
    rate_limiter: RateLimiter | None = None,
) -> AccountHttpServer:
    handler = _handler_factory(service, rate_limiter or RateLimiter())
    return AccountHttpServer(
        (host if host is not None else service.config.bind_host, port if port is not None else service.config.port),
        handler,
    )

from __future__ import annotations

import os
from dataclasses import dataclass
from pathlib import Path
from urllib.parse import urlsplit


class ConfigError(ValueError):
    """Raised when service configuration is unsafe or incomplete."""


def _env_bool(env: dict[str, str], name: str, default: bool = False) -> bool:
    raw = env.get(name)
    if raw is None:
        return default
    normalized = raw.strip().lower()
    if normalized in {"1", "true", "yes", "on"}:
        return True
    if normalized in {"0", "false", "no", "off"}:
        return False
    raise ConfigError(f"{name} must be a boolean")


def _env_int(
    env: dict[str, str],
    name: str,
    default: int,
    minimum: int,
    maximum: int,
) -> int:
    raw = env.get(name)
    if raw is None:
        return default
    try:
        value = int(raw)
    except ValueError as exc:
        raise ConfigError(f"{name} must be an integer") from exc
    if not minimum <= value <= maximum:
        raise ConfigError(f"{name} must be between {minimum} and {maximum}")
    return value


def _validate_base_url(value: str) -> str:
    clean = value.strip().rstrip("/")
    parsed = urlsplit(clean)
    if parsed.scheme not in {"http", "https"} or not parsed.hostname:
        raise ConfigError("CREEPY_ACCOUNT_PUBLIC_BASE_URL must be an absolute HTTP(S) URL")
    if parsed.username or parsed.password or parsed.query or parsed.fragment:
        raise ConfigError("CREEPY_ACCOUNT_PUBLIC_BASE_URL contains unsupported components")
    if parsed.path not in {"", "/"}:
        raise ConfigError("CREEPY_ACCOUNT_PUBLIC_BASE_URL must not contain a path")
    if parsed.scheme != "https" and parsed.hostname not in {"127.0.0.1", "::1", "localhost"}:
        raise ConfigError("the public base URL must use HTTPS outside local development")
    return clean


def _validate_origin(value: str) -> str:
    clean = value.strip().rstrip("/")
    parsed = urlsplit(clean)
    if parsed.scheme not in {"http", "https"} or not parsed.hostname:
        raise ConfigError(f"invalid allowed origin: {value!r}")
    if parsed.username or parsed.password or parsed.path not in {"", "/"} or parsed.query or parsed.fragment:
        raise ConfigError(f"invalid allowed origin: {value!r}")
    if parsed.scheme != "https" and parsed.hostname not in {"127.0.0.1", "::1", "localhost"}:
        raise ConfigError("allowed browser origins must use HTTPS outside local development")
    return clean


@dataclass(frozen=True, slots=True)
class Config:
    db_path: Path
    bind_host: str
    port: int
    public_base_url: str
    google_client_id: str | None
    google_client_secret: str | None
    internal_secret: str
    allowed_origins: tuple[str, ...] = ()
    allow_setup_pending: bool = False
    access_ttl_seconds: int = 15 * 60
    refresh_ttl_seconds: int = 30 * 24 * 60 * 60
    login_ttl_seconds: int = 10 * 60
    ticket_ttl_seconds: int = 60
    heartbeat_credit_cap_seconds: int = 120
    play_session_idle_ttl_seconds: int = 10 * 60
    max_body_bytes: int = 16 * 1024
    google_http_timeout_seconds: int = 10
    contact_email: str | None = None

    @classmethod
    def from_env(cls, environ: dict[str, str] | None = None) -> "Config":
        env = dict(os.environ if environ is None else environ)
        allow_setup_pending = _env_bool(env, "CREEPY_ACCOUNT_ALLOW_SETUP_PENDING", False)
        google_client_id = env.get("CREEPY_GOOGLE_CLIENT_ID", "").strip() or None
        google_client_secret = env.get("CREEPY_GOOGLE_CLIENT_SECRET", "").strip() or None
        missing_google = not google_client_id or not google_client_secret
        if missing_google and not allow_setup_pending:
            raise ConfigError(
                "CREEPY_GOOGLE_CLIENT_ID and CREEPY_GOOGLE_CLIENT_SECRET are required "
                "unless setup-pending mode is explicitly enabled"
            )

        internal_secret = env.get("CREEPY_ACCOUNT_INTERNAL_SECRET", "")
        if len(internal_secret) < 32:
            raise ConfigError("CREEPY_ACCOUNT_INTERNAL_SECRET must contain at least 32 characters")
        if internal_secret != internal_secret.strip() or any(
            ord(character) < 33 or ord(character) > 126 for character in internal_secret
        ):
            raise ConfigError(
                "CREEPY_ACCOUNT_INTERNAL_SECRET must contain only visible ASCII without whitespace"
            )

        origins: list[str] = []
        for raw_origin in env.get("CREEPY_ACCOUNT_ALLOWED_ORIGINS", "").split(","):
            if raw_origin.strip():
                origin = _validate_origin(raw_origin)
                if origin not in origins:
                    origins.append(origin)

        contact_email = env.get("CREEPY_ACCOUNT_CONTACT_EMAIL", "").strip() or None
        if contact_email is not None and (len(contact_email) > 254 or "@" not in contact_email):
            raise ConfigError("CREEPY_ACCOUNT_CONTACT_EMAIL is invalid")

        return cls(
            db_path=Path(env.get("CREEPY_ACCOUNT_DB_PATH", "data/accounts.db")).expanduser(),
            bind_host=env.get("CREEPY_ACCOUNT_BIND_HOST", "127.0.0.1").strip() or "127.0.0.1",
            port=_env_int(env, "CREEPY_ACCOUNT_PORT", 8080, 0, 65535),
            public_base_url=_validate_base_url(
                env.get("CREEPY_ACCOUNT_PUBLIC_BASE_URL", "http://127.0.0.1:8080")
            ),
            google_client_id=google_client_id,
            google_client_secret=google_client_secret,
            internal_secret=internal_secret,
            allowed_origins=tuple(origins),
            allow_setup_pending=allow_setup_pending,
            access_ttl_seconds=_env_int(
                env, "CREEPY_ACCOUNT_ACCESS_TTL_SECONDS", 15 * 60, 60, 24 * 60 * 60
            ),
            refresh_ttl_seconds=_env_int(
                env,
                "CREEPY_ACCOUNT_REFRESH_TTL_SECONDS",
                30 * 24 * 60 * 60,
                60 * 60,
                180 * 24 * 60 * 60,
            ),
            login_ttl_seconds=_env_int(
                env, "CREEPY_ACCOUNT_LOGIN_TTL_SECONDS", 10 * 60, 60, 30 * 60
            ),
            ticket_ttl_seconds=_env_int(
                env, "CREEPY_ACCOUNT_TICKET_TTL_SECONDS", 60, 10, 5 * 60
            ),
            heartbeat_credit_cap_seconds=_env_int(
                env, "CREEPY_ACCOUNT_HEARTBEAT_CREDIT_CAP_SECONDS", 120, 15, 10 * 60
            ),
            play_session_idle_ttl_seconds=_env_int(
                env,
                "CREEPY_ACCOUNT_PLAY_SESSION_IDLE_TTL_SECONDS",
                10 * 60,
                60,
                24 * 60 * 60,
            ),
            max_body_bytes=_env_int(
                env, "CREEPY_ACCOUNT_MAX_BODY_BYTES", 16 * 1024, 1024, 1024 * 1024
            ),
            google_http_timeout_seconds=_env_int(
                env, "CREEPY_GOOGLE_HTTP_TIMEOUT_SECONDS", 10, 2, 30
            ),
            contact_email=contact_email,
        )

    @property
    def google_callback_url(self) -> str:
        return f"{self.public_base_url}/api/v1/auth/google/callback"

    @property
    def missing_setup(self) -> tuple[str, ...]:
        missing: list[str] = []
        if not self.google_client_id:
            missing.append("CREEPY_GOOGLE_CLIENT_ID")
        if not self.google_client_secret:
            missing.append("CREEPY_GOOGLE_CLIENT_SECRET")
        return tuple(missing)

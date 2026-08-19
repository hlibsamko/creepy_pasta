from __future__ import annotations

import base64
import hashlib
import hmac
import re
import secrets
import unicodedata
import uuid
from urllib.parse import urlsplit


FRIEND_CODE_RE = re.compile(r"\ACP-[A-Z2-7]{16}\Z")
EVENT_ID_RE = re.compile(r"\A[A-Za-z0-9][A-Za-z0-9._:/@-]{0,255}\Z")
ACHIEVEMENT_CODE_RE = re.compile(r"\A[a-z0-9][a-z0-9_]{0,63}\Z")
TOKEN_RE = re.compile(r"\A(?:cpa|cpr|cpt|cpp)_[A-Za-z0-9_-]{32,128}\Z")


def random_token(prefix: str, bytes_count: int = 32) -> str:
    return f"{prefix}_{secrets.token_urlsafe(bytes_count)}"


def token_hash(token: str) -> bytes:
    return hashlib.sha256(token.encode("utf-8", "strict")).digest()


def secure_equal(left: str, right: str) -> bool:
    return hmac.compare_digest(left.encode("utf-8"), right.encode("utf-8"))


def random_uuid() -> str:
    return str(uuid.uuid4())


def random_friend_code() -> str:
    encoded = base64.b32encode(secrets.token_bytes(10)).decode("ascii").rstrip("=")
    return f"CP-{encoded}"


def pkce_verifier() -> str:
    # 64 random bytes produce a verifier within RFC 7636's 43..128 character range.
    return secrets.token_urlsafe(64)


def pkce_challenge(verifier: str) -> str:
    digest = hashlib.sha256(verifier.encode("ascii", "strict")).digest()
    return base64.urlsafe_b64encode(digest).decode("ascii").rstrip("=")


def normalize_display_name(value: object) -> str:
    if not isinstance(value, str):
        return "Player"
    clean = unicodedata.normalize("NFC", value).strip()
    clean = " ".join(clean.split())
    clean = "".join(character for character in clean if unicodedata.category(character)[0] != "C")
    if not clean:
        return "Player"
    return clean[:64]


def normalize_avatar_url(value: object) -> str | None:
    if not isinstance(value, str) or not value or len(value) > 2048:
        return None
    parsed = urlsplit(value)
    if parsed.scheme != "https" or not parsed.hostname or parsed.username or parsed.password:
        return None
    return value


def is_valid_email(value: object) -> bool:
    if not isinstance(value, str) or not 3 <= len(value) <= 254 or value.count("@") != 1:
        return False
    local, domain = value.rsplit("@", 1)
    return bool(local and domain and "." in domain and not any(ch.isspace() for ch in value))


def canonical_pair(first: str, second: str) -> tuple[str, str]:
    return (first, second) if first < second else (second, first)


def valid_friend_code(value: object) -> str | None:
    if not isinstance(value, str):
        return None
    normalized = value.strip().upper()
    return normalized if FRIEND_CODE_RE.fullmatch(normalized) else None


def valid_event_id(value: object) -> str | None:
    return value if isinstance(value, str) and EVENT_ID_RE.fullmatch(value) else None


def valid_achievement_code(value: object) -> str | None:
    return value if isinstance(value, str) and ACHIEVEMENT_CODE_RE.fullmatch(value) else None

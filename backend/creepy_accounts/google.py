from __future__ import annotations

import base64
import hashlib
import json
import re
import ssl
import threading
import time
import urllib.error
import urllib.parse
import urllib.request
from dataclasses import dataclass
from typing import Any, Protocol

from .security import is_valid_email, normalize_avatar_url, normalize_display_name, secure_equal


GOOGLE_AUTHORIZATION_ENDPOINT = "https://accounts.google.com/o/oauth2/v2/auth"
GOOGLE_TOKEN_ENDPOINT = "https://oauth2.googleapis.com/token"
GOOGLE_JWKS_ENDPOINT = "https://www.googleapis.com/oauth2/v3/certs"
GOOGLE_ISSUERS = frozenset({"https://accounts.google.com", "accounts.google.com"})
MAX_GOOGLE_RESPONSE_BYTES = 1024 * 1024
SHA256_DIGEST_INFO_PREFIX = bytes.fromhex("3031300d060960864801650304020105000420")


class GoogleAuthError(RuntimeError):
    """A safe, non-token-bearing Google authentication failure."""


@dataclass(frozen=True, slots=True)
class GoogleIdentity:
    subject: str
    email: str
    email_verified: bool
    display_name: str
    avatar_url: str | None


class CodeExchanger(Protocol):
    def exchange(self, code: str, redirect_uri: str, code_verifier: str) -> str:
        """Exchange a one-time authorization code and return an ID token."""


class IdTokenVerifier(Protocol):
    def verify(
        self,
        id_token: str,
        expected_audience: str,
        expected_nonce: str,
        now: int,
    ) -> GoogleIdentity:
        """Cryptographically verify a Google ID token and return its identity."""


def _read_json_response(response: Any) -> tuple[dict[str, Any], str | None]:
    content_type = response.headers.get_content_type()
    if content_type != "application/json":
        raise GoogleAuthError("google returned an unexpected content type")
    payload = response.read(MAX_GOOGLE_RESPONSE_BYTES + 1)
    if len(payload) > MAX_GOOGLE_RESPONSE_BYTES:
        raise GoogleAuthError("google response was too large")
    try:
        parsed = json.loads(payload.decode("utf-8"))
    except (UnicodeDecodeError, json.JSONDecodeError) as exc:
        raise GoogleAuthError("google returned malformed JSON") from exc
    if not isinstance(parsed, dict):
        raise GoogleAuthError("google returned an unexpected JSON value")
    return parsed, response.headers.get("Cache-Control")


class GoogleCodeExchanger:
    def __init__(self, client_id: str, client_secret: str, timeout_seconds: int = 10) -> None:
        self.client_id = client_id
        self.client_secret = client_secret
        self.timeout_seconds = timeout_seconds
        self.ssl_context = ssl.create_default_context()

    def exchange(self, code: str, redirect_uri: str, code_verifier: str) -> str:
        body = urllib.parse.urlencode(
            {
                "code": code,
                "client_id": self.client_id,
                "client_secret": self.client_secret,
                "redirect_uri": redirect_uri,
                "grant_type": "authorization_code",
                "code_verifier": code_verifier,
            }
        ).encode("ascii")
        request = urllib.request.Request(
            GOOGLE_TOKEN_ENDPOINT,
            data=body,
            headers={
                "Accept": "application/json",
                "Content-Type": "application/x-www-form-urlencoded",
                "User-Agent": "CreepyPastaAccountService/1",
            },
            method="POST",
        )
        try:
            with urllib.request.urlopen(
                request, timeout=self.timeout_seconds, context=self.ssl_context
            ) as response:
                parsed, _ = _read_json_response(response)
        except (urllib.error.URLError, TimeoutError, OSError) as exc:
            raise GoogleAuthError("google code exchange failed") from exc
        id_token = parsed.get("id_token")
        if not isinstance(id_token, str) or not 32 <= len(id_token) <= 16384:
            raise GoogleAuthError("google did not return a usable ID token")
        return id_token


def _base64url_decode(value: str, maximum_bytes: int) -> bytes:
    if not value or len(value) > maximum_bytes * 2:
        raise GoogleAuthError("invalid base64url value")
    if not re.fullmatch(r"[A-Za-z0-9_-]+", value):
        raise GoogleAuthError("invalid base64url alphabet")
    try:
        decoded = base64.urlsafe_b64decode(value + "=" * (-len(value) % 4))
    except (ValueError, base64.binascii.Error) as exc:
        raise GoogleAuthError("invalid base64url encoding") from exc
    if len(decoded) > maximum_bytes:
        raise GoogleAuthError("decoded value was too large")
    return decoded


def _positive_int_from_b64(value: object, maximum_bytes: int) -> int:
    if not isinstance(value, str):
        raise GoogleAuthError("invalid RSA key")
    decoded = _base64url_decode(value, maximum_bytes)
    if not decoded:
        raise GoogleAuthError("invalid RSA key")
    return int.from_bytes(decoded, "big")


def _verify_rs256(signing_input: bytes, signature: bytes, modulus: int, exponent: int) -> bool:
    key_size = (modulus.bit_length() + 7) // 8
    if key_size < 256 or key_size > 1024 or len(signature) != key_size:
        return False
    signature_number = int.from_bytes(signature, "big")
    if signature_number >= modulus:
        return False
    encoded = pow(signature_number, exponent, modulus).to_bytes(key_size, "big")
    digest_info = SHA256_DIGEST_INFO_PREFIX + hashlib.sha256(signing_input).digest()
    padding_length = key_size - len(digest_info) - 3
    if padding_length < 8:
        return False
    expected = b"\x00\x01" + (b"\xff" * padding_length) + b"\x00" + digest_info
    return secrets_compare(encoded, expected)


def secrets_compare(left: bytes, right: bytes) -> bool:
    # A local helper keeps all JWT signature comparisons constant-time.
    import hmac

    return hmac.compare_digest(left, right)


class GoogleIdTokenVerifier:
    def __init__(self, timeout_seconds: int = 10) -> None:
        self.timeout_seconds = timeout_seconds
        self.ssl_context = ssl.create_default_context()
        self._keys: dict[str, tuple[int, int]] = {}
        self._keys_expire_monotonic = 0.0
        self._lock = threading.Lock()

    def _fetch_keys(self) -> dict[str, tuple[int, int]]:
        request = urllib.request.Request(
            GOOGLE_JWKS_ENDPOINT,
            headers={"Accept": "application/json", "User-Agent": "CreepyPastaAccountService/1"},
        )
        try:
            with urllib.request.urlopen(
                request, timeout=self.timeout_seconds, context=self.ssl_context
            ) as response:
                parsed, cache_control = _read_json_response(response)
        except (urllib.error.URLError, TimeoutError, OSError) as exc:
            raise GoogleAuthError("google signing keys are unavailable") from exc

        raw_keys = parsed.get("keys")
        if not isinstance(raw_keys, list) or not raw_keys:
            raise GoogleAuthError("google returned no signing keys")
        keys: dict[str, tuple[int, int]] = {}
        for raw_key in raw_keys:
            if not isinstance(raw_key, dict):
                continue
            if raw_key.get("kty") != "RSA" or raw_key.get("alg") not in {None, "RS256"}:
                continue
            kid = raw_key.get("kid")
            if not isinstance(kid, str) or not 1 <= len(kid) <= 256:
                continue
            try:
                modulus = _positive_int_from_b64(raw_key.get("n"), 1024)
                exponent = _positive_int_from_b64(raw_key.get("e"), 8)
            except GoogleAuthError:
                continue
            if modulus.bit_length() < 2048 or exponent < 3 or exponent % 2 == 0:
                continue
            keys[kid] = (modulus, exponent)
        if not keys:
            raise GoogleAuthError("google returned no supported signing keys")

        max_age = 3600
        if cache_control:
            match = re.search(r"(?:^|,)\s*max-age=(\d+)", cache_control, re.IGNORECASE)
            if match:
                max_age = max(60, min(int(match.group(1)), 24 * 60 * 60))
        self._keys_expire_monotonic = time.monotonic() + max_age
        self._keys = keys
        return keys

    def _key_for(self, kid: str) -> tuple[int, int]:
        with self._lock:
            keys = self._keys
            if time.monotonic() >= self._keys_expire_monotonic:
                keys = self._fetch_keys()
            key = keys.get(kid)
            if key is None:
                # Google rotates keys. Force one refresh before rejecting an unknown kid.
                self._keys_expire_monotonic = 0.0
                key = self._fetch_keys().get(kid)
            if key is None:
                raise GoogleAuthError("ID token signing key is unknown")
            return key

    def verify(
        self,
        id_token: str,
        expected_audience: str,
        expected_nonce: str,
        now: int,
    ) -> GoogleIdentity:
        if not isinstance(id_token, str) or len(id_token) > 16384:
            raise GoogleAuthError("invalid ID token")
        parts = id_token.split(".")
        if len(parts) != 3:
            raise GoogleAuthError("invalid ID token")
        header_segment, payload_segment, signature_segment = parts
        try:
            header = json.loads(_base64url_decode(header_segment, 4096).decode("utf-8"))
            claims = json.loads(_base64url_decode(payload_segment, 12288).decode("utf-8"))
        except (UnicodeDecodeError, json.JSONDecodeError) as exc:
            raise GoogleAuthError("invalid ID token JSON") from exc
        if not isinstance(header, dict) or not isinstance(claims, dict):
            raise GoogleAuthError("invalid ID token structure")
        if header.get("alg") != "RS256":
            raise GoogleAuthError("unsupported ID token algorithm")
        kid = header.get("kid")
        if not isinstance(kid, str) or not 1 <= len(kid) <= 256:
            raise GoogleAuthError("ID token has no valid key identifier")
        signature = _base64url_decode(signature_segment, 1024)
        modulus, exponent = self._key_for(kid)
        signing_input = f"{header_segment}.{payload_segment}".encode("ascii", "strict")
        if not _verify_rs256(signing_input, signature, modulus, exponent):
            raise GoogleAuthError("ID token signature is invalid")

        if claims.get("iss") not in GOOGLE_ISSUERS:
            raise GoogleAuthError("ID token issuer is invalid")
        audience = claims.get("aud")
        audience_valid = False
        if isinstance(audience, str):
            audience_valid = secure_equal(audience, expected_audience)
        elif isinstance(audience, list) and audience:
            audience_valid = all(isinstance(item, str) for item in audience) and any(
                secure_equal(item, expected_audience) for item in audience
            )
            if len(audience) > 1:
                authorized_party = claims.get("azp")
                audience_valid = audience_valid and isinstance(authorized_party, str) and secure_equal(
                    authorized_party, expected_audience
                )
        if not audience_valid:
            raise GoogleAuthError("ID token audience is invalid")

        expiry = claims.get("exp")
        issued_at = claims.get("iat")
        if type(expiry) is not int or expiry <= now - 30:
            raise GoogleAuthError("ID token is expired")
        if type(issued_at) is not int or issued_at > now + 60:
            raise GoogleAuthError("ID token issue time is invalid")
        not_before = claims.get("nbf")
        if not_before is not None and (type(not_before) is not int or not_before > now + 60):
            raise GoogleAuthError("ID token is not active")
        nonce = claims.get("nonce")
        if not isinstance(nonce, str) or not secure_equal(nonce, expected_nonce):
            raise GoogleAuthError("ID token nonce is invalid")

        subject = claims.get("sub")
        email = claims.get("email")
        if not isinstance(subject, str) or not 1 <= len(subject) <= 255:
            raise GoogleAuthError("ID token subject is invalid")
        if not is_valid_email(email) or claims.get("email_verified") is not True:
            raise GoogleAuthError("a verified Google email is required")
        return GoogleIdentity(
            subject=subject,
            email=email,
            email_verified=True,
            display_name=normalize_display_name(claims.get("name")),
            avatar_url=normalize_avatar_url(claims.get("picture")),
        )

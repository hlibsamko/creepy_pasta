from __future__ import annotations

import base64
import hashlib
import json
import time
import unittest

from creepy_accounts.google import GoogleAuthError, GoogleIdTokenVerifier


# Test-only RSA key material. Production keys are fetched from Google's JWKS URL.
RSA_MODULUS_B64 = (
    "7yp5fpGL+2oocVoRI1zjOLtAcV1BrXqeeSpmqnRper9boirVGOzLjnz6DAlCpek0/"
    "e6Cu67iMvPNDIsjq7DGYQ6wIYL4xKo8mKHGnJiLqmV2HaCzM8KfC2DwzrZYLNa/"
    "ry/Oa3KfzhuBt/reGOow0AC7U0DHRXiyKUQFHNd6LVls3rtdLwspic2boAmjcgf"
    "OcpaDb5uU6ZAx+Nj3/0I5oFSJyNVMOtGjAyD6chrHrlvMr5WDgpYdSKcTs4V2LT"
    "zbgPtQQfGTR974j1IEWONaGky/soCzFW3wpIGCR+5a5AV2PmzgPThvZIDb0fmp9"
    "e2oHw89KxBspl9+3Sywf4gL9Q=="
)
RSA_PRIVATE_EXPONENT_B64 = (
    "DjxsAPGu8GcwQxcGYCF+UPksa9MOPsJGvpWciNbnFGxhivSbvKETuMaNp7vBYNjR"
    "06+nzn4pbrj+YpnBpM2f8VULfOMr5aDwfHFcviOCZMEnV7oiEJmsF+RMUTGfbAPY"
    "YxgoZFLtWjpe7VGceMUv5KG2hM0dT3BQwo4O89mLpzlHAZiki1fSKhAQ7sApYi29"
    "6fD6SB1jGIiH7oEECvzCWd6TkqzJF7NoC5XZ4icwLtc1f7/BDAFSPq4ObC5yMVG"
    "++uNDbhg1iljzURrk+coIIl+eqbKDtHaANQGLOknnY6U/+6hxCdVUugn7wKwANzQ"
    "VQiDsOi719vIbpSfPynndvQ=="
)
DIGEST_INFO_PREFIX = bytes.fromhex("3031300d060960864801650304020105000420")


def _b64url(value: bytes) -> str:
    return base64.urlsafe_b64encode(value).decode("ascii").rstrip("=")


def _integer(value: str) -> int:
    return int.from_bytes(base64.b64decode(value), "big")


def signed_token(claims: dict[str, object]) -> str:
    header = _b64url(
        json.dumps({"alg": "RS256", "kid": "test-key", "typ": "JWT"}, separators=(",", ":")).encode()
    )
    payload = _b64url(json.dumps(claims, separators=(",", ":")).encode())
    signing_input = f"{header}.{payload}".encode("ascii")
    modulus = _integer(RSA_MODULUS_B64)
    private_exponent = _integer(RSA_PRIVATE_EXPONENT_B64)
    key_size = (modulus.bit_length() + 7) // 8
    digest_info = DIGEST_INFO_PREFIX + hashlib.sha256(signing_input).digest()
    encoded_message = (
        b"\x00\x01"
        + b"\xff" * (key_size - len(digest_info) - 3)
        + b"\x00"
        + digest_info
    )
    signature = pow(int.from_bytes(encoded_message, "big"), private_exponent, modulus).to_bytes(
        key_size, "big"
    )
    return f"{header}.{payload}.{_b64url(signature)}"


class GoogleIdTokenVerifierTests(unittest.TestCase):
    def setUp(self) -> None:
        self.now = 1_800_000_000
        self.audience = "test-client.apps.googleusercontent.com"
        self.nonce = "nonce-value-that-is-long-and-random"
        self.verifier = GoogleIdTokenVerifier()
        self.verifier._keys = {"test-key": (_integer(RSA_MODULUS_B64), 65537)}
        self.verifier._keys_expire_monotonic = time.monotonic() + 3600

    def claims(self) -> dict[str, object]:
        return {
            "iss": "https://accounts.google.com",
            "sub": "stable-google-subject",
            "aud": self.audience,
            "iat": self.now - 5,
            "exp": self.now + 3600,
            "nonce": self.nonce,
            "email": "verified@example.test",
            "email_verified": True,
            "name": "Verified Player",
            "picture": "https://example.test/avatar.png",
        }

    def test_valid_rs256_token_is_verified_without_network(self) -> None:
        identity = self.verifier.verify(
            signed_token(self.claims()), self.audience, self.nonce, self.now
        )
        self.assertEqual(identity.subject, "stable-google-subject")
        self.assertEqual(identity.email, "verified@example.test")
        self.assertEqual(identity.display_name, "Verified Player")

    def test_signature_and_security_claim_failures_are_rejected(self) -> None:
        valid = signed_token(self.claims())
        segments = valid.split(".")
        altered_payload = self.claims()
        altered_payload["sub"] = "attacker"
        segments[1] = _b64url(json.dumps(altered_payload, separators=(",", ":")).encode())
        with self.assertRaises(GoogleAuthError):
            self.verifier.verify(".".join(segments), self.audience, self.nonce, self.now)

        for claim, value in (
            ("iss", "https://attacker.example"),
            ("aud", "wrong-client"),
            ("exp", self.now - 60),
            ("iat", self.now + 120),
            ("nonce", "wrong-nonce"),
            ("email_verified", False),
        ):
            with self.subTest(claim=claim):
                claims = self.claims()
                claims[claim] = value
                with self.assertRaises(GoogleAuthError):
                    self.verifier.verify(
                        signed_token(claims), self.audience, self.nonce, self.now
                    )


if __name__ == "__main__":
    unittest.main()

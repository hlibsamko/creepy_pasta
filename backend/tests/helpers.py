from __future__ import annotations

import tempfile
import unittest
import urllib.parse
from pathlib import Path
from typing import Any

from creepy_accounts import AccountService, Config
from creepy_accounts.google import GoogleAuthError, GoogleIdentity
from creepy_accounts.service import AuthContext


class MutableClock:
    def __init__(self, value: int = 1_800_000_000) -> None:
        self.value = value

    def __call__(self) -> int:
        return self.value

    def advance(self, seconds: int) -> None:
        self.value += seconds


class FakeGoogleExchanger:
    def __init__(self) -> None:
        self.calls: list[tuple[str, str, str]] = []
        self.fail_codes: set[str] = set()

    def exchange(self, code: str, redirect_uri: str, code_verifier: str) -> str:
        self.calls.append((code, redirect_uri, code_verifier))
        if code in self.fail_codes:
            raise GoogleAuthError("fake exchange failure")
        return f"fake-id-token:{code}"


class FakeGoogleVerifier:
    def __init__(self) -> None:
        self.identities: dict[str, GoogleIdentity] = {}
        self.calls: list[tuple[str, str, str, int]] = []
        self.fail_tokens: set[str] = set()

    def verify(
        self,
        id_token: str,
        expected_audience: str,
        expected_nonce: str,
        now: int,
    ) -> GoogleIdentity:
        self.calls.append((id_token, expected_audience, expected_nonce, now))
        if id_token in self.fail_tokens or id_token not in self.identities:
            raise GoogleAuthError("fake verification failure")
        return self.identities[id_token]


class ServiceTestCase(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary_directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary_directory.cleanup)
        self.clock = MutableClock()
        self.exchanger = FakeGoogleExchanger()
        self.verifier = FakeGoogleVerifier()
        self.config = Config(
            db_path=Path(self.temporary_directory.name) / "accounts.db",
            bind_host="127.0.0.1",
            port=0,
            public_base_url="http://127.0.0.1:8080",
            google_client_id="fake-client.apps.googleusercontent.com",
            google_client_secret="fake-client-secret",
            internal_secret="I" * 48,
            allowed_origins=("http://127.0.0.1:9090",),
            access_ttl_seconds=900,
            refresh_ttl_seconds=3600,
            login_ttl_seconds=600,
            ticket_ttl_seconds=60,
            heartbeat_credit_cap_seconds=120,
            max_body_bytes=1024,
        )
        self.service = AccountService(
            self.config,
            exchanger=self.exchanger,
            verifier=self.verifier,
            clock=self.clock,
        )

    def login(
        self,
        subject: str,
        email: str | None = None,
        name: str | None = None,
    ) -> tuple[AuthContext, dict[str, Any]]:
        code = f"code-{subject}"
        identity = GoogleIdentity(
            subject=subject,
            email=email or f"{subject}@example.test",
            email_verified=True,
            display_name=name or f"Player {subject}",
            avatar_url="https://example.test/avatar.png",
        )
        self.verifier.identities[f"fake-id-token:{code}"] = identity
        started = self.service.start_google_login()
        state = urllib.parse.parse_qs(
            urllib.parse.urlsplit(started["authorization_url"]).query
        )["state"][0]
        self.service.complete_google_callback(state, code)
        status, completed = self.service.poll_google_login(
            started["login_id"], started["poll_token"]
        )
        self.assertEqual(status, 200)
        auth = self.service.authenticate(completed["access_token"])
        return auth, completed

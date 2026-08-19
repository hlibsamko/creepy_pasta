from __future__ import annotations

import http.client
import json
import threading
import urllib.parse
from typing import Any

from creepy_accounts.google import GoogleIdentity
from creepy_accounts.http_server import RateLimiter, create_http_server

from tests.helpers import ServiceTestCase


class HttpApiTests(ServiceTestCase):
    def setUp(self) -> None:
        super().setUp()
        self.http_server = create_http_server(self.service, "127.0.0.1", 0)
        self.http_thread = threading.Thread(target=self.http_server.serve_forever, daemon=True)
        self.http_thread.start()
        self.addCleanup(self._stop_server)
        self.host, self.port = self.http_server.server_address[:2]

    def _stop_server(self) -> None:
        self.http_server.shutdown()
        self.http_server.server_close()
        self.http_thread.join(timeout=2)

    def request(
        self,
        method: str,
        path: str,
        payload: dict[str, Any] | None = None,
        headers: dict[str, str] | None = None,
        raw_body: bytes | None = None,
    ) -> tuple[int, dict[str, str], bytes]:
        connection = http.client.HTTPConnection(self.host, self.port, timeout=5)
        body: bytes | None = None
        request_headers = {"Accept": "application/json", **(headers or {})}
        if payload is not None:
            body = json.dumps(payload, separators=(",", ":")).encode("utf-8")
            request_headers.setdefault("Content-Type", "application/json")
        elif raw_body is not None:
            body = raw_body
        try:
            connection.request(method, path, body=body, headers=request_headers)
            response = connection.getresponse()
            response_body = response.read()
            return response.status, {key.lower(): value for key, value in response.getheaders()}, response_body
        finally:
            connection.close()

    @staticmethod
    def json_body(body: bytes) -> dict[str, Any]:
        parsed = json.loads(body.decode("utf-8"))
        if not isinstance(parsed, dict):
            raise AssertionError("response was not an object")
        return parsed

    def test_health_readiness_legal_pages_and_security_headers(self) -> None:
        status, headers, body = self.request("GET", "/healthz")
        self.assertEqual(status, 200)
        self.assertEqual(self.json_body(body), {"status": "ok"})
        self.assertEqual(headers["x-content-type-options"], "nosniff")
        self.assertEqual(headers["x-frame-options"], "DENY")
        self.assertEqual(headers["cache-control"], "no-store")
        self.assertIn("default-src 'none'", headers["content-security-policy"])
        status, _, body = self.request("GET", "/readyz")
        self.assertEqual(status, 200)
        self.assertEqual(self.json_body(body)["status"], "ready")
        for path, title in (
            ("/privacy", b"Privacy Notice"),
            ("/terms", b"Terms of Service"),
            ("/api/v1/privacy", b"Privacy Notice"),
            ("/api/v1/terms", b"Terms of Service"),
        ):
            status, legal_headers, legal_body = self.request("GET", path)
            self.assertEqual(status, 200)
            self.assertIn(title, legal_body)
            self.assertTrue(legal_headers["content-type"].startswith("text/html"))

    def test_full_browser_auth_http_flow_and_compatibility_logout(self) -> None:
        self.verifier.identities["fake-id-token:http-code"] = GoogleIdentity(
            subject="http-user",
            email="http@example.test",
            email_verified=True,
            display_name="HTTP Player",
            avatar_url=None,
        )
        status, _, start_body = self.request("POST", "/api/v1/auth/google/start", {})
        self.assertEqual(status, 201)
        started = self.json_body(start_body)
        state = urllib.parse.parse_qs(
            urllib.parse.urlsplit(started["authorization_url"]).query
        )["state"][0]
        status, callback_headers, callback_body = self.request(
            "GET",
            "/api/v1/auth/google/callback?"
            + urllib.parse.urlencode({"state": state, "code": "http-code"}),
        )
        self.assertEqual(status, 200)
        self.assertIn(b"Sign-in complete", callback_body)
        self.assertNotIn(b"http-code", callback_body)
        self.assertEqual(callback_headers["referrer-policy"], "no-referrer")
        status, _, poll_body = self.request(
            "POST",
            "/api/v1/auth/google/poll",
            {"login_id": started["login_id"], "poll_token": started["poll_token"]},
        )
        self.assertEqual(status, 200)
        completed = self.json_body(poll_body)
        token = completed["access_token"]
        status, _, me_body = self.request(
            "GET", "/api/v1/me", headers={"Authorization": f"Bearer {token}"}
        )
        self.assertEqual(status, 200)
        self.assertEqual(self.json_body(me_body)["display_name"], "HTTP Player")
        status, _, _ = self.request(
            "POST",
            "/api/v1/logout",
            {},
            headers={"Authorization": f"Bearer {token}"},
        )
        self.assertEqual(status, 204)
        status, _, _ = self.request(
            "GET", "/api/v1/me", headers={"Authorization": f"Bearer {token}"}
        )
        self.assertEqual(status, 401)

    def test_strict_json_origin_body_limit_and_query_validation(self) -> None:
        status, _, body = self.request(
            "POST",
            "/api/v1/auth/google/start",
            headers={"Content-Type": "application/json"},
            raw_body=b'{"duplicate":1,"duplicate":2}',
        )
        self.assertEqual(status, 400)
        self.assertEqual(self.json_body(body)["error"], "invalid_json")

        status, _, body = self.request(
            "POST",
            "/api/v1/auth/google/start",
            headers={"Content-Type": "text/plain"},
            raw_body=b"{}",
        )
        self.assertEqual(status, 415)
        self.assertEqual(self.json_body(body)["error"], "json_required")

        status, _, body = self.request(
            "POST",
            "/api/v1/auth/google/start",
            headers={"Content-Type": "application/json"},
            raw_body=b" " * (self.config.max_body_bytes + 1),
        )
        self.assertEqual(status, 413)
        self.assertEqual(self.json_body(body)["error"], "body_too_large")

        status, headers, _ = self.request(
            "GET",
            "/api/v1/me",
            headers={"Origin": "https://attacker.example"},
        )
        self.assertEqual(status, 403)
        self.assertNotIn("access-control-allow-origin", headers)
        status, headers, _ = self.request(
            "GET",
            "/api/v1/me",
            headers={"Origin": self.config.allowed_origins[0]},
        )
        self.assertEqual(status, 401)
        self.assertEqual(headers["access-control-allow-origin"], self.config.allowed_origins[0])
        status, _, body = self.request("GET", "/healthz?unexpected=true")
        self.assertEqual(status, 400)
        self.assertEqual(self.json_body(body)["error"], "unexpected_query")
        status, headers, body = self.request("GET", "/healthz", raw_body=b"not-allowed")
        self.assertEqual(status, 400)
        self.assertEqual(self.json_body(body)["error"], "unexpected_body")
        self.assertEqual(headers["connection"], "close")

    def test_unsupported_methods_keep_bounded_secure_responses(self) -> None:
        status, headers, body = self.request("HEAD", "/healthz")
        self.assertEqual(status, 405)
        self.assertEqual(body, b"")
        self.assertGreater(int(headers["content-length"]), 0)
        self.assertEqual(headers["x-content-type-options"], "nosniff")

        status, headers, body = self.request("TRACE", "/healthz")
        self.assertEqual(status, 405)
        self.assertEqual(self.json_body(body)["error"], "method_not_allowed")
        self.assertEqual(headers["x-frame-options"], "DENY")
        self.assertEqual(headers["connection"], "close")

    def test_rate_limiter_bounds_distinct_client_state(self) -> None:
        now = [100.0]
        limiter = RateLimiter(clock=lambda: now[0], max_buckets=2)
        self.assertTrue(limiter.allow("client-a", "api", 10))
        self.assertTrue(limiter.allow("client-b", "api", 10))
        self.assertFalse(limiter.allow("client-c", "api", 10))
        now[0] += 60
        self.assertTrue(limiter.allow("client-c", "api", 10))

    def test_internal_routes_require_secret_and_redeem_ticket_once(self) -> None:
        auth, _ = self.login("internal-http")
        ticket = self.service.create_game_ticket(auth)["ticket"]
        payload = {"ticket": ticket}
        status, _, _ = self.request(
            "POST", "/internal/v1/game-tickets/redeem", payload
        )
        self.assertEqual(status, 401)
        status, _, body = self.request(
            "POST",
            "/internal/v1/game-tickets/redeem",
            payload,
            headers={"X-Internal-Secret": self.config.internal_secret},
        )
        self.assertEqual(status, 200)
        redeemed = self.json_body(body)
        self.assertEqual(redeemed["user"]["id"], auth.user_id)
        play_session_id = redeemed["play_session_id"]
        internal_headers = {"X-Internal-Secret": self.config.internal_secret}
        status, _, heartbeat_body = self.request(
            "POST",
            f"/internal/v1/play-sessions/{play_session_id}/heartbeat",
            {"active": False},
            headers=internal_headers,
        )
        self.assertEqual(status, 200)
        self.assertFalse(self.json_body(heartbeat_body)["active"])
        status, _, invalid_heartbeat_body = self.request(
            "POST",
            f"/internal/v1/play-sessions/{play_session_id}/heartbeat",
            {},
            headers=internal_headers,
        )
        self.assertEqual(status, 400)
        self.assertEqual(self.json_body(invalid_heartbeat_body)["error"], "missing_fields")
        status, _, _ = self.request(
            "POST",
            "/internal/v1/game-tickets/redeem",
            payload,
            headers={"X-Internal-Secret": self.config.internal_secret},
        )
        self.assertEqual(status, 401)


if __name__ == "__main__":
    import unittest

    unittest.main()

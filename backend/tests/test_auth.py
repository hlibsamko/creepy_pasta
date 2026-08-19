from __future__ import annotations

import sqlite3
import urllib.parse

from creepy_accounts.google import GoogleIdentity
from creepy_accounts.service import ApiError

from tests.helpers import ServiceTestCase


class GoogleAuthTests(ServiceTestCase):
    def test_browser_code_flow_is_one_time_and_tokens_are_hashed(self) -> None:
        identity = GoogleIdentity(
            subject="google-subject-1",
            email="player@example.test",
            email_verified=True,
            display_name="Test Player",
            avatar_url="https://example.test/player.png",
        )
        self.verifier.identities["fake-id-token:good-code"] = identity

        started = self.service.start_google_login()
        authorization = urllib.parse.urlsplit(started["authorization_url"])
        query = urllib.parse.parse_qs(authorization.query)
        self.assertEqual(authorization.scheme, "https")
        self.assertEqual(query["response_type"], ["code"])
        self.assertEqual(query["scope"], ["openid email profile"])
        self.assertEqual(query["code_challenge_method"], ["S256"])
        self.assertNotIn("client_secret", query)
        self.assertGreaterEqual(len(query["state"][0]), 32)
        self.assertGreaterEqual(len(query["nonce"][0]), 32)

        pending_status, pending = self.service.poll_google_login(
            started["login_id"], started["poll_token"]
        )
        self.assertEqual(pending_status, 202)
        self.assertEqual(pending, {"status": "pending"})

        self.service.complete_google_callback(query["state"][0], "good-code")
        status, completed = self.service.poll_google_login(
            started["login_id"], started["poll_token"]
        )
        self.assertEqual(status, 200)
        self.assertEqual(completed["status"], "complete")
        self.assertEqual(completed["user"]["display_name"], "Test Player")
        self.assertEqual(completed["user"]["email"], "player@example.test")
        self.assertTrue(completed["access_token"].startswith("cpa_"))
        self.assertTrue(completed["refresh_token"].startswith("cpr_"))
        self.assertEqual(self.exchanger.calls[0][1], self.config.google_callback_url)
        self.assertGreaterEqual(len(self.exchanger.calls[0][2]), 43)
        self.assertEqual(self.verifier.calls[0][1], self.config.google_client_id)
        self.assertEqual(self.verifier.calls[0][2], query["nonce"][0])

        with self.assertRaises(ApiError) as consumed:
            self.service.poll_google_login(started["login_id"], started["poll_token"])
        self.assertEqual(consumed.exception.status, 410)
        with self.assertRaises(ApiError) as replayed_callback:
            self.service.complete_google_callback(query["state"][0], "good-code")
        self.assertEqual(replayed_callback.exception.code, "invalid_login_state")

        with self.service.db.connection() as connection:
            login = connection.execute("SELECT * FROM oauth_login_attempts").fetchone()
            session = connection.execute("SELECT * FROM auth_sessions").fetchone()
        self.assertNotIn(started["poll_token"].encode(), bytes(login["poll_token_hash"]))
        self.assertNotIn(completed["access_token"].encode(), bytes(session["access_token_hash"]))
        self.assertNotIn(completed["refresh_token"].encode(), bytes(session["refresh_token_hash"]))

    def test_google_subject_not_email_is_account_key(self) -> None:
        first_auth, first = self.login("subject-a", "same@example.test", "First Name")
        second_auth, second = self.login("subject-a", "renamed@example.test", "Renamed")
        third_auth, third = self.login("subject-b", "same@example.test", "Different Account")

        self.assertEqual(first_auth.user_id, second_auth.user_id)
        self.assertEqual(first["user"]["friend_code"], second["user"]["friend_code"])
        self.assertNotEqual(first_auth.user_id, third_auth.user_id)
        self.assertEqual(self.service.me(second_auth)["display_name"], "Renamed")
        self.assertEqual(self.service.me(third_auth)["display_name"], "Different Account")

    def test_failed_verification_is_generic_and_attempt_cannot_be_replayed(self) -> None:
        started = self.service.start_google_login()
        query = urllib.parse.parse_qs(
            urllib.parse.urlsplit(started["authorization_url"]).query
        )
        with self.assertRaises(ApiError) as failed:
            self.service.complete_google_callback(query["state"][0], "untrusted-code")
        self.assertEqual(failed.exception.code, "authentication_failed")
        self.assertNotIn("fake", failed.exception.message)
        with self.assertRaises(ApiError) as polled:
            self.service.poll_google_login(started["login_id"], started["poll_token"])
        self.assertEqual(polled.exception.code, "authentication_failed")
        with self.assertRaises(ApiError):
            self.service.complete_google_callback(query["state"][0], "untrusted-code")

    def test_refresh_rotation_and_reuse_revokes_the_token_family(self) -> None:
        _, completed = self.login("refresh-user")
        rotated = self.service.refresh_session(completed["refresh_token"])

        with self.assertRaises(ApiError):
            self.service.authenticate(completed["access_token"])
        self.assertEqual(
            self.service.authenticate(rotated["access_token"]).user_id,
            rotated["user"]["id"],
        )
        with self.assertRaises(ApiError) as reuse:
            self.service.refresh_session(completed["refresh_token"])
        self.assertEqual(reuse.exception.code, "invalid_refresh_token")
        with self.assertRaises(ApiError):
            self.service.authenticate(rotated["access_token"])

    def test_login_expiry_and_invalid_poll_token_fail_closed(self) -> None:
        started = self.service.start_google_login()
        with self.assertRaises(ApiError) as wrong:
            self.service.poll_google_login(started["login_id"], "cpp_" + "A" * 43)
        self.assertEqual(wrong.exception.status, 404)
        self.clock.advance(self.config.login_ttl_seconds)
        with self.assertRaises(ApiError) as expired:
            self.service.poll_google_login(started["login_id"], started["poll_token"])
        self.assertEqual(expired.exception.status, 410)

    def test_disabled_account_attempt_is_committed_as_failed(self) -> None:
        auth, _ = self.login("disabled-subject")
        with self.service.db.transaction() as connection:
            connection.execute("UPDATE users SET status = 'disabled' WHERE id = ?", (auth.user_id,))

        code = "code-disabled-subject"
        started = self.service.start_google_login()
        state = urllib.parse.parse_qs(
            urllib.parse.urlsplit(started["authorization_url"]).query
        )["state"][0]
        with self.assertRaises(ApiError) as disabled:
            self.service.complete_google_callback(state, code)
        self.assertEqual(disabled.exception.code, "account_disabled")
        with self.assertRaises(ApiError) as polled:
            self.service.poll_google_login(started["login_id"], started["poll_token"])
        self.assertEqual(polled.exception.code, "authentication_failed")
        with self.service.db.connection() as connection:
            attempt = connection.execute(
                "SELECT status, error_code FROM oauth_login_attempts WHERE id = ?",
                (started["login_id"],),
            ).fetchone()
        self.assertEqual((attempt["status"], attempt["error_code"]), ("failed", "account_disabled"))


if __name__ == "__main__":
    import unittest

    unittest.main()

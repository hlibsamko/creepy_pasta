from __future__ import annotations

from creepy_accounts.service import ApiError

from tests.helpers import ServiceTestCase


class FriendshipTests(ServiceTestCase):
    def test_request_accept_list_and_remove(self) -> None:
        alice, alice_login = self.login("alice", name="Alice")
        bob, bob_login = self.login("bob", name="Bob")

        status, created = self.service.create_friend_request(
            alice, bob_login["user"]["friend_code"].lower()
        )
        self.assertEqual(status, 201)
        self.assertTrue(created["created"])
        repeated_status, repeated = self.service.create_friend_request(
            alice, bob_login["user"]["friend_code"]
        )
        self.assertEqual(repeated_status, 200)
        self.assertFalse(repeated["created"])

        alice_requests = self.service.list_friend_requests(alice)
        bob_requests = self.service.list_friend_requests(bob)
        self.assertEqual(len(alice_requests["outgoing"]), 1)
        self.assertEqual(len(bob_requests["incoming"]), 1)
        self.assertEqual(bob_requests["friend_requests"], bob_requests["incoming"])
        with self.assertRaises(ApiError) as reverse:
            self.service.create_friend_request(bob, alice_login["user"]["friend_code"])
        self.assertEqual(reverse.exception.code, "incoming_friend_request_exists")
        with self.assertRaises(ApiError):
            self.service.accept_friend_request(alice, bob_login["user"]["friend_code"])

        accepted = self.service.accept_friend_request(
            bob, alice_login["user"]["friend_code"]
        )
        self.assertEqual(accepted["status"], "accepted")
        self.assertEqual(self.service.list_friend_requests(bob)["incoming"], [])
        self.assertEqual(
            self.service.list_friends(alice)["friends"][0]["friend_code"],
            bob_login["user"]["friend_code"],
        )
        self.assertEqual(
            self.service.list_friends(bob)["friends"][0]["friend_code"],
            alice_login["user"]["friend_code"],
        )
        with self.assertRaises(ApiError) as already:
            self.service.create_friend_request(alice, bob_login["user"]["friend_code"])
        self.assertEqual(already.exception.code, "already_friends")

        self.service.remove_friend(alice, bob_login["user"]["friend_code"])
        self.assertEqual(self.service.list_friends(alice)["friends"], [])
        self.assertEqual(self.service.list_friends(bob)["friends"], [])
        with self.assertRaises(ApiError):
            self.service.remove_friend(alice, bob_login["user"]["friend_code"])

    def test_decline_and_self_request_guards(self) -> None:
        alice, alice_login = self.login("alice-guard", name="Alice")
        bob, bob_login = self.login("bob-guard", name="Bob")
        with self.assertRaises(ApiError) as self_request:
            self.service.create_friend_request(alice, alice_login["user"]["friend_code"])
        self.assertEqual(self_request.exception.code, "cannot_friend_self")
        with self.assertRaises(ApiError) as missing:
            self.service.create_friend_request(alice, "CP-AAAAAAAAAAAAAAAA")
        self.assertEqual(missing.exception.status, 404)

        self.service.create_friend_request(alice, bob_login["user"]["friend_code"])
        declined = self.service.decline_friend_request(
            bob, alice_login["user"]["friend_code"]
        )
        self.assertEqual(declined["status"], "declined")
        self.assertEqual(self.service.list_friends(alice)["friends"], [])
        with self.assertRaises(ApiError):
            self.service.decline_friend_request(bob, alice_login["user"]["friend_code"])


if __name__ == "__main__":
    import unittest

    unittest.main()

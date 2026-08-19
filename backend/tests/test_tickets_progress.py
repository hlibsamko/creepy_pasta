from __future__ import annotations

from concurrent.futures import ThreadPoolExecutor

from creepy_accounts.service import ApiError

from tests.helpers import ServiceTestCase


class TicketAndProgressTests(ServiceTestCase):
    def test_game_ticket_is_expiring_single_use_and_not_stored_raw(self) -> None:
        auth, _ = self.login("ticket-user")
        issued = self.service.create_game_ticket(auth)
        self.assertEqual(issued["expires_at"], self.clock() + self.config.ticket_ttl_seconds)
        redeemed = self.service.redeem_game_ticket(issued["ticket"])
        self.assertEqual(redeemed["user"]["id"], auth.user_id)
        self.assertNotIn("email", redeemed["user"])
        self.assertEqual(len(redeemed["play_session_id"]), 36)
        with self.assertRaises(ApiError) as reused:
            self.service.redeem_game_ticket(issued["ticket"])
        self.assertEqual(reused.exception.status, 401)

        with self.service.db.connection() as connection:
            stored = connection.execute("SELECT token_hash FROM game_tickets").fetchone()[0]
        self.assertNotEqual(bytes(stored), issued["ticket"].encode())

        expired = self.service.create_game_ticket(auth)
        self.clock.advance(self.config.ticket_ttl_seconds)
        with self.assertRaises(ApiError) as expiry:
            self.service.redeem_game_ticket(expired["ticket"])
        self.assertEqual(expiry.exception.code, "invalid_game_ticket")

    def test_heartbeat_is_server_timed_capped_and_end_is_idempotent(self) -> None:
        auth, _ = self.login("playtime-user")
        ticket = self.service.create_game_ticket(auth)["ticket"]
        play_session_id = self.service.redeem_game_ticket(ticket)["play_session_id"]

        started = self.service.heartbeat_play_session(play_session_id, True)
        self.assertEqual(started["credited_seconds"], 0)
        self.clock.advance(60)
        first = self.service.heartbeat_play_session(play_session_id, True)
        self.assertEqual(first["credited_seconds"], 60)
        self.assertEqual(first["verified_playtime_seconds"], 60)
        self.clock.advance(self.config.heartbeat_credit_cap_seconds + 30)
        capped = self.service.heartbeat_play_session(play_session_id, True)
        self.assertEqual(capped["credited_seconds"], self.config.heartbeat_credit_cap_seconds)
        self.clock.advance(5)
        ended = self.service.end_play_session(play_session_id)
        self.assertEqual(ended["credited_seconds"], 5)
        repeated = self.service.end_play_session(play_session_id)
        self.assertEqual(repeated["credited_seconds"], 0)
        with self.assertRaises(ApiError) as late_heartbeat:
            self.service.heartbeat_play_session(play_session_id, True)
        self.assertEqual(late_heartbeat.exception.code, "play_session_ended")

    def test_only_active_heartbeat_intervals_are_credited(self) -> None:
        auth, _ = self.login("activity-user")
        ticket = self.service.create_game_ticket(auth)["ticket"]
        play_session_id = self.service.redeem_game_ticket(ticket)["play_session_id"]

        started = self.service.heartbeat_play_session(play_session_id, True)
        self.assertEqual(started["credited_seconds"], 0)
        self.clock.advance(60)
        playing = self.service.heartbeat_play_session(play_session_id, True)
        self.assertTrue(playing["active"])
        self.assertEqual(playing["credited_seconds"], 60)
        self.assertEqual(playing["verified_playtime_seconds"], 60)

        self.clock.advance(30)
        finished = self.service.heartbeat_play_session(play_session_id, False)
        self.assertFalse(finished["active"])
        self.assertEqual(finished["credited_seconds"], 30)
        self.assertEqual(finished["verified_playtime_seconds"], 90)

        self.clock.advance(60)
        lobby = self.service.heartbeat_play_session(play_session_id, False)
        self.assertEqual(lobby["credited_seconds"], 0)
        restarted = self.service.heartbeat_play_session(play_session_id, True)
        self.assertEqual(restarted["credited_seconds"], 0)
        ended = self.service.end_play_session(play_session_id)
        self.assertEqual(ended["credited_seconds"], 0)
        self.assertEqual(ended["verified_playtime_seconds"], 90)

        for invalid in (None, 0, 1, "true"):
            with self.subTest(invalid=invalid):
                with self.assertRaises(ApiError) as invalid_active:
                    self.service.heartbeat_play_session(play_session_id, invalid)
                self.assertEqual(invalid_active.exception.code, "invalid_active_state")

    def test_new_redeem_supersedes_old_session_without_double_playtime(self) -> None:
        auth, _ = self.login("reconnect-user")
        first_ticket = self.service.create_game_ticket(auth)["ticket"]
        first_session = self.service.redeem_game_ticket(first_ticket)["play_session_id"]
        self.service.heartbeat_play_session(first_session, True)

        self.clock.advance(60)
        second_ticket = self.service.create_game_ticket(auth)["ticket"]
        second_session = self.service.redeem_game_ticket(second_ticket)["play_session_id"]
        self.assertNotEqual(first_session, second_session)
        self.assertEqual(self.service.progress(auth)["verified_playtime_seconds"], 60)
        activated = self.service.heartbeat_play_session(second_session, True)
        self.assertEqual(activated["credited_seconds"], 0)

        with self.assertRaises(ApiError) as old_heartbeat:
            self.service.heartbeat_play_session(first_session, True)
        self.assertEqual(old_heartbeat.exception.code, "play_session_ended")
        with self.assertRaises(ApiError) as old_event:
            self.service.record_progress_event(first_session, "old-death", "death")
        self.assertEqual(old_event.exception.code, "play_session_ended")

        self.clock.advance(60)
        current = self.service.heartbeat_play_session(second_session, True)
        self.assertEqual(current["verified_playtime_seconds"], 120)
        with self.service.db.connection() as connection:
            active = connection.execute(
                "SELECT id FROM play_sessions WHERE user_id = ? AND ended_at IS NULL",
                (auth.user_id,),
            ).fetchall()
        self.assertEqual([row["id"] for row in active], [second_session])

    def test_concurrent_redeems_leave_exactly_one_active_session(self) -> None:
        auth, _ = self.login("concurrent-reconnect-user")
        initial_ticket = self.service.create_game_ticket(auth)["ticket"]
        initial_session = self.service.redeem_game_ticket(initial_ticket)["play_session_id"]
        self.service.heartbeat_play_session(initial_session, True)
        self.clock.advance(60)
        tickets = [self.service.create_game_ticket(auth)["ticket"] for _ in range(4)]
        with ThreadPoolExecutor(max_workers=4) as executor:
            redeemed = list(executor.map(self.service.redeem_game_ticket, tickets))
        session_ids = {item["play_session_id"] for item in redeemed}
        self.assertEqual(len(session_ids), len(tickets))

        with self.service.db.connection() as connection:
            rows = connection.execute(
                "SELECT id, ended_at FROM play_sessions WHERE user_id = ?",
                (auth.user_id,),
            ).fetchall()
        active_ids = [row["id"] for row in rows if row["ended_at"] is None]
        self.assertEqual(len(active_ids), 1)
        self.assertIn(active_ids[0], session_ids)
        self.assertEqual(self.service.progress(auth)["verified_playtime_seconds"], 60)
        for ended_id in (session_ids | {initial_session}) - set(active_ids):
            with self.assertRaises(ApiError) as old_session:
                self.service.heartbeat_play_session(ended_id, True)
            self.assertEqual(old_session.exception.code, "play_session_ended")

    def test_idle_session_rejects_events_and_receives_no_final_credit(self) -> None:
        auth, _ = self.login("expired-session-user")
        ticket = self.service.create_game_ticket(auth)["ticket"]
        play_session_id = self.service.redeem_game_ticket(ticket)["play_session_id"]
        self.clock.advance(self.config.play_session_idle_ttl_seconds)

        with self.assertRaises(ApiError) as late_event:
            self.service.record_progress_event(play_session_id, "late-death", "death")
        self.assertEqual(late_event.exception.code, "play_session_expired")
        with self.assertRaises(ApiError) as late_heartbeat:
            self.service.heartbeat_play_session(play_session_id, False)
        self.assertEqual(late_heartbeat.exception.code, "play_session_expired")

        ended = self.service.end_play_session(play_session_id)
        self.assertTrue(ended["expired"])
        self.assertEqual(ended["credited_seconds"], 0)
        self.assertEqual(self.service.progress(auth)["verified_playtime_seconds"], 0)
        self.assertEqual(self.service.progress(auth)["death_count"], 0)

    def test_events_are_idempotent_and_achievements_are_allowlisted(self) -> None:
        auth, _ = self.login("events-user")
        ticket = self.service.create_game_ticket(auth)["ticket"]
        play_session_id = self.service.redeem_game_ticket(ticket)["play_session_id"]

        death = self.service.record_progress_event(play_session_id, "death:1", "death")
        duplicate = self.service.record_progress_event(play_session_id, "death:1", "death")
        self.assertTrue(death["applied"])
        self.assertTrue(death["achievement_unlocked"])
        self.assertEqual(duplicate, {"applied": False, "duplicate": True})

        unlocked = self.service.record_progress_event(
            play_session_id, "achievement:1", "achievement", "first_record"
        )
        already_unlocked = self.service.record_progress_event(
            play_session_id, "achievement:2", "achievement", "first_record"
        )
        unknown = self.service.record_progress_event(
            play_session_id, "achievement:3", "achievement", "not_in_catalog"
        )
        self.assertTrue(unlocked["achievement_unlocked"])
        self.assertFalse(already_unlocked["achievement_unlocked"])
        self.assertEqual(unknown["reason"], "unknown_achievement")

        progress = self.service.progress(auth)
        self.assertEqual(progress["death_count"], 1)
        self.assertEqual(progress["deaths"], 1)
        self.assertEqual(
            [item["code"] for item in progress["achievements"]],
            ["first_death", "first_record"],
        )
        with self.service.db.connection() as connection:
            count = connection.execute("SELECT COUNT(*) FROM progress_events").fetchone()[0]
        self.assertEqual(count, 3)

    def test_ended_session_rejects_death_and_achievement_events(self) -> None:
        auth, _ = self.login("ended-events-user")
        ticket = self.service.create_game_ticket(auth)["ticket"]
        play_session_id = self.service.redeem_game_ticket(ticket)["play_session_id"]
        self.service.end_play_session(play_session_id)

        for event_id, event_type, achievement in (
            ("late-death", "death", None),
            ("late-achievement", "achievement", "escaped"),
        ):
            with self.subTest(event_type=event_type):
                with self.assertRaises(ApiError) as ended:
                    self.service.record_progress_event(
                        play_session_id, event_id, event_type, achievement
                    )
                self.assertEqual(ended.exception.code, "play_session_ended")
        progress = self.service.progress(auth)
        self.assertEqual(progress["death_count"], 0)
        self.assertEqual(progress["achievements"], [])

    def test_public_service_has_no_arbitrary_stat_mutator(self) -> None:
        self.assertFalse(hasattr(self.service, "set_progress"))
        self.assertFalse(hasattr(self.service, "increment_playtime"))
        self.assertFalse(hasattr(self.service, "unlock_achievement"))


if __name__ == "__main__":
    import unittest

    unittest.main()

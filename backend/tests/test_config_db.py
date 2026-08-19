from __future__ import annotations

import sqlite3
import tempfile
import unittest
from pathlib import Path

from creepy_accounts import AccountService, Config, ConfigError
from creepy_accounts.db import Database

from tests.helpers import FakeGoogleExchanger, FakeGoogleVerifier, MutableClock


class ConfigurationAndDatabaseTests(unittest.TestCase):
    def base_environment(self, database_path: Path) -> dict[str, str]:
        return {
            "CREEPY_ACCOUNT_DB_PATH": str(database_path),
            "CREEPY_ACCOUNT_PUBLIC_BASE_URL": "https://creepy-pasta.example",
            "CREEPY_GOOGLE_CLIENT_ID": "client.apps.googleusercontent.com",
            "CREEPY_GOOGLE_CLIENT_SECRET": "server-secret",
            "CREEPY_ACCOUNT_INTERNAL_SECRET": "A" * 48,
            "CREEPY_ACCOUNT_ALLOWED_ORIGINS": "https://creepy-pasta.example",
        }

    def test_environment_configuration_and_setup_pending(self) -> None:
        with tempfile.TemporaryDirectory() as temporary_directory:
            path = Path(temporary_directory) / "account.db"
            config = Config.from_env(self.base_environment(path))
            self.assertEqual(config.db_path, path)
            self.assertEqual(
                config.google_callback_url,
                "https://creepy-pasta.example/api/v1/auth/google/callback",
            )
            self.assertEqual(config.allowed_origins, ("https://creepy-pasta.example",))

            pending_env = self.base_environment(path)
            pending_env.pop("CREEPY_GOOGLE_CLIENT_ID")
            pending_env.pop("CREEPY_GOOGLE_CLIENT_SECRET")
            pending_env["CREEPY_ACCOUNT_ALLOW_SETUP_PENDING"] = "1"
            pending = Config.from_env(pending_env)
            service = AccountService(
                pending,
                exchanger=FakeGoogleExchanger(),
                verifier=FakeGoogleVerifier(),
                clock=MutableClock(),
            )
            ready, details = service.readiness()
            self.assertFalse(ready)
            self.assertEqual(details["status"], "setup_pending")
            self.assertEqual(
                details["missing"],
                ["CREEPY_GOOGLE_CLIENT_ID", "CREEPY_GOOGLE_CLIENT_SECRET"],
            )

    def test_unsafe_or_incomplete_configuration_is_rejected(self) -> None:
        with tempfile.TemporaryDirectory() as temporary_directory:
            path = Path(temporary_directory) / "account.db"
            environment = self.base_environment(path)
            environment.pop("CREEPY_GOOGLE_CLIENT_SECRET")
            with self.assertRaises(ConfigError):
                Config.from_env(environment)

            environment = self.base_environment(path)
            environment["CREEPY_ACCOUNT_INTERNAL_SECRET"] = "short"
            with self.assertRaises(ConfigError):
                Config.from_env(environment)

            environment = self.base_environment(path)
            environment["CREEPY_ACCOUNT_INTERNAL_SECRET"] = "A" * 32 + "\nB"
            with self.assertRaises(ConfigError):
                Config.from_env(environment)

            environment = self.base_environment(path)
            environment["CREEPY_ACCOUNT_PUBLIC_BASE_URL"] = "http://public.example"
            with self.assertRaises(ConfigError):
                Config.from_env(environment)

            environment = self.base_environment(path)
            environment["CREEPY_ACCOUNT_ALLOWED_ORIGINS"] = "https://ok.example/path"
            with self.assertRaises(ConfigError):
                Config.from_env(environment)

    def test_migrations_are_idempotent_and_seed_exact_achievements(self) -> None:
        with tempfile.TemporaryDirectory() as temporary_directory:
            database = Database(Path(temporary_directory) / "account.db")
            database.initialize()
            database.initialize()
            self.assertTrue(database.is_ready())
            with database.connection() as connection:
                migrations = connection.execute(
                    "SELECT version, name FROM schema_migrations ORDER BY version"
                ).fetchall()
                codes = [
                    row[0]
                    for row in connection.execute(
                        "SELECT code FROM achievement_definitions ORDER BY code"
                    )
                ]
                foreign_keys = connection.execute("PRAGMA foreign_keys").fetchone()[0]
                journal_mode = connection.execute("PRAGMA journal_mode").fetchone()[0]
            self.assertEqual(
                [(row[0], row[1]) for row in migrations],
                [
                    (1, "001_initial.sql"),
                    (2, "002_one_active_play_session.sql"),
                    (3, "003_play_session_activity.sql"),
                ],
            )
            self.assertEqual(
                codes,
                ["escaped", "field_researcher", "first_death", "first_record"],
            )
            self.assertEqual(foreign_keys, 1)
            self.assertEqual(journal_mode.lower(), "wal")

    def test_one_active_session_migration_repairs_legacy_duplicates(self) -> None:
        with tempfile.TemporaryDirectory() as temporary_directory:
            database = Database(Path(temporary_directory) / "account.db")
            database.initialize()
            with database.transaction() as connection:
                connection.execute("DROP INDEX play_sessions_one_active_user_idx")
                connection.execute("DELETE FROM schema_migrations WHERE version = 2")
                connection.execute(
                    """
                    INSERT INTO users(
                        id, display_name, avatar_url, friend_code, status,
                        created_at, updated_at, last_login_at
                    ) VALUES ('legacy-user', 'Legacy', NULL, 'CP-AAAAAAAAAAAAAAAA',
                              'active', 100, 100, 100)
                    """
                )
                connection.execute(
                    "INSERT INTO player_stats(user_id, updated_at) VALUES ('legacy-user', 100)"
                )
                for session_id, started_at in (
                    ("00000000-0000-4000-8000-000000000001", 100),
                    ("00000000-0000-4000-8000-000000000002", 200),
                ):
                    connection.execute(
                        """
                        INSERT INTO play_sessions(
                            id, user_id, game_server_id, started_at,
                            last_heartbeat_at, last_credited_at, credited_seconds
                        ) VALUES (?, 'legacy-user', 'legacy-server', ?, ?, ?, 0)
                        """,
                        (session_id, started_at, started_at, started_at),
                    )

            database.initialize()
            with database.transaction() as connection:
                active = connection.execute(
                    "SELECT id FROM play_sessions WHERE user_id = 'legacy-user' AND ended_at IS NULL"
                ).fetchall()
                self.assertEqual(
                    [row["id"] for row in active],
                    ["00000000-0000-4000-8000-000000000002"],
                )
                with self.assertRaises(sqlite3.IntegrityError):
                    connection.execute(
                        """
                        INSERT INTO play_sessions(
                            id, user_id, game_server_id, started_at,
                            last_heartbeat_at, last_credited_at, credited_seconds
                        ) VALUES ('00000000-0000-4000-8000-000000000003',
                                  'legacy-user', 'legacy-server', 300, 300, 300, 0)
                        """
                    )


if __name__ == "__main__":
    unittest.main()

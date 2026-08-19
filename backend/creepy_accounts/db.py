from __future__ import annotations

import os
import sqlite3
from contextlib import contextmanager
from pathlib import Path
from typing import Iterator


class Database:
    def __init__(self, path: Path, migrations_dir: Path | None = None) -> None:
        self.path = path
        self.migrations_dir = migrations_dir or Path(__file__).with_name("migrations")

    def connect(self) -> sqlite3.Connection:
        connection = sqlite3.connect(self.path, timeout=5.0, isolation_level=None)
        connection.row_factory = sqlite3.Row
        connection.execute("PRAGMA foreign_keys = ON")
        connection.execute("PRAGMA busy_timeout = 5000")
        connection.execute("PRAGMA trusted_schema = OFF")
        return connection

    def initialize(self) -> None:
        self.path.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
        connection = self.connect()
        try:
            connection.execute("PRAGMA journal_mode = WAL")
            connection.execute("PRAGMA synchronous = FULL")
            connection.execute(
                "CREATE TABLE IF NOT EXISTS schema_migrations ("
                "version INTEGER PRIMARY KEY, name TEXT NOT NULL, applied_at INTEGER NOT NULL)"
            )
            applied = {
                int(row["version"])
                for row in connection.execute("SELECT version FROM schema_migrations")
            }
            for migration_path in sorted(self.migrations_dir.glob("[0-9][0-9][0-9]_*.sql")):
                version = int(migration_path.name.split("_", 1)[0])
                if version in applied:
                    continue
                sql = migration_path.read_text(encoding="utf-8")
                escaped_name = migration_path.name.replace("'", "''")
                script = (
                    "BEGIN IMMEDIATE;\n"
                    f"{sql}\n"
                    "INSERT INTO schema_migrations(version, name, applied_at) "
                    f"VALUES ({version}, '{escaped_name}', CAST(strftime('%s','now') AS INTEGER));\n"
                    "COMMIT;"
                )
                try:
                    connection.executescript(script)
                except Exception:
                    if connection.in_transaction:
                        connection.execute("ROLLBACK")
                    raise
        finally:
            connection.close()
        try:
            os.chmod(self.path, 0o600)
        except OSError:
            # Windows ACLs and some mounted filesystems do not implement POSIX modes.
            pass

    def is_ready(self) -> bool:
        try:
            with self.connection() as connection:
                row = connection.execute("PRAGMA quick_check(1)").fetchone()
                migration = connection.execute(
                    "SELECT MAX(version) AS version FROM schema_migrations"
                ).fetchone()
                return bool(row and row[0] == "ok" and migration and migration["version"] is not None)
        except sqlite3.Error:
            return False

    @contextmanager
    def connection(self) -> Iterator[sqlite3.Connection]:
        connection = self.connect()
        try:
            yield connection
        finally:
            connection.close()

    @contextmanager
    def transaction(self) -> Iterator[sqlite3.Connection]:
        with self.connection() as connection:
            connection.execute("BEGIN IMMEDIATE")
            try:
                yield connection
            except Exception:
                connection.execute("ROLLBACK")
                raise
            else:
                connection.execute("COMMIT")

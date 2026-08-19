#!/usr/bin/env python3
"""Create an online SQLite backup and retain only the newest snapshots."""

from __future__ import annotations

import os
from pathlib import Path
import re
import sqlite3
import sys
from contextlib import closing
from datetime import datetime, timezone


def _positive_int(name: str, default: int) -> int:
    raw_value = os.environ.get(name, str(default))
    try:
        value = int(raw_value)
    except ValueError as error:
        raise ValueError(f"{name} must be an integer") from error
    if value < 1:
        raise ValueError(f"{name} must be at least 1")
    return value


def main() -> int:
    source_path = Path(
        os.environ.get(
            "CREEPY_ACCOUNT_DB_PATH",
            "/var/lib/creepy-pasta/accounts.db",
        )
    )
    backup_dir = Path(
        os.environ.get(
            "CREEPY_ACCOUNT_BACKUP_DIR",
            "/var/backups/creepy-pasta",
        )
    )
    keep_count = _positive_int("CREEPY_ACCOUNT_BACKUP_KEEP", 14)

    if not source_path.is_file():
        print(f"Account database does not exist yet: {source_path}")
        return 0

    backup_dir.mkdir(parents=True, exist_ok=True, mode=0o700)
    timestamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%S%fZ")
    destination = backup_dir / f"accounts-{timestamp}.db"
    temporary = backup_dir / f".{destination.name}.tmp"
    temporary.unlink(missing_ok=True)

    source_uri = f"file:{source_path.as_posix()}?mode=ro"
    try:
        with closing(sqlite3.connect(source_uri, uri=True, timeout=30.0)) as source:
            with closing(sqlite3.connect(temporary, timeout=30.0)) as target:
                source.backup(target)
                integrity = target.execute("PRAGMA integrity_check").fetchone()
                if not integrity or integrity[0] != "ok":
                    raise RuntimeError("SQLite backup failed its integrity check")
        os.chmod(temporary, 0o600)
        os.replace(temporary, destination)
    finally:
        temporary.unlink(missing_ok=True)

    snapshot_name = re.compile(r"accounts-\d{8}T\d{6}(?:\d{6})?Z\.db\Z")
    snapshots = sorted(
        (path for path in backup_dir.glob("accounts-*.db") if snapshot_name.fullmatch(path.name)),
        key=lambda path: path.name,
        reverse=True,
    )
    for expired in snapshots[keep_count:]:
        expired.unlink()

    print(f"Created account database backup: {destination}")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as error:  # systemd records the type without exposing secrets.
        print(f"Account database backup failed: {type(error).__name__}: {error}", file=sys.stderr)
        raise SystemExit(1)

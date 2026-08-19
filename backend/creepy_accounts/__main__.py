from __future__ import annotations

import logging
import signal
import sqlite3
import sys
import threading

from .config import Config, ConfigError
from .http_server import create_http_server
from .service import AccountService


def main() -> int:
    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s %(levelname)s %(name)s %(message)s",
    )
    if sys.version_info < (3, 12):
        logging.getLogger("creepy_accounts").error("Python 3.12 or newer is required")
        return 2
    if sqlite3.sqlite_version_info < (3, 37, 0):
        logging.getLogger("creepy_accounts").error("SQLite 3.37 or newer is required")
        return 2
    try:
        config = Config.from_env()
        service = AccountService(config)
        server = create_http_server(service)
    except (ConfigError, OSError, sqlite3.Error) as exc:
        logging.getLogger("creepy_accounts").error("startup failed: %s", exc)
        return 2

    logger = logging.getLogger("creepy_accounts")
    ready, readiness = service.readiness()
    if ready:
        logger.info("account service ready on %s:%d", *server.server_address[:2])
    else:
        logger.warning("account service started but is not ready: %s", readiness.get("status"))

    stopping = threading.Event()

    def request_shutdown(_signum: int, _frame: object) -> None:
        if stopping.is_set():
            return
        stopping.set()
        threading.Thread(target=server.shutdown, name="account-shutdown", daemon=True).start()

    for signal_name in ("SIGTERM", "SIGINT"):
        if hasattr(signal, signal_name):
            signal.signal(getattr(signal, signal_name), request_shutdown)

    try:
        server.serve_forever(poll_interval=0.5)
    finally:
        server.server_close()
        logger.info("account service stopped")
    return 0


if __name__ == "__main__":
    sys.exit(main())

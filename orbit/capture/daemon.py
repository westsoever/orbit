"""Orbit capture daemon — listens for app-focus events and logs AX context to SQLite.

Entry points::

    orbit start [--no-embed] [--db PATH]
    python -m orbit.capture.daemon --db ./orbit.db [--no-embed]

DB selection (see ``orbit.storage.db``):

- Default: ``open_db`` with embed worker when SQLite extensions are available.
- ``--no-embed`` or missing extension support: ``open_db_plain``, capture + FTS only.

Requires macOS Accessibility permission (see ``orbit/capture/PERMISSIONS.md``).
"""
from __future__ import annotations

import argparse
import logging
import queue
import sys
import threading

from PyObjCTools import AppHelper
from orbit.capture.listener import AppFocusListener
from orbit.capture.worker import run_capture_worker
from orbit.storage.db import open_db, open_db_plain, sqlite_supports_extensions
from orbit.ui.statusbar import OrbitStatusBar

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)-8s %(name)s — %(message)s",
)
logger = logging.getLogger(__name__)


def main() -> None:
    parser = argparse.ArgumentParser(description="Orbit capture daemon")
    parser.add_argument("--db", default="./orbit.db", help="SQLite DB path")
    parser.add_argument("--no-embed", action="store_true", help="Skip embedding worker")
    parser.add_argument(
        "--max-depth",
        type=int,
        default=None,
        help="Override AX tree depth (default: 12 native, 24 Electron, 20 Chromium)",
    )
    parser.add_argument(
        "--browser-bridge-port",
        type=int,
        default=8765,
        help="Localhost port for browser companion extension (default: 8765)",
    )
    parser.add_argument(
        "--no-browser-bridge",
        action="store_true",
        help="Disable browser extension HTTP ingest",
    )
    parser.add_argument(
        "--ocr",
        action="store_true",
        help="Enable Tier 4 OCR fallback (also set tier_ocr in ~/.orbit/policy.json)",
    )
    parser.add_argument(
        "--no-fsevents",
        action="store_true",
        help="Disable FSEvents workspace capture (even if tier_fsevents in policy)",
    )
    parser.add_argument(
        "--no-statusbar",
        action="store_true",
        help="Skip the Python menu bar indicator",
    )
    parser.add_argument(
        "--purge-retention",
        action="store_true",
        help="On startup, delete capture events older than policy retention_days",
    )
    args = parser.parse_args()

    from orbit.ui.macos_app import hide_from_dock

    hide_from_dock()

    from orbit.daemon_ctl import is_daemon_running
    from orbit.daemon_pid import read_pid

    health_url = f"http://127.0.0.1:{args.browser_bridge_port}/health"
    if is_daemon_running(health_url):
        pid = read_pid()
        logger.error(
            "Another Orbit daemon is already running (pid %s).",
            pid if pid is not None else "unknown",
        )
        sys.exit(1)

    from orbit.capture.policy import load_policy

    policy = load_policy()
    if args.ocr:
        policy.tier_ocr = True

    use_embed = not args.no_embed and sqlite_supports_extensions()
    if args.no_embed:
        con, lock = open_db_plain(args.db)
        logger.info("Database opened at %s (capture-only, no embeddings)", args.db)
    elif use_embed:
        con, lock = open_db(args.db)
        logger.info(
            "Database opened at %s (embeddings enabled — use --no-embed for lower CPU/RAM)",
            args.db,
        )
    else:
        con, lock = open_db_plain(args.db)
        logger.warning(
            "SQLite extensions unavailable on %s; running capture-only (no embeddings). "
            "Use Homebrew Python for full embed support — see README.",
            sys.executable,
        )

    if args.purge_retention:
        from orbit.privacy import purge_older_than

        n = purge_older_than(con, policy.retention_days)
        if n:
            logger.info("Purged %d events older than %d days", n, policy.retention_days)

    if args.no_statusbar:
        statusbar = None
    else:
        statusbar = OrbitStatusBar()
        logger.info("Status bar initialized")

    capture_active = threading.Event()

    focus_queue: queue.Queue = queue.Queue()
    embed_queue: queue.Queue | None = None if not use_embed else queue.Queue()

    listener = AppFocusListener(q=focus_queue)

    def _request_shutdown() -> None:
        from PyObjCTools import AppHelper

        AppHelper.callAfter(AppHelper.stopEventLoop)

    browser_queue: queue.Queue | None = None
    browser_server = None
    if not args.no_browser_bridge:
        from orbit.browser_bridge.server import start_browser_bridge
        from orbit.browser_bridge.worker import run_browser_worker

        browser_queue = queue.Queue()
        browser_server, _ = start_browser_bridge(
            browser_queue,
            port=args.browser_bridge_port,
            db_ref=(con, lock),
            capture_active_ref=capture_active,
            shutdown_hook=_request_shutdown,
        )
        browser_thread = threading.Thread(
            target=run_browser_worker,
            args=(browser_queue, embed_queue, con, lock),
            daemon=True,
            name="browser-worker",
        )
        browser_thread.start()

    capture_thread = threading.Thread(
        target=run_capture_worker,
        args=(focus_queue, embed_queue, con, lock),
        kwargs={
            "max_depth": args.max_depth,
            "policy": policy,
            "on_capture_start": lambda: (
                capture_active.set(),
                statusbar.set_active() if statusbar else None,
            ),
            "on_capture_done": lambda: (
                capture_active.clear(),
                statusbar.set_idle() if statusbar else None,
            ),
        },
        daemon=True,
        name="capture-worker",
    )
    capture_thread.start()

    fs_listener = None
    fs_queue: queue.Queue | None = None
    if policy.tier_fsevents and not args.no_fsevents and policy.watch_roots:
        from orbit.capture.fsevents_listener import FSEventsListener
        from orbit.capture.fs_worker import run_fs_worker

        fs_queue = queue.Queue()
        fs_thread = threading.Thread(
            target=run_fs_worker,
            args=(fs_queue, con, lock),
            daemon=True,
            name="fs-worker",
        )
        fs_thread.start()
        fs_listener = FSEventsListener(fs_queue, policy.watch_roots)

    if embed_queue is not None:
        from orbit.embed.worker import run_embedding_worker

        embed_thread = threading.Thread(
            target=run_embedding_worker,
            args=(embed_queue, con, lock),
            daemon=True,
            name="embed-worker",
        )
        embed_thread.start()

    from orbit.daemon_pid import write_pid

    write_pid()
    logger.info("Orbit daemon running. Switch app focus to capture context. Ctrl-C to stop.")
    try:
        AppHelper.runConsoleEventLoop(installInterrupt=True)
    finally:
        logger.info("Shutting down...")
        listener.stop()
        focus_queue.put(None)
        if browser_queue is not None:
            browser_queue.put(None)
        if fs_queue is not None:
            fs_queue.put(None)
        if fs_listener is not None:
            fs_listener.stop()
        if browser_server is not None:
            from orbit.browser_bridge.server import stop_browser_bridge

            stop_browser_bridge(browser_server)
        if embed_queue is not None:
            embed_queue.put(None)
        from orbit.daemon_pid import remove_pid

        remove_pid()


if __name__ == "__main__":
    main()

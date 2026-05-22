"""
Run with: python -m orbit.capture.daemon --db ./orbit.db [--no-embed]
"""
from __future__ import annotations

import argparse
import logging
import queue
import threading

from AppKit import NSRunLoop, NSDate
from orbit.capture.listener import AppFocusListener
from orbit.capture.worker import run_capture_worker
from orbit.embed.worker import run_embedding_worker
from orbit.storage.db import open_db
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
    args = parser.parse_args()

    con, lock = open_db(args.db)
    logger.info("Database opened at %s", args.db)

    statusbar = OrbitStatusBar()
    logger.info("Status bar initialized")

    focus_queue: queue.Queue = queue.Queue()
    embed_queue: queue.Queue | None = None if args.no_embed else queue.Queue()

    listener = AppFocusListener(q=focus_queue)

    capture_thread = threading.Thread(
        target=run_capture_worker,
        args=(focus_queue, embed_queue, con, lock),
        kwargs={
            "on_capture_start": statusbar.set_active,
            "on_capture_done": statusbar.set_idle,
        },
        daemon=True,
        name="capture-worker",
    )
    capture_thread.start()

    if embed_queue is not None:
        embed_thread = threading.Thread(
            target=run_embedding_worker,
            args=(embed_queue, con, lock),
            daemon=True,
            name="embed-worker",
        )
        embed_thread.start()

    logger.info("Orbit daemon running. Switch app focus to capture context. Ctrl-C to stop.")
    try:
        while True:
            NSRunLoop.currentRunLoop().runUntilDate_(NSDate.dateWithTimeIntervalSinceNow_(2.0))
    except KeyboardInterrupt:
        logger.info("Shutting down...")
        focus_queue.put(None)
        if embed_queue is not None:
            embed_queue.put(None)


if __name__ == "__main__":
    main()

"""HTTP ingest for Orbit browser companion extension (Tier 2).

Local-only: binds 127.0.0.1 — no cloud exfiltration.
Spec: plans/03-universal-capture.md Phase 2B; orbit-context.md L25.
"""
from __future__ import annotations

import json
import logging
import queue
import threading
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

logger = logging.getLogger(__name__)

DEFAULT_PORT = 8765


class _BridgeHandler(BaseHTTPRequestHandler):
    def log_message(self, format: str, *args) -> None:  # noqa: A003
        logger.debug("browser-bridge: " + format, *args)

    def do_POST(self) -> None:
        if self.path != "/capture":
            self.send_error(404)
            return
        length = int(self.headers.get("Content-Length", 0))
        if length <= 0 or length > 65536:
            self.send_error(400, "invalid body size")
            return
        try:
            payload = json.loads(self.rfile.read(length).decode("utf-8"))
        except (json.JSONDecodeError, UnicodeDecodeError):
            self.send_error(400, "invalid json")
            return
        if not isinstance(payload, dict):
            self.send_error(400, "expected object")
            return
        url = payload.get("url")
        if not url or not isinstance(url, str):
            self.send_error(400, "url required")
            return
        self.server.event_queue.put(payload)  # type: ignore[attr-defined]
        self.send_response(204)
        self.end_headers()

    def do_GET(self) -> None:
        if self.path == "/health":
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            self.wfile.write(b'{"ok":true}')
            return
        self.send_error(404)


def start_browser_bridge(
    event_queue: queue.Queue,
    port: int = DEFAULT_PORT,
) -> tuple[ThreadingHTTPServer, threading.Thread]:
    """Start localhost HTTP server; returns (server, thread)."""
    server = ThreadingHTTPServer(("127.0.0.1", port), _BridgeHandler)
    server.event_queue = event_queue  # type: ignore[attr-defined]
    thread = threading.Thread(
        target=server.serve_forever,
        name="browser-bridge",
        daemon=True,
    )
    thread.start()
    logger.info("Browser bridge listening on http://127.0.0.1:%d/capture", port)
    return server, thread


def stop_browser_bridge(server: ThreadingHTTPServer) -> None:
    server.shutdown()

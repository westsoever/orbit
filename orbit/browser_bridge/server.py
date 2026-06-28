"""HTTP ingest for Orbit browser companion extension (Tier 2).

Local-only: binds 127.0.0.1 — no cloud exfiltration.
Spec: plans/03-universal-capture.md Phase 2B; orbit-context.md L25.
Orbit Access API: plans/orbitaccessappdesign.md Appendix §10.
"""
from __future__ import annotations

import json
import logging
import queue
import re
import sqlite3
import threading
from dataclasses import asdict
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from typing import Any, Callable
from urllib.parse import parse_qs, urlparse

from orbit.check.log import get_pending_today, migrate, update_status
from orbit.search.types import Hit

logger = logging.getLogger(__name__)

DEFAULT_PORT = 8765
DbRef = tuple[sqlite3.Connection, threading.Lock]
CaptureActiveRef = Callable[[], bool] | threading.Event

_CHAT_SYSTEM = """\
You are Orbit, a personal context assistant. Answer the user's question using \
the provided context snippets from their recent screen activity. Be concise and \
grounded in the snippets; say when context is insufficient.\
"""

_TASK_APPROVE_RE = re.compile(r"^/api/task/(\d+)/approve$")
_TASK_SKIP_RE = re.compile(r"^/api/task/(\d+)/skip$")


def _capture_active(ref: CaptureActiveRef | None) -> bool:
    if ref is None:
        return False
    if isinstance(ref, threading.Event):
        return ref.is_set()
    return bool(ref())


def _hit_to_dict(hit: Hit) -> dict[str, Any]:
    return asdict(hit)


def _task_to_dict(log_id: int, task: Any) -> dict[str, Any]:
    return {
        "id": log_id,
        "title": task.title,
        "description": task.description,
        "original_prompt": task.suggested_prompt,
        "agent_type": task.agent_type,
        "confidence": task.confidence,
        "status": "detected",
    }


def _read_json_body(handler: BaseHTTPRequestHandler, max_size: int = 65536) -> dict[str, Any] | None:
    length = int(handler.headers.get("Content-Length", 0))
    if length <= 0 or length > max_size:
        handler.send_error(400, "invalid body size")
        return None
    try:
        payload = json.loads(handler.rfile.read(length).decode("utf-8"))
    except (json.JSONDecodeError, UnicodeDecodeError):
        handler.send_error(400, "invalid json")
        return None
    if not isinstance(payload, dict):
        handler.send_error(400, "expected object")
        return None
    return payload


def _send_json(handler: BaseHTTPRequestHandler, status: int, payload: Any) -> None:
    body = json.dumps(payload).encode("utf-8")
    handler.send_response(status)
    handler.send_header("Content-Type", "application/json")
    handler.send_header("Content-Length", str(len(body)))
    handler.end_headers()
    handler.wfile.write(body)


def _require_db(handler: BaseHTTPRequestHandler, server: ThreadingHTTPServer) -> DbRef | None:
    db_ref: DbRef | None = getattr(server, "db_ref", None)
    if db_ref is None:
        _send_json(handler, 503, {"error": "database unavailable"})
        return None
    return db_ref


def _build_chat_context(hits: list[Hit]) -> str:
    if not hits:
        return "(no matching context found)"
    parts = []
    for i, hit in enumerate(hits[:8], start=1):
        parts.append(
            f"[{i}] {hit.app_name} — {hit.window_title or 'untitled'}\n"
            f"{hit.snippet_html}"
        )
    return "\n\n".join(parts)


class _BridgeHandler(BaseHTTPRequestHandler):
    def log_message(self, format: str, *args) -> None:  # noqa: A003
        logger.debug("browser-bridge: " + format, *args)

    def do_POST(self) -> None:
        path = urlparse(self.path).path
        if path == "/capture":
            self._handle_capture()
            return
        if path == "/api/chat":
            self._handle_chat()
            return
        if path == "/api/shutdown":
            self._handle_shutdown()
            return
        match = _TASK_APPROVE_RE.match(path)
        if match:
            self._handle_task_approve(int(match.group(1)))
            return
        match = _TASK_SKIP_RE.match(path)
        if match:
            self._handle_task_skip(int(match.group(1)))
            return
        self.send_error(404)

    def do_GET(self) -> None:
        path = urlparse(self.path).path
        if path == "/health":
            _send_json(self, 200, {"ok": True})
            return
        if path == "/api/status":
            self._handle_status()
            return
        if path == "/api/tasks/pending":
            self._handle_tasks_pending()
            return
        if path == "/api/search":
            self._handle_search()
            return
        self.send_error(404)

    def _handle_capture(self) -> None:
        payload = _read_json_body(self)
        if payload is None:
            return
        url = payload.get("url")
        if not url or not isinstance(url, str):
            self.send_error(400, "url required")
            return
        self.server.event_queue.put(payload)  # type: ignore[attr-defined]
        self.send_response(204)
        self.end_headers()

    def _handle_status(self) -> None:
        ref: CaptureActiveRef | None = getattr(self.server, "capture_active_ref", None)
        _send_json(self, 200, {"ok": True, "capture_active": _capture_active(ref)})

    def _handle_shutdown(self) -> None:
        shutdown_hook = getattr(self.server, "shutdown_hook", None)
        if shutdown_hook is None:
            self.send_error(503, "shutdown unavailable")
            return
        self.send_response(204)
        self.end_headers()
        shutdown_hook()

    def _handle_tasks_pending(self) -> None:
        db_ref = _require_db(self, self.server)
        if db_ref is None:
            return
        con, lock = db_ref
        tasks = [_task_to_dict(log_id, task) for log_id, task in get_pending_today(con, lock)]
        _send_json(self, 200, tasks)

    def _handle_task_approve(self, task_id: int) -> None:
        db_ref = _require_db(self, self.server)
        if db_ref is None:
            return
        payload = _read_json_body(self)
        if payload is None:
            return
        approved_prompt = payload.get("approved_prompt")
        if not approved_prompt or not isinstance(approved_prompt, str):
            self.send_error(400, "approved_prompt required")
            return
        con, lock = db_ref
        with lock:
            row = con.execute(
                "SELECT title FROM task_log WHERE id = ?",
                (task_id,),
            ).fetchone()
        title = (row["title"] if row and row["title"] else "task")
        update_status(con, lock, task_id, "approved", approved_prompt=approved_prompt)
        try:
            from orbit.check.dispatch import dispatch

            exit_code = dispatch(approved_prompt, title=title)
        except Exception as exc:
            logger.exception("task dispatch failed for id=%s", task_id)
            _send_json(self, 503, {"error": str(exc), "id": task_id, "status": "approved"})
            return
        update_status(con, lock, task_id, "dispatched", exit_code=exit_code)
        _send_json(
            self,
            200,
            {"ok": True, "id": task_id, "status": "dispatched", "exit_code": exit_code},
        )

    def _handle_task_skip(self, task_id: int) -> None:
        db_ref = _require_db(self, self.server)
        if db_ref is None:
            return
        con, lock = db_ref
        update_status(con, lock, task_id, "skipped")
        _send_json(self, 200, {"ok": True, "id": task_id, "status": "skipped"})

    def _handle_search(self) -> None:
        db_ref = _require_db(self, self.server)
        if db_ref is None:
            return
        params = parse_qs(urlparse(self.path).query)
        q = (params.get("q") or [""])[0].strip()
        if not q:
            self.send_error(400, "q required")
            return
        try:
            limit = int((params.get("limit") or ["20"])[0])
        except ValueError:
            self.send_error(400, "invalid limit")
            return
        con, _lock = db_ref
        try:
            from orbit.search.hybrid import search_hybrid

            hits = [_hit_to_dict(h) for h in search_hybrid(con, q, limit=limit)]
        except Exception as exc:
            logger.exception("search failed")
            _send_json(self, 503, {"error": str(exc)})
            return
        _send_json(self, 200, hits)

    def _handle_chat(self) -> None:
        db_ref = _require_db(self, self.server)
        if db_ref is None:
            return
        payload = _read_json_body(self)
        if payload is None:
            return
        query = payload.get("query")
        if not query or not isinstance(query, str):
            self.send_error(400, "query required")
            return
        con, _lock = db_ref
        try:
            from orbit.search.hybrid import search_hybrid

            hits = search_hybrid(con, query, limit=8)
        except Exception as exc:
            logger.exception("chat search failed")
            _send_json(self, 503, {"error": str(exc)})
            return
        context = _build_chat_context(hits)
        user_msg = f"Context:\n{context}\n\nQuestion: {query}"
        try:
            from orbit.check.llm import complete

            answer = complete(_CHAT_SYSTEM, user_msg)
        except Exception as exc:
            logger.exception("chat completion failed")
            _send_json(self, 503, {"error": str(exc)})
            return
        self._stream_chat_sse(answer or "", hits)

    def _stream_chat_sse(self, text: str, hits: list[Hit]) -> None:
        self.send_response(200)
        self.send_header("Content-Type", "text/event-stream")
        self.send_header("Cache-Control", "no-cache")
        self.send_header("Connection", "keep-alive")
        self.end_headers()
        events = [
            ("delta", {"text": text}),
            ("sources", {"hits": [_hit_to_dict(h) for h in hits]}),
            ("done", {}),
        ]
        for name, data in events:
            chunk = f"event: {name}\ndata: {json.dumps(data)}\n\n".encode("utf-8")
            self.wfile.write(chunk)
            self.wfile.flush()


def start_browser_bridge(
    event_queue: queue.Queue,
    port: int = DEFAULT_PORT,
    db_ref: DbRef | None = None,
    capture_active_ref: CaptureActiveRef | None = None,
    shutdown_hook: Callable[[], None] | None = None,
) -> tuple[ThreadingHTTPServer, threading.Thread]:
    """Start localhost HTTP server; returns (server, thread)."""
    if db_ref is not None:
        migrate(db_ref[0])
    server = ThreadingHTTPServer(("127.0.0.1", port), _BridgeHandler)
    server.event_queue = event_queue  # type: ignore[attr-defined]
    server.db_ref = db_ref  # type: ignore[attr-defined]
    server.capture_active_ref = capture_active_ref  # type: ignore[attr-defined]
    server.shutdown_hook = shutdown_hook  # type: ignore[attr-defined]
    thread = threading.Thread(
        target=server.serve_forever,
        name="browser-bridge",
        daemon=True,
    )
    thread.start()
    logger.info("Browser bridge listening on http://127.0.0.1:%d", port)
    return server, thread


def stop_browser_bridge(server: ThreadingHTTPServer) -> None:
    server.shutdown()

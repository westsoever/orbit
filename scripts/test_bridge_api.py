#!/usr/bin/env python3
"""Exercise Orbit Access bridge API routes on localhost:8765.

Runs an in-process bridge with a temporary DB (no daemon required).
For live daemon testing, run `orbit start` and use --live.
"""
from __future__ import annotations

import argparse
import json
import queue
import sqlite3
import sys
import tempfile
import threading
import time
import urllib.error
import urllib.parse
import urllib.request
from datetime import datetime, timezone
from pathlib import Path


def _base(port: int) -> str:
    return f"http://127.0.0.1:{port}"


def _request(
    method: str,
    path: str,
    body: dict | None = None,
    port: int = 8765,
    timeout: float = 10,
) -> tuple[int, bytes]:
    data = json.dumps(body).encode("utf-8") if body is not None else None
    headers = {"Content-Type": "application/json"} if data else {}
    req = urllib.request.Request(
        f"{_base(port)}{path}",
        data=data,
        headers=headers,
        method=method,
    )
    try:
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            return resp.status, resp.read()
    except urllib.error.HTTPError as exc:
        return exc.code, exc.read()


def _parse_sse(raw: bytes) -> list[tuple[str, dict]]:
    events: list[tuple[str, dict]] = []
    for block in raw.decode("utf-8").split("\n\n"):
        block = block.strip()
        if not block:
            continue
        event_name = "message"
        data_line = ""
        for line in block.splitlines():
            if line.startswith("event:"):
                event_name = line.split(":", 1)[1].strip()
            elif line.startswith("data:"):
                data_line = line.split(":", 1)[1].strip()
        events.append((event_name, json.loads(data_line) if data_line else {}))
    return events


def _seed_task(con: sqlite3.Connection) -> int:
    ts = datetime.now(timezone.utc).isoformat()
    cur = con.execute(
        "INSERT INTO task_log"
        " (timestamp, title, description, original_prompt, agent_type, status)"
        " VALUES (?, ?, ?, ?, ?, 'detected')",
        (ts, "Test task", "Bridge API test", "Do the thing", "admin"),
    )
    con.commit()
    return int(cur.lastrowid)


def _run_embedded_tests(port: int) -> int:
    from orbit.browser_bridge.server import start_browser_bridge, stop_browser_bridge
    from orbit.storage.db import open_db_plain

    with tempfile.TemporaryDirectory() as tmp:
        db_path = Path(tmp) / "test.db"
        con, lock = open_db_plain(str(db_path))
        capture_active = threading.Event()
        event_q: queue.Queue = queue.Queue()
        server, _ = start_browser_bridge(
            event_q,
            port=port,
            db_ref=(con, lock),
            capture_active_ref=capture_active,
            shutdown_hook=lambda: None,
        )
        task_id = _seed_task(con)
        time.sleep(0.2)
        failures = 0
        try:
            status, body = _request("GET", "/health", port=port)
            if status != 200 or json.loads(body) != {"ok": True}:
                print("FAIL /health", status, body)
                failures += 1
            else:
                print("OK   GET /health")

            status, body = _request("GET", "/api/status", port=port)
            data = json.loads(body)
            if status != 200 or not data.get("ok") or data.get("capture_active") is not False:
                print("FAIL /api/status idle", status, body)
                failures += 1
            else:
                print("OK   GET /api/status (idle)")

            capture_active.set()
            status, body = _request("GET", "/api/status", port=port)
            data = json.loads(body)
            if status != 200 or data.get("capture_active") is not True:
                print("FAIL /api/status active", status, body)
                failures += 1
            else:
                print("OK   GET /api/status (active)")

            status, body = _request("GET", "/api/tasks/pending", port=port)
            tasks = json.loads(body)
            if status != 200 or not isinstance(tasks, list) or not tasks:
                print("FAIL /api/tasks/pending", status, body)
                failures += 1
            else:
                print("OK   GET /api/tasks/pending")

            status, body = _request(
                "POST",
                f"/api/task/{task_id}/approve",
                {"approved_prompt": "Approved prompt text"},
                port=port,
            )
            if status != 200 or json.loads(body).get("status") != "approved":
                print("FAIL approve", status, body)
                failures += 1
            else:
                print("OK   POST /api/task/{id}/approve")

            task_id2 = _seed_task(con)
            status, body = _request("POST", f"/api/task/{task_id2}/skip", port=port)
            if status != 200 or json.loads(body).get("status") != "skipped":
                print("FAIL skip", status, body)
                failures += 1
            else:
                print("OK   POST /api/task/{id}/skip")

            q = urllib.parse.quote("test query")
            try:
                status, body = _request("GET", f"/api/search?q={q}&limit=5", port=port, timeout=120)
            except TimeoutError:
                print("SKIP GET /api/search (model load timed out)")
                status = 0
            if status == 0:
                pass
            elif status == 503:
                print("SKIP GET /api/search (embeddings unavailable:", body.decode()[:80], ")")
            elif status != 200 or not isinstance(json.loads(body), list):
                print("FAIL /api/search", status, body)
                failures += 1
            else:
                print("OK   GET /api/search")

            try:
                status, body = _request(
                    "POST",
                    "/api/chat",
                    {"query": "What did I work on?"},
                    port=port,
                    timeout=120,
                )
            except TimeoutError:
                print("SKIP POST /api/chat (timed out)")
                status = 0
            if status == 0:
                pass
            elif status == 503:
                print("SKIP POST /api/chat (LLM unavailable:", body.decode()[:80], ")")
            elif status != 200:
                print("FAIL /api/chat", status, body)
                failures += 1
            else:
                events = _parse_sse(body)
                names = [e[0] for e in events]
                if names != ["delta", "sources", "done"]:
                    print("FAIL /api/chat SSE events", names)
                    failures += 1
                else:
                    print("OK   POST /api/chat (SSE)")

            status, _ = _request("POST", "/api/shutdown", port=port)
            if status != 204:
                print("FAIL POST /api/shutdown", status)
                failures += 1
            else:
                print("OK   POST /api/shutdown")

            status, _ = _request("GET", "/api/nope", port=port)
            if status != 404:
                print("FAIL unknown route expected 404, got", status)
                failures += 1
            else:
                print("OK   GET unknown route → 404")

            status, _ = _request("POST", "/capture", {"url": "https://example.com"}, port=port)
            if status != 204:
                print("FAIL /capture", status)
                failures += 1
            else:
                print("OK   POST /capture (legacy)")

            no_db_q: queue.Queue = queue.Queue()
            no_db_server, _ = start_browser_bridge(no_db_q, port=port + 1)
            try:
                req = urllib.request.Request(f"http://127.0.0.1:{port + 1}/api/tasks/pending")
                with urllib.request.urlopen(req, timeout=3) as resp:
                    print("FAIL no-db should 503, got", resp.status)
                    failures += 1
            except urllib.error.HTTPError as exc:
                if exc.code == 503:
                    print("OK   GET /api/tasks/pending without db → 503")
                else:
                    print("FAIL no-db expected 503, got", exc.code)
                    failures += 1
            finally:
                stop_browser_bridge(no_db_server)
        finally:
            stop_browser_bridge(server)

        if failures:
            print(f"\n{failures} test(s) failed")
            return 1
        print("\nAll bridge API tests passed")
        return 0


def _run_live_tests() -> int:
    failures = 0
    for method, path, body in [
        ("GET", "/health", None),
        ("GET", "/api/status", None),
        ("GET", "/api/tasks/pending", None),
    ]:
        status, body_bytes = _request(method, path, body)
        label = f"{method} {path}"
        if status == 200:
            print(f"OK   {label}", body_bytes.decode()[:120])
        else:
            print(f"FAIL {label}", status, body_bytes.decode()[:120])
            failures += 1
    return 1 if failures else 0


def main() -> int:
    parser = argparse.ArgumentParser(description="Test Orbit bridge API")
    parser.add_argument("--live", action="store_true", help="Hit running daemon on :8765")
    parser.add_argument("--port", type=int, default=8765, help="Port for embedded server")
    args = parser.parse_args()
    if args.live:
        return _run_live_tests()
    return _run_embedded_tests(args.port)


if __name__ == "__main__":
    raise SystemExit(main())

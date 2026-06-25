"""task_log table helpers."""
from __future__ import annotations
import sqlite3
import threading
from datetime import datetime, timezone

from .detector import Task


def insert_task(con: sqlite3.Connection, lock: threading.Lock, task: Task) -> int:
    ts = datetime.now(timezone.utc).isoformat()
    with lock:
        cur = con.execute(
            "INSERT INTO task_log (timestamp, title, original_prompt, agent_type, status)"
            " VALUES (?, ?, ?, ?, 'detected')",
            (ts, task.title, task.suggested_prompt, task.agent_type),
        )
        return cur.lastrowid


def update_status(
    con: sqlite3.Connection,
    lock: threading.Lock,
    log_id: int,
    status: str,
    approved_prompt: str | None = None,
    exit_code: int | None = None,
) -> None:
    with lock:
        con.execute(
            "UPDATE task_log"
            " SET status = ?,"
            "     approved_prompt = COALESCE(?, approved_prompt),"
            "     exit_code = COALESCE(?, exit_code)"
            " WHERE id = ?",
            (status, approved_prompt, exit_code, log_id),
        )

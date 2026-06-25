"""task_log table helpers."""
from __future__ import annotations
import sqlite3
import threading
from datetime import datetime, date, timezone

from .detector import Task


def migrate(con: sqlite3.Connection) -> None:
    """Add columns introduced after initial schema creation."""
    try:
        con.execute("ALTER TABLE task_log ADD COLUMN description TEXT")
    except sqlite3.OperationalError:
        pass  # already exists


def insert_task(con: sqlite3.Connection, lock: threading.Lock, task: Task) -> int:
    ts = datetime.now(timezone.utc).isoformat()
    with lock:
        cur = con.execute(
            "INSERT INTO task_log"
            " (timestamp, title, description, original_prompt, agent_type, status)"
            " VALUES (?, ?, ?, ?, ?, 'detected')",
            (ts, task.title, task.description, task.suggested_prompt, task.agent_type),
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


def get_pending_today(
    con: sqlite3.Connection,
    lock: threading.Lock,
    report_date: str | None = None,
) -> list[tuple[int, Task]]:
    """Return (log_id, Task) pairs with status='detected' from today's date."""
    d = report_date or date.today().isoformat()
    with lock:
        rows = con.execute(
            "SELECT id, title, description, original_prompt, agent_type"
            " FROM task_log"
            " WHERE status = 'detected'"
            "   AND date(timestamp) = ?",
            (d,),
        ).fetchall()
    result = []
    for row in rows:
        task = Task(
            title=row["title"],
            description=row["description"] or "",
            suggested_prompt=row["original_prompt"] or "",
            agent_type=row["agent_type"] or "admin",
            confidence=1.0,
        )
        result.append((row["id"], task))
    return result

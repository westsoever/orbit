"""Build task-detection context from captured atoms in orbit.db."""
from __future__ import annotations

import sqlite3
from datetime import datetime, timedelta, timezone

from orbit.storage.session import get_active_user_id

_DEFAULT_HOURS = 4
_MAX_ATOMS = 80
_MIN_TEXT_LEN = 8


def read_capture_context(
    con: sqlite3.Connection,
    *,
    hours: int = _DEFAULT_HOURS,
    user_id: str | None = None,
    max_atoms: int = _MAX_ATOMS,
) -> tuple[str, str]:
    """Return (context_text, source_label) from recent captured activity."""
    uid = user_id if user_id is not None else get_active_user_id()
    cutoff = (datetime.now(timezone.utc) - timedelta(hours=hours)).isoformat()

    params: list = [cutoff]
    user_clause = ""
    if uid:
        user_clause = " AND e.user_id = ?"
        params.append(uid)

    rows = con.execute(
        f"""
        SELECT e.timestamp, e.app_name, e.window_title, e.page_url, a.text
        FROM text_atoms a
        JOIN context_events e ON e.id = a.event_id
        WHERE e.timestamp >= ?
          AND length(trim(a.text)) >= ?
          {user_clause}
        ORDER BY e.timestamp DESC, a.id DESC
        LIMIT ?
        """,
        [*params, _MIN_TEXT_LEN, max_atoms],
    ).fetchall()

    if not rows:
        raise FileNotFoundError(
            "No captured context found in the last "
            f"{hours} hour(s). Start capture and switch between a few apps first."
        )

    parts: list[str] = []
    for row in reversed(rows):
        ts = row["timestamp"] or ""
        app = row["app_name"] or "Unknown"
        title = row["window_title"] or row["page_url"] or "untitled"
        text = (row["text"] or "").strip()
        if len(text) < _MIN_TEXT_LEN:
            continue
        snippet = text if len(text) <= 500 else text[:500] + "…"
        parts.append(f"[{ts}] {app} — {title}\n{snippet}")

    label = f"orbit.db (last {hours}h, {len(parts)} snippets)"
    return "\n\n".join(parts), label

"""Privacy utilities — export, delete, retention (GDPR Art. 15/17)."""

from __future__ import annotations

import json
import sqlite3
from datetime import datetime, timedelta, timezone
from pathlib import Path


def export_capture_data(con: sqlite3.Connection, out_path: Path) -> int:
    """Export context_events + text_atoms as JSONL. Returns row count."""
    count = 0
    with out_path.open("w", encoding="utf-8") as f:
        for row in con.execute(
            "SELECT * FROM context_events ORDER BY id"
        ):
            event = dict(row)
            eid = event["id"]
            atoms = [
                dict(a)
                for a in con.execute(
                    "SELECT * FROM text_atoms WHERE event_id = ? ORDER BY id", (eid,)
                )
            ]
            f.write(json.dumps({"event": event, "atoms": atoms}, default=str) + "\n")
            count += 1
    return count


def delete_all_capture_data(con: sqlite3.Connection) -> None:
    con.execute("DELETE FROM text_atoms")
    try:
        con.execute("DELETE FROM fs_events")
    except sqlite3.Error:
        pass
    con.execute("DELETE FROM context_events")
    try:
        con.execute("DELETE FROM vec_atoms")
    except sqlite3.Error:
        pass
    try:
        con.execute("DELETE FROM capture_audit")
    except sqlite3.Error:
        pass
    con.execute("DELETE FROM atoms_fts")


def purge_older_than(con: sqlite3.Connection, days: int) -> int:
    """Delete events older than ``days``. Returns deleted event count."""
    cutoff = (datetime.now(timezone.utc) - timedelta(days=days)).isoformat()
    ids = [
        r[0]
        for r in con.execute(
            "SELECT id FROM context_events WHERE timestamp < ?", (cutoff,)
        ).fetchall()
    ]
    if not ids:
        return 0
    placeholders = ",".join("?" * len(ids))
    atom_ids = [
        r[0]
        for r in con.execute(
            f"SELECT id FROM text_atoms WHERE event_id IN ({placeholders})", ids
        ).fetchall()
    ]
    if atom_ids:
        atom_ph = ",".join("?" * len(atom_ids))
        try:
            con.execute(
                f"DELETE FROM vec_atoms WHERE rowid IN ({atom_ph})", atom_ids
            )
        except sqlite3.Error:
            pass
    con.execute(f"DELETE FROM text_atoms WHERE event_id IN ({placeholders})", ids)
    con.execute(f"DELETE FROM context_events WHERE id IN ({placeholders})", ids)
    try:
        con.execute("DELETE FROM fs_events WHERE timestamp < ?", (cutoff,))
    except sqlite3.Error:
        pass
    try:
        con.execute("DELETE FROM capture_audit WHERE timestamp < ?", (cutoff,))
    except sqlite3.Error:
        pass
    return len(ids)

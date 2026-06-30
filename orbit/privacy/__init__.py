"""Privacy utilities — export, delete, retention (GDPR Art. 15/17)."""

from __future__ import annotations

import json
import sqlite3
from datetime import datetime, timedelta, timezone
from pathlib import Path

from orbit.storage.session import get_active_user_id


def _user_clause(user_id: str | None) -> tuple[str, list]:
    if user_id:
        return " WHERE user_id = ?", [user_id]
    return "", []


def export_capture_data(
    con: sqlite3.Connection, out_path: Path, user_id: str | None = None
) -> int:
    """Export context_events + text_atoms as JSONL. Returns row count."""
    uid = user_id if user_id is not None else get_active_user_id()
    where, params = _user_clause(uid)
    count = 0
    with out_path.open("w", encoding="utf-8") as f:
        for row in con.execute(
            f"SELECT * FROM context_events{where} ORDER BY id", params
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


def delete_all_capture_data(con: sqlite3.Connection, user_id: str | None = None) -> None:
    uid = user_id if user_id is not None else get_active_user_id()
    if uid:
        event_ids = [
            r[0]
            for r in con.execute(
                "SELECT id FROM context_events WHERE user_id = ?", (uid,)
            ).fetchall()
        ]
        if event_ids:
            placeholders = ",".join("?" * len(event_ids))
            atom_ids = [
                r[0]
                for r in con.execute(
                    f"SELECT id FROM text_atoms WHERE event_id IN ({placeholders})",
                    event_ids,
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
            con.execute(
                f"DELETE FROM text_atoms WHERE event_id IN ({placeholders})", event_ids
            )
            con.execute(
                f"DELETE FROM context_events WHERE id IN ({placeholders})", event_ids
            )
        try:
            con.execute("DELETE FROM fs_events WHERE user_id = ?", (uid,))
        except sqlite3.Error:
            pass
        try:
            con.execute("DELETE FROM capture_audit WHERE user_id = ?", (uid,))
        except sqlite3.Error:
            pass
        return

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


def purge_older_than(
    con: sqlite3.Connection, days: int, user_id: str | None = None
) -> int:
    """Delete events older than ``days``. Returns deleted event count."""
    cutoff = (datetime.now(timezone.utc) - timedelta(days=days)).isoformat()
    uid = user_id if user_id is not None else get_active_user_id()
    if uid:
        ids = [
            r[0]
            for r in con.execute(
                "SELECT id FROM context_events WHERE user_id = ? AND timestamp < ?",
                (uid, cutoff),
            ).fetchall()
        ]
    else:
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
        if uid:
            con.execute(
                "DELETE FROM fs_events WHERE user_id = ? AND timestamp < ?",
                (uid, cutoff),
            )
            con.execute(
                "DELETE FROM capture_audit WHERE user_id = ? AND timestamp < ?",
                (uid, cutoff),
            )
        else:
            con.execute("DELETE FROM fs_events WHERE timestamp < ?", (cutoff,))
            con.execute("DELETE FROM capture_audit WHERE timestamp < ?", (cutoff,))
    except sqlite3.Error:
        pass
    return len(ids)

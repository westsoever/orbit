from __future__ import annotations
import sqlite3

def resolve(con: sqlite3.Connection, uri: str) -> dict:
    if uri.startswith("orbit://atom/"):
        atom_id = int(uri.removeprefix("orbit://atom/"))
        row = con.execute(
            """SELECT a.*, e.app_bundle_id, e.app_name, e.window_title, e.timestamp, e.raw_json
                 FROM text_atoms a JOIN context_events e ON e.id = a.event_id
                WHERE a.id = ?""",
            [atom_id],
        ).fetchone()
    elif uri.startswith("orbit://event/"):
        event_id = int(uri.removeprefix("orbit://event/"))
        row = con.execute(
            "SELECT * FROM context_events WHERE id = ?", [event_id]
        ).fetchone()
    else:
        raise ValueError(f"Unknown URI scheme: {uri!r}")
    return dict(row) if row else {}

import sqlite3
import threading
import json
from typing import Any

def record_event(
    con: sqlite3.Connection,
    lock: threading.Lock,
    event_dict: dict[str, Any],
    atoms: list[dict[str, Any]],
) -> tuple[int, list[int]]:
    with lock:
        con.execute("BEGIN IMMEDIATE")
        cur = con.execute(
            """INSERT INTO context_events
               (timestamp, app_bundle_id, app_name, window_title,
                focused_element_role, focused_element_label, visible_text, raw_json)
               VALUES (?, ?, ?, ?, ?, ?, ?, ?)""",
            (
                event_dict.get("timestamp"),
                event_dict.get("app_bundle_id"),
                event_dict.get("app_name"),
                event_dict.get("window_title"),
                event_dict.get("focused_element_role"),
                event_dict.get("focused_element_label"),
                event_dict.get("visible_text"),
                json.dumps(event_dict.get("raw_json")),
            ),
        )
        event_id = cur.lastrowid
        atom_ids = []
        for atom in atoms:
            cur2 = con.execute(
                """INSERT INTO text_atoms (event_id, role, label, text, element_path, element_hash)
                   VALUES (?, ?, ?, ?, ?, ?)""",
                (
                    event_id,
                    atom.get("role", ""),
                    atom.get("label"),
                    atom.get("text", ""),
                    atom.get("element_path", ""),
                    atom.get("element_hash"),
                ),
            )
            atom_ids.append(cur2.lastrowid)
        con.execute("COMMIT")
    return event_id, atom_ids

def record_embeddings(
    con: sqlite3.Connection,
    lock: threading.Lock,
    atom_ids: list[int],
    vectors: list[bytes],
) -> None:
    with lock:
        con.execute("BEGIN IMMEDIATE")
        con.executemany(
            "INSERT INTO vec_atoms(rowid, embedding) VALUES (?, ?)",
            list(zip(atom_ids, vectors)),
        )
        con.execute("COMMIT")

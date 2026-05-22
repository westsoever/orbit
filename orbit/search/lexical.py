from __future__ import annotations
import sqlite3
from orbit.search.types import Hit

def search_lexical(
    con: sqlite3.Connection,
    query: str,
    limit: int = 20,
    app_bundle_id: str | None = None,
) -> list[Hit]:
    rows = con.execute(
        """
        SELECT a.id  AS atom_id,
               a.event_id,
               a.role, a.label,
               e.app_bundle_id, e.app_name, e.window_title, e.timestamp,
               snippet(atoms_fts, 0, '<mark>', '</mark>', '…', 12) AS snippet_html,
               bm25(atoms_fts) AS score
          FROM atoms_fts
          JOIN text_atoms a    ON a.id = atoms_fts.rowid
          JOIN context_events e ON e.id = a.event_id
         WHERE atoms_fts MATCH :q
           AND (:bundle IS NULL OR e.app_bundle_id = :bundle)
         ORDER BY score
         LIMIT :limit
        """,
        {"q": query, "bundle": app_bundle_id, "limit": limit},
    ).fetchall()
    return [Hit.from_row(r) for r in rows]

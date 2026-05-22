from __future__ import annotations
import sqlite3
import sqlite_vec
from sentence_transformers import SentenceTransformer
from orbit.search.types import Hit

_MODEL: SentenceTransformer | None = None

def _get_model() -> SentenceTransformer:
    global _MODEL
    if _MODEL is None:
        try:
            _MODEL = SentenceTransformer("sentence-transformers/all-MiniLM-L6-v2", local_files_only=True)
        except Exception:
            _MODEL = SentenceTransformer("sentence-transformers/all-MiniLM-L6-v2")
    return _MODEL

def search_hybrid(
    con: sqlite3.Connection,
    query: str,
    limit: int = 20,
    app_bundle_id: str | None = None,
    k_each: int = 60,
    rrf_k: int = 60,
) -> list[Hit]:
    """Hybrid search using Reciprocal Rank Fusion of lexical and semantic results.

    sqlite-vec's vec0 virtual table cursors cannot be safely reused inside
    multi-reference CTEs, so we run the two searches as separate queries and
    fuse rankings in Python.
    """
    model = _get_model()
    qvec = sqlite_vec.serialize_float32(
        model.encode([query], normalize_embeddings=True)[0].tolist()
    )

    # --- 1. Semantic (vec) candidates ------------------------------------------
    vec_rows = con.execute(
        """
        SELECT rowid AS atom_id, distance
          FROM vec_atoms
         WHERE embedding MATCH ?
           AND k = ?
         ORDER BY distance
        """,
        [qvec, k_each],
    ).fetchall()

    # --- 2. Lexical (FTS) candidates -------------------------------------------
    fts_rows = con.execute(
        f"""
        SELECT rowid AS atom_id, bm25(atoms_fts) AS score
          FROM atoms_fts
         WHERE atoms_fts MATCH ?
         ORDER BY score
         LIMIT {int(k_each)}
        """,
        [query],
    ).fetchall()

    # --- 3. RRF fusion in Python -----------------------------------------------
    rrf_scores: dict[int, float] = {}
    for rank, row in enumerate(vec_rows, start=1):
        aid = row["atom_id"]
        rrf_scores[aid] = rrf_scores.get(aid, 0.0) + 1.0 / (rrf_k + rank)
    for rank, row in enumerate(fts_rows, start=1):
        aid = row["atom_id"]
        rrf_scores[aid] = rrf_scores.get(aid, 0.0) + 1.0 / (rrf_k + rank)

    if not rrf_scores:
        return []

    ranked_ids = sorted(rrf_scores, key=lambda x: rrf_scores[x], reverse=True)[:limit]

    # --- 4. Fetch full rows for the top-k atom IDs ----------------------------
    placeholders = ",".join("?" * len(ranked_ids))
    rows = con.execute(
        f"""
        SELECT a.id AS atom_id, a.event_id, a.role, a.label,
               e.app_bundle_id, e.app_name, e.window_title, e.timestamp,
               substr(a.text, 1, 240) AS snippet_html
          FROM text_atoms a
          JOIN context_events e ON e.id = a.event_id
         WHERE a.id IN ({placeholders})
           AND (? IS NULL OR e.app_bundle_id = ?)
        """,
        [*ranked_ids, app_bundle_id, app_bundle_id],
    ).fetchall()

    # Map to dict for quick lookup, then order by RRF rank
    row_map = {r["atom_id"]: r for r in rows}
    result = []
    for aid in ranked_ids:
        if aid not in row_map:
            continue
        r = row_map[aid]
        # Build a synthetic row dict so Hit.from_row() works
        hit = Hit(
            atom_id=r["atom_id"],
            event_id=r["event_id"],
            atom_uri=f"orbit://atom/{r['atom_id']}",
            event_uri=f"orbit://event/{r['event_id']}",
            app_bundle_id=r["app_bundle_id"],
            app_name=r["app_name"],
            window_title=r["window_title"],
            timestamp=r["timestamp"],
            role=r["role"],
            label=r["label"],
            snippet_html=r["snippet_html"],
            score=rrf_scores[aid],
        )
        result.append(hit)
    return result

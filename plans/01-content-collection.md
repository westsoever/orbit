# Plan 01 — Lean Content Collection App (v2: + Vector DB)

**Goal (from user):** Build the first lean content-collection application that uses the existing **macapptree** to contextualise and structure information happening on the Mac. Store context so it can later be searched via a function and provide linkable access to any record found.

**Scope discipline (v2):** Lean = capture → store → **lexical search (FTS5) + vector search (sqlite-vec) + hybrid** → linkable URIs. Whisper / Kanban / agents / SQLCipher / cross-platform / layered memory remain out of scope; reserved as **Future Slots** at the end of this plan so they can drop in without renumbering.

**Plan structure:** Each phase is self-contained and can be executed in a fresh chat by an implementer who only reads this plan and the cited docs. Phases run sequentially.

---

## Phase 0 — Documentation Discovery (Consolidated, v2)

This phase has been executed across two discovery rounds. Findings below are evidence-cited and load-bearing for every subsequent phase. Do not re-derive; copy from here.

### 0.A Allowed APIs — macapptree (cited)

| Surface | Form | Source |
|---|---|---|
| Install | `pip install macapptree` | https://github.com/MacPaw/macapptree README |
| Python version | `>=3.8` | `pyproject.toml` `requires-python` |
| Declared deps | `atomacos==3.3.0`, `pyobjc==10.3.1`, `unidecode==1.3.8`, `pytest==7.4.4` | `pyproject.toml` |
| Undeclared runtime dep | `Pillow` (imported in `macapptree/run.py`, `macapptree/main.py` but **not** in `pyproject.toml`) | source |
| CLI invocation | `python -m macapptree.main -a <bundle> --oa <out.json> [--max-depth N] [--include-menubar] [--include-dock] [--all-apps] [--os <screenshots-dir>]` | `macapptree/main.py` argparse block |
| No console script | `pyproject.toml` has no `[project.scripts]`; `macapptree` is **not** on PATH | `pyproject.toml` |
| Library import | `from macapptree import get_tree, get_tree_screenshot, get_app_bundle` | `macapptree/__init__.py` |
| `get_app_bundle(name) -> str` | Resolves app display name → bundle ID via `osascript` | `macapptree/run.py` lines 7–10 |
| `get_tree(app_bundle, max_depth=None) -> list[dict]` | **Shells out** via `subprocess.check_call` to `python -m macapptree.main`; returns `json.load(tmp_file)`. Returns a **list** (top-level windows). | `macapptree/run.py` lines ~23–34 |
| Discovery | `from macapptree.apps import list_visible_app_bundles` | `macapptree/apps.py` ~lines 38–67 |
| Output schema | `{id, name, role, description, role_description, value, absolute_position, position, size, enabled, bbox, visible_bbox, visible, children[]}` per element | `macapptree/uielement.py` `to_dict()` ~lines 169–186 |
| `id` semantics | md5 of `position+size+enabled+role` — **not stable across time** if any of those change | `uielement.py` ~lines 302–309 |

### 0.B Anti-patterns — macapptree (verified absences)

- No `--watch`, no streaming, no async API. Each call is one-shot.
- No `--frontmost` or `--pid`. Targeting is by **bundle ID only** (or `--all-apps`).
- No `--role` / `--text-only` / `--filter` flags. **Caller must filter post-hoc.**
- No `--format` (always JSON), no `--stdout` (`--oa` is `required=True`).
- No `--quiet`. `main.py` prints progress unconditionally.
- No in-process tree extraction in `run.py` — even the library spawns a subprocess.

**Implication:** `get_tree` is too expensive to call per event. Debounce per-bundle and cap `max_depth`.

### 0.C Allowed APIs — SQLite + Python `sqlite3` (cited)

| Item | Doc | Note |
|---|---|---|
| External-content FTS5 + triggers (verbatim) | https://www.sqlite.org/fts5.html §4.4.3 | Three triggers required; absence causes silent drift. |
| FTS5 `'rebuild'` | fts5.html §4.4.4 | `INSERT INTO fts(fts) VALUES('rebuild');` for drift recovery. |
| FTS5 `MATCH`, `bm25()`, `snippet()` | fts5.html §3, §5.1.1, §5.1.3 | `snippet(tbl, colIdx, before, after, ellipsis, maxTokens 1..64)` |
| Tokenizers | fts5.html §4.3 | `unicode61` (default), `porter`, `trigram`, `ascii` |
| `INTEGER PRIMARY KEY` aliases ROWID | https://www.sqlite.org/lang_createtable.html | Declared type **must be exactly `INTEGER`**. |
| WAL mode | https://www.sqlite.org/wal.html | `PRAGMA journal_mode=WAL;` is persistent. |
| Python `sqlite3.connect(...)` | https://docs.python.org/3/library/sqlite3.html | `check_same_thread=True` default; `False` requires caller serialization. |
| `sqlite3.Row` | python.org sqlite3 | `con.row_factory = sqlite3.Row` for named access. |

### 0.D Allowed APIs — sqlite-vec (cited)

| Item | Source | Note |
|---|---|---|
| Latest stable release | `gh api repos/asg017/sqlite-vec/releases/latest` | **v0.1.9** (2026-03-31). `VERSION` file on `main` is `0.1.10-alpha.3`. |
| Stability disclaimer | README L10–L11 | "_`sqlite-vec` is a pre-v1, so expect breaking changes!_" |
| License | repo LICENSE-APACHE + LICENSE-MIT | Dual MIT/Apache-2. |
| Install (Python) | https://alexgarcia.xyz/sqlite-vec/python.html, README L50 | `pip install sqlite-vec` |
| Load pattern (verbatim from `examples/simple-python/demo.py` L1–17) | example file | `db.enable_load_extension(True); sqlite_vec.load(db); db.enable_load_extension(False)` |
| **macOS Python caveat** | python.html | "The default SQLite library that is bundled with Mac operating systems do not include support for SQLite extensions." Symptom: `AttributeError: 'sqlite3.Connection' object has no attribute 'enable_load_extension'`. **Fix: use Homebrew Python (`brew install python`).** |
| Module name | README L66–68 | `vec0`. |
| Vector column types | README L15, source `sqlite-vec.c` | `float[N]`, `int8[N]`, `bit[N]`. |
| Hard limits (source `sqlite-vec.c` L3470–3475) | source | `MAX_DIMENSIONS=8192`; `MAX_VECTOR_COLUMNS=16`; `MAX_PARTITION_COLUMNS=4`; `MAX_AUXILIARY_COLUMNS=16`; `MAX_METADATA_COLUMNS=16`. Zero-length vectors rejected. |
| Distance metric | features/knn.html | Default L2. Cosine via `... float[N] distance_metric=cosine` declaration. Scalar fns: `vec_distance_L2`, `vec_distance_L1`, `vec_distance_cosine`, `vec_distance_hamming`. |
| Insert helper | `bindings/python/extra_init.py` L5–7; python.html | `from sqlite_vec import serialize_float32`; returns `bytes` (struct-packed `f` array). |
| KNN query | `examples/simple-python/demo.py` L45–57; features/knn.html | `WHERE embedding MATCH ? ORDER BY distance LIMIT N` (or `... AND k = N`). Result includes auto column `distance`. |
| Pre-filter inside KNN | features/vec0.html | Metadata columns filterable inside the same query: `=, !=, >, >=, <, <=`; partition keys with `=`. Aux `+` columns are **not** filterable. |
| Updates/deletes | v0.1.9 release notes; source `xUpdate` callback | Supported. v0.1.9 fixed a DELETE bug. |
| **FTS5 coexistence** | `examples/nbc-headlines/2_build.ipynb` | Same DB file holds both `fts_articles` (FTS5) and `vec_articles` (vec0); joined via rowid. **Hybrid retrieval pattern (RRF) demonstrated in `3_search.ipynb`.** |

### 0.E Anti-patterns — sqlite-vec (cited)

- **macOS system Python won't load extensions.** `enable_load_extension` is missing on the bundled `/usr/bin/python3`. Use Homebrew Python.
- **Auxiliary `+` columns are not WHERE-filterable.** Storage-only.
- **Bitvectors don't support cosine/L2/L1.** Hamming only. Float32/int8 don't support hamming.
- **Vectors must be non-empty** (source rejects zero-length at L972, L1007, L1100, etc.).

### 0.F Allowed APIs — Embeddings (sentence-transformers, chosen)

The orchestrator selects **sentence-transformers** with **`all-MiniLM-L6-v2`** for the lean POC. Rationale (cited, not benchmarked):

- Library Apache-2.0 (https://github.com/UKPLab/sentence-transformers/blob/master/LICENSE); model Apache-2.0 (https://huggingface.co/sentence-transformers/all-MiniLM-L6-v2).
- 384-dim output, 22.7M params, max 256 word-pieces (model card).
- Auto-selects MPS on Apple Silicon (https://sbert.net/docs/sentence_transformer/usage/efficiency.html — order: `cuda > mps > cpu`).
- Single batched API: `model.encode([...])` (https://www.sbert.net/).
- No daemon, no compile flags, no GPL.

Alternatives considered and rejected for the lean POC:
- **mlx-embeddings** (Apple-Silicon-native MLX): runtime is **GPL-3.0** (https://github.com/Blaizzy/mlx-embeddings) — copyleft is unwanted at this stage.
- **llama-cpp-python**: requires `CMAKE_ARGS="-DGGML_METAL=on" pip install llama-cpp-python` and arm64 Python; user supplies `.gguf`. Setup overhead.
- **Ollama**: requires `ollama serve` daemon. Extra moving part.

| Item | Source | Note |
|---|---|---|
| Install | sbert.net/docs/installation.html | `pip install -U sentence-transformers` (Python 3.10+, PyTorch 1.11.0+). |
| Embed call | https://www.sbert.net/ | `SentenceTransformer("sentence-transformers/all-MiniLM-L6-v2").encode([...])` |
| Default device | sbert.net efficiency page | Auto MPS on Apple Silicon. |

### 0.G Anti-patterns — Embeddings (cited)

- Don't call `encode()` per-string in tight loops; pass a list to enable internal batching (sbert.net + model card).
- Don't ship cloud-only providers (OpenAI/Cohere/Voyage/Anthropic). Violates local-first.
- Don't assume PyTorch picks MPS in every context — verify with `model.device` at startup.
- Don't truncate the embedding tensor manually; the model already handles its own 256-token cap.

### 0.H Confidence + gaps (v2 deltas)

- sqlite-vec install/load/syntax/limits: **HIGH** (verified by source + canonical example).
- sqlite-vec UPDATE/DELETE prose: **MEDIUM** (inferred from release notes + `xUpdate`; no doc page on full semantics yet).
- Embedding latency / memory footprint: **NOT MEASURED** (docs don't publish numbers; benchmark in Phase 6 acceptance run).
- macOS minimum, Accessibility permission flow: **LOW** (still undocumented upstream; handle by checklist in Phase 1).

---

## Phase 1 — Project Scaffold + Sanity Checks

**What to implement.** One Python package, all deps installed, both macapptree and sqlite-vec proven loadable on this Mac.

Tasks:

1. **Use Homebrew Python.** Confirm:
   ```bash
   which python3   # expect /opt/homebrew/bin/python3 (Apple Silicon) or /usr/local/bin/python3 (Intel Homebrew)
   python3 -c "import sqlite3; sqlite3.connect(':memory:').enable_load_extension(True)"
   ```
   If the second command raises `AttributeError`, the interpreter does not support loadable extensions. Fix by `brew install python` and re-run inside that interpreter (cited rationale: https://alexgarcia.xyz/sqlite-vec/python.html).

2. Directory layout:
   ```
   orbit/
     pyproject.toml
     orbit/
       __init__.py
       capture/
         __init__.py
       storage/
         __init__.py
       embed/                # NEW (v2)
         __init__.py
       search/
         __init__.py
     scripts/
       sanity_macapptree.py
       sanity_sqlite_vec.py  # NEW (v2)
       sanity_embed.py       # NEW (v2)
     plans/
   ```

3. `pyproject.toml` deps (copy exactly):
   ```toml
   [project]
   name = "orbit"
   version = "0.0.1"
   requires-python = ">=3.10"
   dependencies = [
     "macapptree==0.0.2",
     "pyobjc-framework-Cocoa>=10.3.1",
     "Pillow",
     "sqlite-vec==0.1.9",
     "sentence-transformers>=3.0",
   ]
   ```
   Pillow is added per Phase 0.A undeclared-import finding. `sqlite-vec` pinned at the v0.1.9 stable tag — pre-v1 disclaimer is acknowledged; revisit on next release.

4. Install:
   ```bash
   python -m venv .venv && source .venv/bin/activate
   pip install -e .
   ```

5. **macOS Accessibility permission.** Grant the host process Accessibility:
   System Settings → Privacy & Security → Accessibility → toggle on the interpreter (or its hosting Terminal). Record the exact path used in `orbit/capture/PERMISSIONS.md` after verifying — this remains undocumented upstream.

6. `scripts/sanity_macapptree.py` (verbatim from v1):
   ```python
   from macapptree import get_app_bundle, get_tree
   bundle = get_app_bundle("Finder")
   tree = get_tree(bundle, max_depth=4)
   print(f"top-level elements: {len(tree)}")
   for el in tree[:1]:
       print(el.get("role"), el.get("name"), "children:", len(el.get("children", [])))
   ```

7. `scripts/sanity_sqlite_vec.py` (copy verbatim from `examples/simple-python/demo.py` L1–17 + a vec0 round-trip):
   ```python
   import sqlite3
   import sqlite_vec
   from sqlite_vec import serialize_float32

   db = sqlite3.connect(":memory:")
   db.enable_load_extension(True)
   sqlite_vec.load(db)
   db.enable_load_extension(False)

   db.execute("CREATE VIRTUAL TABLE v USING vec0(embedding float[4])")
   with db:
       db.execute(
           "INSERT INTO v(rowid, embedding) VALUES (?, ?)",
           [1, serialize_float32([0.1, 0.2, 0.3, 0.4])],
       )
   row = db.execute(
       "SELECT rowid, distance FROM v WHERE embedding MATCH ? ORDER BY distance LIMIT 1",
       [serialize_float32([0.1, 0.2, 0.3, 0.4])],
   ).fetchone()
   print("hit:", row)  # expect (1, 0.0)
   ```

8. `scripts/sanity_embed.py` (verbatim shape from https://www.sbert.net/):
   ```python
   from sentence_transformers import SentenceTransformer
   m = SentenceTransformer("sentence-transformers/all-MiniLM-L6-v2")
   v = m.encode(["The weather is lovely today."])
   print("device:", m.device, "dim:", len(v[0]))   # expect dim: 384
   ```

**Documentation references.**
- macapptree README (Example block).
- sqlite-vec Python guide: https://alexgarcia.xyz/sqlite-vec/python.html.
- sqlite-vec demo: https://raw.githubusercontent.com/asg017/sqlite-vec/main/examples/simple-python/demo.py (L1–17, L37–57).
- sentence-transformers landing: https://www.sbert.net/.

**Verification checklist.**
- [ ] `python3 -c "import sqlite3; sqlite3.connect(':memory:').enable_load_extension(True)"` succeeds (no AttributeError).
- [ ] `pip show macapptree` reports `Version: 0.0.2`; `pip show sqlite-vec` reports `Version: 0.1.9`.
- [ ] `python scripts/sanity_macapptree.py` exits 0 and prints at least one `AXWindow`.
- [ ] `python scripts/sanity_sqlite_vec.py` prints `hit: (1, 0.0)`.
- [ ] `python scripts/sanity_embed.py` prints `dim: 384`.
- [ ] `PERMISSIONS.md` records the exact System Settings path used.

**Anti-pattern guards.**
- Do not invoke a `macapptree` console script. Use `python -m macapptree.main` if calling the CLI.
- Do not run under macOS system Python (`/usr/bin/python3`) — extension loading is disabled.
- Do not skip `enable_load_extension(True)` before `sqlite_vec.load(db)` — it raises a clear error but easy to forget.
- Do not use cloud embedding APIs.

---

## Phase 2 — Event-Driven Activation Listener (NSWorkspace)

**Unchanged from v1.** Summary:

- `orbit/capture/listener.py` registers `NSWorkspaceDidActivateApplicationNotification`.
- Per-bundle debounce, `min_interval_s=1.5`.
- Run loop entry: `python -m orbit.capture.listener` prints one JSON line per accepted focus event.
- Exclusion seeds from `macapptree/apps.py` ~lines 38–67 plus user additions in `orbit/capture/exclusions.py`.

(Verbatim verification + anti-pattern guards from v1; not duplicated here.)

---

## Phase 3 — SQLite Storage Layer (Schema + Writer + Vector Index)

**What to implement.** A storage module that owns the DB connection, applies migrations (FTS5 + vec0 + supporting tables), and exposes write APIs.

Tasks:

1. `orbit/storage/db.py` — connection helper (extends v1):
   ```python
   import sqlite3, threading
   import sqlite_vec
   _LOCK = threading.Lock()

   def open_db(path: str) -> sqlite3.Connection:
       con = sqlite3.connect(path, check_same_thread=False, isolation_level=None)
       con.row_factory = sqlite3.Row
       con.enable_load_extension(True)
       sqlite_vec.load(con)
       con.enable_load_extension(False)
       con.execute("PRAGMA journal_mode=WAL;")
       con.execute("PRAGMA synchronous=NORMAL;")
       con.execute("PRAGMA foreign_keys=ON;")
       return con
   ```
   Cited load order: https://alexgarcia.xyz/sqlite-vec/python.html.

2. `orbit/storage/schema.sql` — extends v1 with the vec0 table. The `context_events` columns remain verbatim from `orbit-context.md`. `text_atoms` and `atoms_fts` are unchanged from v1. **New: `vec_atoms` virtual table.**
   ```sql
   -- v1: spec verbatim.
   CREATE TABLE IF NOT EXISTS context_events (
     id INTEGER PRIMARY KEY AUTOINCREMENT,
     timestamp TEXT NOT NULL,
     app_bundle_id TEXT,
     app_name TEXT,
     window_title TEXT,
     focused_element_role TEXT,
     focused_element_label TEXT,
     visible_text TEXT,
     raw_json TEXT
   );
   CREATE INDEX IF NOT EXISTS idx_events_bundle_ts
     ON context_events(app_bundle_id, timestamp);

   -- v1: per-atom rows for fine-grained linking (deviation from spec, flagged).
   CREATE TABLE IF NOT EXISTS text_atoms (
     id INTEGER PRIMARY KEY AUTOINCREMENT,
     event_id INTEGER NOT NULL REFERENCES context_events(id) ON DELETE CASCADE,
     role TEXT NOT NULL,
     label TEXT,
     text TEXT NOT NULL,
     element_path TEXT NOT NULL,
     element_hash TEXT
   );
   CREATE INDEX IF NOT EXISTS idx_atoms_event ON text_atoms(event_id);

   -- v1: external-content FTS5 (cited verbatim, fts5.html §4.4.3).
   CREATE VIRTUAL TABLE IF NOT EXISTS atoms_fts USING fts5(
     text,
     label UNINDEXED,
     role UNINDEXED,
     content='text_atoms',
     content_rowid='id',
     tokenize='unicode61 remove_diacritics 2'
   );
   CREATE TRIGGER IF NOT EXISTS text_atoms_ai AFTER INSERT ON text_atoms BEGIN
     INSERT INTO atoms_fts(rowid, text, label, role) VALUES (new.id, new.text, new.label, new.role);
   END;
   CREATE TRIGGER IF NOT EXISTS text_atoms_ad AFTER DELETE ON text_atoms BEGIN
     INSERT INTO atoms_fts(atoms_fts, rowid, text, label, role) VALUES('delete', old.id, old.text, old.label, old.role);
   END;
   CREATE TRIGGER IF NOT EXISTS text_atoms_au AFTER UPDATE ON text_atoms BEGIN
     INSERT INTO atoms_fts(atoms_fts, rowid, text, label, role) VALUES('delete', old.id, old.text, old.label, old.role);
     INSERT INTO atoms_fts(rowid, text, label, role) VALUES (new.id, new.text, new.label, new.role);
   END;

   -- v2: vector index over atoms. Cosine distance per features/knn.html.
   -- rowid is set explicitly on insert to match text_atoms.id (NOT a foreign key — vec0 doesn't support FKs).
   CREATE VIRTUAL TABLE IF NOT EXISTS vec_atoms USING vec0(
     embedding float[384] distance_metric=cosine
   );
   ```
   **Linkage contract:** for each `text_atoms.id = N`, there is at most one `vec_atoms` row with `rowid = N`. Maintained by application code (no triggers — vec0 doesn't accept SQL triggers as a virtual table target on the same INSERT statement, and writing application-side keeps the embedding step idempotent and restartable).

   Dim 384 corresponds to `all-MiniLM-L6-v2` (Phase 0.F). If the embedding model changes, the table must be dropped and rebuilt.

3. `orbit/storage/writer.py` — extends v1:
   - `record_event(con, lock, event_dict, atoms: list[dict]) -> tuple[int, list[int]]` returns `(event_id, atom_ids)`. Use `BEGIN IMMEDIATE` … `COMMIT`. atom_ids are needed by the embedding worker (Phase 4.B).
   - `record_embeddings(con, lock, atom_ids: list[int], vectors: list[bytes]) -> None`:
     ```python
     with lock:
         con.execute("BEGIN IMMEDIATE")
         con.executemany(
             "INSERT INTO vec_atoms(rowid, embedding) VALUES (?, ?)",
             list(zip(atom_ids, vectors)),
         )
         con.execute("COMMIT")
     ```
   `vectors` are `bytes` produced by `sqlite_vec.serialize_float32(vector)`.

4. `orbit/storage/links.py` — URI helpers (extended):
   ```python
   def event_uri(event_id: int) -> str:  return f"orbit://event/{event_id}"
   def atom_uri(atom_id: int) -> str:    return f"orbit://atom/{atom_id}"
   ```
   `INTEGER PRIMARY KEY` is the canonical link target. vec_atoms.rowid is kept identical to text_atoms.id, so a single integer addresses both lexical and semantic hits.

**Documentation references.**
- FTS5 external-content + triggers: https://www.sqlite.org/fts5.html §4.4.3.
- WAL: https://www.sqlite.org/wal.html.
- vec0 syntax + cosine: https://alexgarcia.xyz/sqlite-vec/features/vec0.html and features/knn.html.
- Spec schema source: `orbit-context.md` "macapptree Clone — Immediate Build Target".

**Verification checklist.**
- [ ] `sqlite3 orbit.db ".schema"` lists `context_events`, `text_atoms`, `atoms_fts`, `vec_atoms`, and the three FTS triggers.
- [ ] `PRAGMA journal_mode;` returns `wal`.
- [ ] After inserting one atom and one embedding, `SELECT count(*) FROM vec_atoms;` returns 1 and `SELECT rowid, distance FROM vec_atoms WHERE embedding MATCH ? ORDER BY distance LIMIT 1` returns the matching rowid with distance 0.0 when the query vector equals the stored vector.
- [ ] Concurrent writes from two threads complete without `database is locked`.

**Anti-pattern guards.**
- Do not omit any of the three FTS triggers (silent drift).
- Do not declare `vec_atoms.embedding` with a dimension other than 384 unless the embedding model changes; mismatch raises at insert time.
- Do not put a foreign key on `vec_atoms` — virtual tables don't support FKs; integrity is application-level.
- Do not enable extension loading on the connection without disabling it after `sqlite_vec.load` (least-privilege; matches the cited example).

---

## Phase 4 — Capture Pipeline (Listener → macapptree → Atoms → DB → Embeddings)

Phase 4 is two cooperating workers behind one process.

### 4.A Capture worker (verbatim from v1)

- Pulls focus events from a `queue.Queue`.
- Calls `macapptree.get_tree(bundle_id, max_depth=12)`.
- Flattens via `orbit/capture/extract.py:flatten_text_atoms(tree)` keeping roles in `{"AXTextField", "AXTextArea", "AXStaticText", "AXDocument", "AXWebArea"}` with non-empty text.
- Calls `record_event(...)`, gets back `(event_id, atom_ids)`.
- Pushes `(event_id, atom_ids, [atom_text_strings])` onto an **embedding queue** for worker 4.B.
- Logs and continues on any failure.

### 4.B Embedding worker (NEW in v2)

`orbit/embed/worker.py`:

1. Loads the embedding model **once** at startup:
   ```python
   from sentence_transformers import SentenceTransformer
   _MODEL = SentenceTransformer("sentence-transformers/all-MiniLM-L6-v2")
   ```
2. Drains the embedding queue with a small **batch coalescer** — wait up to `flush_ms=200` or until `batch_max=32` items are queued, whichever comes first. This honours the cited anti-pattern "Don't call encode() per-string in tight loops" (Phase 0.G).
3. For each batch:
   ```python
   import sqlite_vec
   texts = [t for (_eid, _aid, t) in batch]
   vectors = _MODEL.encode(texts, normalize_embeddings=True)  # numpy array
   payload = [sqlite_vec.serialize_float32(v.tolist()) for v in vectors]
   atom_ids = [aid for (_eid, aid, _t) in batch]
   record_embeddings(con, lock, atom_ids, payload)
   ```
   `normalize_embeddings=True` keeps cosine distance well-conditioned (`distance_metric=cosine` in Phase 3 schema).
4. Logs per-batch counts and continues on failure.

### 4.C Daemon entry point

`orbit/capture/daemon.py`:
- Wires `AppFocusListener` → capture queue → capture worker → embedding queue → embedding worker.
- One thread per worker. Run loop on the main thread (NSWorkspace requirement).
- Run via `python -m orbit.capture.daemon --db ./orbit.db [--no-embed]`. The `--no-embed` flag skips Phase 4.B for low-resource sessions.

**Documentation references.**
- macapptree subprocess cost: `macapptree/run.py` ~lines 23–34 (Phase 0.A).
- `encode([...])` batched API: https://www.sbert.net/ + model card.
- `serialize_float32`: `bindings/python/extra_init.py` L5–7; https://alexgarcia.xyz/sqlite-vec/python.html.
- vec0 batched insert example: `examples/simple-python/demo.py` L37–43.

**Verification checklist.**
- [ ] Run the daemon, switch focus across three apps for 5 minutes. Confirm `text_atoms` and `vec_atoms` row counts are equal at end of session (within last batch flush).
- [ ] `SELECT rowid FROM text_atoms WHERE id NOT IN (SELECT rowid FROM vec_atoms);` returns at most 32 rows during steady-state (the in-flight batch).
- [ ] `--no-embed` mode populates `text_atoms` only; `vec_atoms` stays empty.
- [ ] Force `get_tree` to fail and confirm the daemon stays up.

**Anti-pattern guards.**
- Do not call `encode()` per atom; always batch (Phase 0.G).
- Do not load the SentenceTransformer per call — once at startup.
- Do not block the run-loop thread on embedding work; the embedding worker is a separate thread.
- Do not write embeddings before the parent atom row is committed; sequencing is `record_event` → enqueue → `record_embeddings`.

---

## Phase 5 — Search: Lexical + Semantic + Hybrid

**What to implement.** Three Python functions returning ranked, linkable hits.

### 5.A Lexical search (v1, retained)

`orbit/search/lexical.py:search_lexical(con, query, limit=20, app_bundle_id=None) -> list[Hit]`

```sql
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
 LIMIT :limit;
```

### 5.B Semantic search (NEW in v2)

`orbit/search/semantic.py:search_semantic(con, query, limit=20, app_bundle_id=None) -> list[Hit]`

```python
import sqlite_vec
from sentence_transformers import SentenceTransformer
_MODEL = SentenceTransformer("sentence-transformers/all-MiniLM-L6-v2")

def search_semantic(con, query, limit=20, app_bundle_id=None):
    qvec = sqlite_vec.serialize_float32(
        _MODEL.encode([query], normalize_embeddings=True)[0].tolist()
    )
    rows = con.execute(
        """
        WITH knn AS (
          SELECT rowid, distance
            FROM vec_atoms
           WHERE embedding MATCH ?
           ORDER BY distance
           LIMIT ?
        )
        SELECT a.id AS atom_id, a.event_id, a.role, a.label,
               e.app_bundle_id, e.app_name, e.window_title, e.timestamp,
               substr(a.text, 1, 240) AS snippet_html,
               knn.distance AS score
          FROM knn
          JOIN text_atoms a    ON a.id = knn.rowid
          JOIN context_events e ON e.id = a.event_id
         WHERE (:bundle IS NULL OR e.app_bundle_id = :bundle)
         ORDER BY score
        """,
        [qvec, limit * 4, app_bundle_id],   # over-fetch; bundle filter happens post-KNN
    ).fetchall()
    return [Hit.from_row(r) for r in rows[:limit]]
```

Why over-fetch: the cited KNN syntax filters metadata columns inside the same query (features/vec0.html), but `app_bundle_id` lives on the sibling `context_events` table, not on `vec_atoms`. The cited pattern (`examples/python-recipes/openai-sample.py` L74–87) uses a CTE + JOIN, which means filtering happens **after** KNN returns its top-K. Over-fetching `limit * 4` and trimming after the JOIN is the documented workaround.

### 5.C Hybrid search (NEW in v2)

`orbit/search/hybrid.py:search_hybrid(con, query, limit=20, app_bundle_id=None, k_each=60, rrf_k=60) -> list[Hit]`

Reciprocal Rank Fusion, copied from `examples/nbc-headlines/3_search.ipynb`. The pattern:

```sql
WITH vec_matches AS (
  SELECT rowid AS atom_id,
         row_number() OVER (ORDER BY distance) AS rank
    FROM vec_atoms
   WHERE embedding MATCH :qvec
   LIMIT :k_each
),
fts_matches AS (
  SELECT rowid AS atom_id,
         row_number() OVER (ORDER BY bm25(atoms_fts)) AS rank
    FROM atoms_fts
   WHERE atoms_fts MATCH :qstr
   LIMIT :k_each
),
fused AS (
  SELECT atom_id,
         SUM(1.0 / (:rrf_k + rank)) AS score
    FROM (
      SELECT atom_id, rank FROM vec_matches
      UNION ALL
      SELECT atom_id, rank FROM fts_matches
    )
    GROUP BY atom_id
)
SELECT a.id AS atom_id, a.event_id, a.role, a.label,
       e.app_bundle_id, e.app_name, e.window_title, e.timestamp,
       snippet(atoms_fts, 0, '<mark>', '</mark>', '…', 12) AS snippet_html,
       fused.score AS score
  FROM fused
  JOIN text_atoms a    ON a.id = fused.atom_id
  JOIN context_events e ON e.id = a.event_id
  LEFT JOIN atoms_fts ON atoms_fts.rowid = a.id AND atoms_fts MATCH :qstr
 WHERE (:bundle IS NULL OR e.app_bundle_id = :bundle)
 ORDER BY score DESC
 LIMIT :limit;
```

Note: in this hybrid query, larger `score` is **better** (RRF sum); in lexical/semantic searches, smaller `score` is better. Document this on `Hit.score` accordingly.

### 5.D `Hit` and resolver

`orbit/search/types.py`:
```python
from dataclasses import dataclass

@dataclass
class Hit:
    atom_id: int
    event_id: int
    atom_uri: str           # orbit://atom/<id>
    event_uri: str          # orbit://event/<id>
    app_bundle_id: str
    app_name: str
    window_title: str | None
    timestamp: str
    role: str
    label: str | None
    snippet_html: str
    score: float
    # score is "lower is better" for lexical/semantic, "higher is better" for hybrid (RRF).
    # Callers should not mix scores across modes.
```

`orbit/search/links.py:resolve(con, uri) -> dict` parses `orbit://event/<id>` and `orbit://atom/<id>` and returns the full record (atom + parent event row, with `raw_json`).

### 5.E CLI

`python -m orbit.search [--mode lexical|semantic|hybrid] "<query>"` prints `score | timestamp | app | snippet | atom_uri`. Default mode: `hybrid`.

**Documentation references.**
- FTS5 `MATCH`/`bm25`/`snippet`: https://www.sqlite.org/fts5.html §3, §5.1.1, §5.1.3.
- vec0 KNN + sibling JOIN: https://alexgarcia.xyz/sqlite-vec/features/knn.html, `examples/python-recipes/openai-sample.py` L74–87.
- RRF hybrid pattern: `examples/nbc-headlines/3_search.ipynb`.

**Verification checklist.**
- [ ] Each of the three modes returns hits with valid `atom_uri` and `event_uri`.
- [ ] `resolve()` round-trips a URI back to the originating record (including `raw_json`).
- [ ] Bundle filter reduces results in all three modes.
- [ ] When the query string exactly matches a stored atom, both `search_lexical` and `search_semantic` return that atom in their top-3.
- [ ] `search_hybrid` returns at least the union of top-3 atoms from each mode (sanity bound, not a strict requirement).

**Anti-pattern guards.**
- Do not concatenate user input into MATCH strings; always parameterize.
- Do not over-fetch by more than `~10x` for the bundle-filter workaround; if more is needed, store `app_bundle_id` as a vec0 metadata column and filter inline (deferred — would change the schema).
- Do not interpret `score` direction without checking the mode.
- Do not run `'rebuild'` per query; only on schema migrations.

---

## Phase 6 — Verification + Acceptance (v2)

**What to implement.** Repeatable verification scripts and a manual acceptance walkthrough.

Tasks:

1. `scripts/verify.sh`:
   ```bash
   set -e
   python scripts/sanity_macapptree.py
   python scripts/sanity_sqlite_vec.py
   python scripts/sanity_embed.py
   python -c "import sqlite3, sys; \
     c = sqlite3.connect(sys.argv[1]); \
     [print(r[0]) for r in c.execute('SELECT name FROM sqlite_master WHERE type IN (\"table\",\"trigger\") ORDER BY name')]" \
     orbit.db
   ```

2. `scripts/grep_antipatterns.sh`:
   ```bash
   set -e
   ! grep -RIn --include='*.py' -- "--frontmost\|--watch\|--text-only" orbit/
   ! grep -RIn --include='*.py' -- "INT PRIMARY KEY\|BIGINT PRIMARY KEY" orbit/ scripts/
   ! grep -RIn --include='*.py' -- "subprocess.*macapptree" orbit/
   ! grep -RIn --include='*.py' -- "openai\|anthropic\|cohere\|voyageai" orbit/   # local-first guard
   ! grep -RIn --include='*.py' -- "encode(\".*\")" orbit/                          # no per-string encode
   echo OK
   ```

3. Manual acceptance walkthrough (`plans/01-acceptance.md` after running):
   - Run `python -m orbit.capture.daemon --db ./orbit.db` for ≥30 minutes across ≥3 apps.
   - `SELECT count(*) FROM text_atoms;` and `SELECT count(*) FROM vec_atoms;` are within 32 of each other.
   - `python -m orbit.search "<phrase>"` returns hits in all three modes.
   - Resolve a returned `orbit://atom/<id>` via `orbit.search.links.resolve` and confirm round-trip.
   - Capture peak RSS and CPU% from Activity Monitor; record in acceptance doc (no fixed budget — establish baseline).

**Acceptance bar (binary).**
The plan is done when, in a single sitting, the user can:
1. Capture ≥30 minutes of context without the daemon crashing.
2. Run `search_lexical`, `search_semantic`, and `search_hybrid` and get ranked, snippeted hits in each.
3. Resolve any returned `orbit://atom/<id>` or `orbit://event/<id>` back to the originating record.

That maps to the user's request: *"saved in a way that I can later-on search it via function and have link-able access to whatever is found."* — now with both keyword and semantic recall.

---

## Future Slots (reserved — do NOT implement in this plan)

These exist so a future planner can drop a phase in without renumbering the executed plan. Each slot lists the trigger condition that should reopen it.

| Slot | Scope | Reopen when |
|---|---|---|
| **Phase 7 — SQLCipher** | Encrypt the SQLite DB at rest with OS-keychain-managed key. Spec requires this for production. | Before any non-throwaway data is collected. |
| **Phase 8 — Whisper audio capture** | Local Whisper transcription of meeting/system audio; new `audio_atoms` sibling table; same FTS5 + vec0 indexing pipeline. | When the user wants meeting transcripts in search. |
| **Phase 9 — File system events** | FSEvents indexing of file create/modify/delete. New `fs_events` sibling table. | When file operations need to surface in search. |
| **Phase 10 — Layered memory** | Working / Episodic / Semantic / Archived summaries (per `orbit-context.md`). New `summaries` table built by a periodic job. | When the raw atom store outgrows usable context-window-fit retrieval. |
| **Phase 11 — Kanban UI** | localhost web app over the search/links API; the same `Hit` shape feeds the UI. | When a non-CLI surface is needed. |
| **Phase 12 — Agent loop + MCP** | Orchestrator + ReAct loop; MCP servers; dual approval gates; audit log. | After Phase 11 (Kanban as approval surface). |
| **Phase 13 — Cross-platform abstraction** | Windows / Linux capture backends behind the same writer/search API. | Phase 2+ per spec. |
| **Phase 14 — Embedding model upgrade** | Swap `all-MiniLM-L6-v2` → larger model (e.g. `bge-m3`, `gte-Qwen2-1.5B-instruct`); rebuild `vec_atoms` with new dim. | When recall on the lean POC plateaus. |

Each slot inherits the same orchestrator contract: do its own Phase 0 discovery before designing.

---

## Appendix — Quick command reference for implementers

```bash
# install
python -m venv .venv && source .venv/bin/activate
pip install -e .

# sanity (run all three)
python scripts/sanity_macapptree.py
python scripts/sanity_sqlite_vec.py
python scripts/sanity_embed.py

# run daemon
python -m orbit.capture.daemon --db ./orbit.db
python -m orbit.capture.daemon --db ./orbit.db --no-embed   # capture only

# search
python -m orbit.search --mode lexical  "phrase"
python -m orbit.search --mode semantic "phrase"
python -m orbit.search --mode hybrid   "phrase"   # default

# verify
./scripts/verify.sh
./scripts/grep_antipatterns.sh
```

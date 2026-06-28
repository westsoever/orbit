# Plan: Fix `orbit start`

**Goal:** `orbit start` runs successfully on macOS with the Python interpreter the user actually has installed (including python.org builds that lack loadable SQLite extensions).

**Status:** Phases 1–3 implemented and verified on Homebrew Python 3.13 venv (2026-06-28).

**Note:** Use `python3.13` not `python3.14` for venv creation — Homebrew 3.14 had broken `ensurepip` on test machine. Always verify with `python` from activated venv, not system `python3`.

**References:**
- Failure site: `orbit/storage/db.py:31-41`
- sqlite-vec macOS caveat: https://alexgarcia.xyz/sqlite-vec/python.html
- Internal doc: `plans/01-content-collection.md:64-78, 126-131`
- Extension-free opener (already exists): `orbit/storage/db.py:20-28`

---

## Phase 0: Documentation Discovery (complete)

### Allowed APIs

| API | Source | Notes |
|-----|--------|-------|
| `sqlite3.connect(..., check_same_thread=False, isolation_level=None)` | stdlib | Used by both `open_db` and `open_db_plain` |
| `con.enable_load_extension(True/False)` | stdlib | **Only when Python built with loadable extensions** |
| `sqlite_vec.load(con)` | `sqlite-vec==0.1.9` | Requires `load_extension`; calls `conn.load_extension(loadable_path())` |
| `open_db_plain(path)` | `orbit/storage/db.py:20-28` | Skips vec0 schema; works on any Python |
| `AppHelper.runConsoleEventLoop(installInterrupt=True)` | PyObjCTools | Main-thread event loop in daemon |

### Anti-patterns to avoid

- Do **not** assume `enable_load_extension` exists on all macOS Pythons.
- Do **not** call `open_db()` when `--no-embed` is set (capture-only should skip vec entirely).
- Do **not** add `pysqlite3-binary` — no wheel for Python 3.13 on macOS (verified).
- Do **not** silently skip embed without logging — user must know semantic search is degraded.

---

## Phase 1: SQLite extension detection + split DB open paths

**What to implement:** Copy the existing `open_db_plain` pattern; add a capability probe; route daemon startup based on embed flag + probe result.

### Tasks

1. **Add `sqlite_supports_extensions()` to `orbit/storage/db.py`**
   - Probe: `hasattr(sqlite3.connect(":memory:"), "enable_load_extension")`
   - Copy pattern from `plans/01-content-collection.md:126-131`

2. **Add `RuntimeError` with fix instructions in `open_db()`**
   - When extensions unavailable, raise:
     ```
     This Python build cannot load SQLite extensions (required for sqlite-vec embeddings).
     Fix: recreate your venv with Homebrew Python:
       brew install python
       /opt/homebrew/bin/python3 -m venv .venv && source .venv/bin/activate && pip install -e .
     Or run capture-only: orbit start --no-embed
     ```
   - Cite: https://alexgarcia.xyz/sqlite-vec/python.html

3. **Update `orbit/capture/daemon.py` DB selection**
   - Copy routing logic:
     ```python
     if args.no_embed or not sqlite_supports_extensions():
         if not args.no_embed:
             logger.warning("SQLite extensions unavailable; running capture-only (no embeddings)")
         con, lock = open_db_plain(args.db)
         embed_queue = None
     else:
         con, lock = open_db(args.db)
         embed_queue = queue.Queue()
     ```
   - Reference: `daemon.py:31-38`, `db.py:20-28`

### Verification checklist

```bash
# python.org Python — capture-only must start (no crash at open_db)
python3 -c "from orbit.storage.db import sqlite_supports_extensions, open_db_plain; print(sqlite_supports_extensions()); open_db_plain('/tmp/t.db')"

# Homebrew Python — full path with vec
/opt/homebrew/bin/python3.13 -c "from orbit.storage.db import open_db; open_db('/tmp/t2.db')"

# CLI smoke (expect log lines, not traceback):
orbit start --no-embed   # must reach "Orbit daemon running"
python scripts/sanity_sqlite_vec.py  # Homebrew only; expect hit: (1, 0.0)
```

### Anti-pattern guards

- Do not call `sqlite_vec.load()` from `open_db_plain`.
- Do not import `sqlite_vec` at module level in daemon when using plain DB.

---

## Phase 2: CLI preflight + README

**What to implement:** Surface the Python requirement before the user hits a traceback; document install path.

### Tasks

1. **Optional preflight in `orbit/cli.py`** (before `daemon_main()`)
   - If not `--no-embed` and not `sqlite_supports_extensions()`:
     - Print warning to stderr with Homebrew fix + `--no-embed` fallback
     - Continue (daemon will auto-degrade per Phase 1)
   - Reference: `cli.py:30-40`

2. **Update `README.md` Install section**
   - Copy Homebrew Python requirement from `plans/01-content-collection.md:126-131`
   - Add verify command: `python3 -c "import sqlite3; sqlite3.connect(':memory:').enable_load_extension(True)"`
   - Note: `orbit start --no-embed` works without extension support (capture + FTS only)

3. **Update `scripts/verify.sh`**
   - Skip `sanity_sqlite_vec.py` with message when extensions unavailable (exit 0 with skip, not fail)
   - Reference: `scripts/verify.sh:1-28`

### Verification checklist

```bash
grep -n "Homebrew" README.md          # documents Python requirement
grep -n "sqlite_supports_extensions" orbit/storage/db.py orbit/capture/daemon.py
./scripts/verify.sh                   # passes on python.org Python (vec sanity skipped)
```

---

## Phase 3: End-to-end verification

**What to verify:** Full startup path on both interpreter types.

### Checklist

| Check | python.org Python | Homebrew Python |
|-------|-------------------|-----------------|
| `orbit start --no-embed` reaches event loop | ✓ | ✓ |
| `orbit start` (default) reaches event loop | ✓ (capture-only fallback) | ✓ (with embed worker) |
| DB created at `~/.orbit/orbit.db` | ✓ | ✓ |
| `vec_atoms` table exists | ✗ (expected) | ✓ |
| App focus → `Captured event` log | ✓ (needs Accessibility perm) | ✓ |

### Anti-pattern grep

```bash
bash scripts/grep_antipatterns.sh     # no macapptree subprocess in capture path
grep -r "enable_load_extension" orbit/  # only in db.py and sanity script
```

### Manual acceptance

1. Grant Accessibility to Terminal (see `orbit/capture/PERMISSIONS.md`)
2. Run `orbit start --no-embed`, switch apps, confirm `Captured event N` in logs
3. On Homebrew Python: run `orbit start`, confirm embed worker loads model on first capture

---

## Session handoff notes

- **Immediate blocker fixed:** `AttributeError` on `enable_load_extension` at startup.
- **Full embed path** still requires Homebrew Python (or any build with loadable SQLite extensions). No pure-Python workaround exists for Python 3.13.
- **DB path inconsistency** (cli default `~/.orbit/orbit.db` vs daemon default `./orbit.db`) is pre-existing; out of scope unless user asks.

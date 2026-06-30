"""SQLite connection helpers for the Orbit context store.

Two open paths:

- ``open_db`` — loads the sqlite-vec extension and creates the ``vec_atoms`` virtual
  table. Requires a Python build with loadable SQLite extensions (Homebrew Python on
  macOS; not the python.org installer). See https://alexgarcia.xyz/sqlite-vec/python.html
- ``open_db_plain`` — schema without vec0; used for capture-only mode (``--no-embed``)
  or when extensions are unavailable.

Use ``sqlite_supports_extensions()`` to probe capability before calling ``open_db``.
"""
import os
import sqlite3
import sys
import threading
import sqlite_vec
from datetime import datetime, timezone
from pathlib import Path

from orbit.runtime import sqlite_supports_extensions
from orbit.storage.session import LEGACY_USER_ID, legacy_user_email

_SCHEMA = Path(__file__).parent / "schema.sql"


def _extension_error() -> RuntimeError:
    return RuntimeError(
        "This Python build cannot load SQLite extensions (required for sqlite-vec embeddings).\n"
        "Fix: activate the project venv and verify with its `python`, not system `python3`:\n"
        "  source .venv/bin/activate\n"
        "  python -c \"import sqlite3; sqlite3.connect(':memory:').enable_load_extension(True)\"\n"
        "If the venv is missing or broken, recreate it:\n"
        "  brew install python@3.13\n"
        "  /opt/homebrew/bin/python3.13 -m venv .venv && source .venv/bin/activate && pip install -e .\n"
        "Or run capture-only:\n"
        "  orbit start --no-embed\n"
        f"Current interpreter: {sys.executable}\n"
        "See: https://alexgarcia.xyz/sqlite-vec/python.html"
    )

def _table_names(con: sqlite3.Connection) -> set[str]:
    return {
        r[0]
        for r in con.execute(
            "SELECT name FROM sqlite_master WHERE type='table'"
        ).fetchall()
    }


def _ensure_legacy_user(con: sqlite3.Connection) -> None:
    row = con.execute(
        "SELECT id FROM users WHERE id = ?", (LEGACY_USER_ID,)
    ).fetchone()
    if row is not None:
        return
    now = datetime.now(timezone.utc).isoformat()
    con.execute(
        """
        INSERT INTO users (id, email, display_name, created_at, cloud_user_id)
        VALUES (?, ?, ?, ?, NULL)
        """,
        (LEGACY_USER_ID, legacy_user_email(), "Legacy User", now),
    )


def _migrate_user_schema(con: sqlite3.Connection) -> None:
    tables = _table_names(con)
    if "users" not in tables:
        con.executescript(
            """
            CREATE TABLE users (
              id TEXT PRIMARY KEY,
              email TEXT NOT NULL UNIQUE,
              display_name TEXT NOT NULL,
              created_at TEXT NOT NULL,
              cloud_user_id TEXT
            );
            CREATE TABLE user_sessions (
              user_id TEXT PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
              last_active_at TEXT NOT NULL
            );
            """
        )
    _ensure_legacy_user(con)

    user_tables = (
        ("context_events", "idx_events_user_ts"),
        ("fs_events", "idx_fs_events_user_ts"),
        ("capture_audit", "idx_capture_audit_user_ts"),
        ("task_log", "idx_task_log_user_ts"),
    )
    for table, index_name in user_tables:
        if table not in _table_names(con):
            continue
        cols = {row[1] for row in con.execute(f"PRAGMA table_info({table})")}
        if "user_id" not in cols:
            con.execute(
                f"ALTER TABLE {table} ADD COLUMN user_id TEXT REFERENCES users(id)"
            )
            con.execute(
                f"UPDATE {table} SET user_id = ? WHERE user_id IS NULL",
                (LEGACY_USER_ID,),
            )
            con.execute(
                f"CREATE INDEX IF NOT EXISTS {index_name} ON {table}(user_id, timestamp)"
            )


def _migrate_schema(con: sqlite3.Connection) -> None:
    cols = {row[1] for row in con.execute("PRAGMA table_info(context_events)")}
    if "capture_method" not in cols:
        con.execute(
            "ALTER TABLE context_events ADD COLUMN capture_method TEXT DEFAULT 'ax'"
        )
    if "capture_tier" not in cols:
        con.execute(
            "ALTER TABLE context_events ADD COLUMN capture_tier INTEGER DEFAULT 1"
        )
    if "page_url" not in cols:
        con.execute("ALTER TABLE context_events ADD COLUMN page_url TEXT")

    tables = _table_names(con)
    if "fs_events" not in tables:
        con.executescript(
            """
            CREATE TABLE fs_events (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              timestamp TEXT NOT NULL,
              path TEXT NOT NULL,
              event_type TEXT NOT NULL,
              mtime REAL,
              linked_event_id INTEGER REFERENCES context_events(id) ON DELETE SET NULL,
              capture_tier INTEGER DEFAULT 3
            );
            CREATE INDEX idx_fs_events_ts ON fs_events(timestamp);
            CREATE INDEX idx_fs_events_linked ON fs_events(linked_event_id);
            """
        )
    if "capture_audit" not in tables:
        con.executescript(
            """
            CREATE TABLE capture_audit (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              timestamp TEXT NOT NULL,
              capture_method TEXT NOT NULL,
              capture_tier INTEGER NOT NULL,
              atom_count INTEGER NOT NULL,
              app_bundle_id TEXT
            );
            CREATE INDEX idx_capture_audit_ts ON capture_audit(timestamp);
            """
        )

    _migrate_user_schema(con)


def _apply_schema(con: sqlite3.Connection, skip_vec: bool = False) -> None:
    sql = _SCHEMA.read_text()
    if skip_vec:
        # Filter whole statements that reference vec0/vec_atoms
        statements = [s.strip() for s in sql.split(";") if s.strip()]
        sql = ";\n".join(
            s for s in statements
            if "vec0" not in s and "vec_atoms" not in s
        ) + ";"
    con.executescript(sql)
    _migrate_schema(con)


def open_db_plain(path: str) -> tuple[sqlite3.Connection, threading.Lock]:
    """Open the context DB without sqlite-vec (FTS + relational tables only)."""
    con = sqlite3.connect(path, check_same_thread=False, isolation_level=None)
    con.row_factory = sqlite3.Row
    con.execute("PRAGMA journal_mode=WAL;")
    con.execute("PRAGMA synchronous=NORMAL;")
    con.execute("PRAGMA foreign_keys=ON;")
    _apply_schema(con, skip_vec=True)
    return con, threading.Lock()


def open_db(path: str) -> tuple[sqlite3.Connection, threading.Lock]:
    """Open the context DB with sqlite-vec loaded and ``vec_atoms`` created."""
    if not sqlite_supports_extensions():
        raise _extension_error()
    con = sqlite3.connect(path, check_same_thread=False, isolation_level=None)
    con.row_factory = sqlite3.Row
    con.enable_load_extension(True)
    sqlite_vec.load(con)
    con.enable_load_extension(False)
    con.execute("PRAGMA journal_mode=WAL;")
    con.execute("PRAGMA synchronous=NORMAL;")
    con.execute("PRAGMA foreign_keys=ON;")
    _apply_schema(con)
    lock = threading.Lock()
    return con, lock

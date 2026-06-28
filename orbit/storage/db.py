"""SQLite connection helpers for the Orbit context store.

Two open paths:

- ``open_db`` — loads the sqlite-vec extension and creates the ``vec_atoms`` virtual
  table. Requires a Python build with loadable SQLite extensions (Homebrew Python on
  macOS; not the python.org installer). See https://alexgarcia.xyz/sqlite-vec/python.html
- ``open_db_plain`` — schema without vec0; used for capture-only mode (``--no-embed``)
  or when extensions are unavailable.

Use ``sqlite_supports_extensions()`` to probe capability before calling ``open_db``.
"""
import sqlite3
import sys
import threading
import sqlite_vec
from pathlib import Path

_SCHEMA = Path(__file__).parent / "schema.sql"


def sqlite_supports_extensions() -> bool:
    """Return True when this Python build can load SQLite extensions (required for sqlite-vec)."""
    return hasattr(sqlite3.connect(":memory:"), "enable_load_extension")


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

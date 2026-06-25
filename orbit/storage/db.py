import sqlite3
import threading
import sqlite_vec
from pathlib import Path

_SCHEMA = Path(__file__).parent / "schema.sql"

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
    """Open DB without sqlite_vec — for modules that don't need vector search."""
    con = sqlite3.connect(path, check_same_thread=False, isolation_level=None)
    con.row_factory = sqlite3.Row
    con.execute("PRAGMA journal_mode=WAL;")
    con.execute("PRAGMA synchronous=NORMAL;")
    con.execute("PRAGMA foreign_keys=ON;")
    _apply_schema(con, skip_vec=True)
    return con, threading.Lock()


def open_db(path: str) -> tuple[sqlite3.Connection, threading.Lock]:
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

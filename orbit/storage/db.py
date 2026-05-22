import sqlite3
import threading
import sqlite_vec
from pathlib import Path

_SCHEMA = Path(__file__).parent / "schema.sql"

def open_db(path: str) -> tuple[sqlite3.Connection, threading.Lock]:
    con = sqlite3.connect(path, check_same_thread=False, isolation_level=None)
    con.row_factory = sqlite3.Row
    con.enable_load_extension(True)
    sqlite_vec.load(con)
    con.enable_load_extension(False)
    con.execute("PRAGMA journal_mode=WAL;")
    con.execute("PRAGMA synchronous=NORMAL;")
    con.execute("PRAGMA foreign_keys=ON;")
    con.executescript(_SCHEMA.read_text())
    lock = threading.Lock()
    return con, lock

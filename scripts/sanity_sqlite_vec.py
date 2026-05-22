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

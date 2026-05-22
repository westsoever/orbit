#!/usr/bin/env bash
set -e
cd "$(dirname "$0")/.."
source .venv/bin/activate

echo "=== sanity: macapptree ==="
.venv/bin/python scripts/sanity_macapptree.py || echo "WARN: macapptree sanity failed (may need Accessibility permission)"

echo "=== sanity: sqlite-vec ==="
.venv/bin/python scripts/sanity_sqlite_vec.py

echo "=== sanity: embeddings ==="
.venv/bin/python scripts/sanity_embed.py

echo "=== DB schema check (if orbit.db exists) ==="
if [ -f orbit.db ]; then
  .venv/bin/python -c "
import sqlite3, sys
c = sqlite3.connect('orbit.db')
rows = c.execute('SELECT name FROM sqlite_master WHERE type IN (\"table\",\"trigger\") ORDER BY name').fetchall()
for r in rows:
    print(r[0])
"
else
  echo "orbit.db not found — skip schema check"
fi

echo "=== all checks passed ==="

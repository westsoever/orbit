#!/usr/bin/env bash
set -e
cd "$(dirname "$0")/.."
source .venv/bin/activate

NO_EMBED=0
for arg in "$@"; do
  if [ "$arg" = "--no-embed" ]; then
    NO_EMBED=1
  fi
done

echo "=== anti-patterns ==="
bash scripts/grep_antipatterns.sh

echo "=== compileall ==="
.venv/bin/python -m compileall -q orbit scripts

echo "=== schema smoke (test_fsevents) ==="
.venv/bin/python scripts/test_fsevents.py

echo "=== sanity: macapptree ==="
.venv/bin/python scripts/sanity_macapptree.py || echo "WARN: macapptree sanity failed (may need Accessibility permission)"

if [ "$NO_EMBED" -eq 0 ]; then
  echo "=== sanity: sqlite-vec ==="
  if .venv/bin/python -c "import sqlite3; exit(0 if hasattr(sqlite3.connect(':memory:'), 'enable_load_extension') else 1)"; then
    .venv/bin/python scripts/sanity_sqlite_vec.py
  else
    echo "SKIP: sqlite-vec (Python build lacks loadable SQLite extensions; use Homebrew Python for embed support)"
  fi

  echo "=== sanity: embeddings ==="
  .venv/bin/python scripts/sanity_embed.py
else
  echo "SKIP: embed sanity (--no-embed)"
fi

echo "=== DB schema check ==="
.venv/bin/python -c "
import os, tempfile
from pathlib import Path
from orbit.storage.db import open_db_plain

def check_db(path):
    con, _ = open_db_plain(path)
    rows = con.execute(
        'SELECT name FROM sqlite_master WHERE type IN (\"table\",\"trigger\") ORDER BY name'
    ).fetchall()
    for r in rows:
        print(r[0])
    required = {'fs_events', 'capture_audit'}
    found = {r[0] for r in rows}
    missing = required - found
    if missing:
        raise SystemExit(f'missing tables: {missing}')

if os.path.isfile('orbit.db'):
    try:
        check_db('orbit.db')
    except Exception as e:
        print(f'WARN: could not open orbit.db ({e}); using temp DB')
        tmp = Path('.orbit-test-tmp')
        tmp.mkdir(exist_ok=True)
        p = str(tmp / 'verify-schema.db')
        check_db(p)
        os.remove(p)
else:
    tmp = Path('.orbit-test-tmp')
    tmp.mkdir(exist_ok=True)
    p = str(tmp / 'verify-schema.db')
    check_db(p)
    os.remove(p)
"

echo "=== all checks passed ==="

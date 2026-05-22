# Acceptance Walkthrough — Plan 01

## How to run the daemon
```bash
source .venv/bin/activate
python -m orbit.capture.daemon --db ./orbit.db
```
Switch focus across 3+ apps for ≥30 minutes. Then:
```bash
sqlite3 orbit.db "SELECT count(*) FROM text_atoms;"
sqlite3 orbit.db "SELECT count(*) FROM vec_atoms;"
# Counts should be within 32 of each other (in-flight batch).
```

## How to search
```bash
python -m orbit.search --mode lexical  "your phrase"
python -m orbit.search --mode semantic "your phrase"
python -m orbit.search --mode hybrid   "your phrase"
```

## How to resolve a URI
```python
from orbit.storage.db import open_db
from orbit.search.links import resolve
con, _ = open_db("./orbit.db")
print(resolve(con, "orbit://atom/1"))
```

## Baseline metrics (fill in after first 30-min run)
- Peak RSS: ___
- CPU%: ___
- text_atoms count: ___
- vec_atoms count: ___

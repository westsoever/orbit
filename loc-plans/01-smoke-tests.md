# Plan 01: Automated smoke tests

Validates Python and Swift compile, schema migrations, and repo hygiene. Safe to run without capture permissions.

**Source:** `scripts/verify.sh`, `tests/`, `OrbitAccessApp/`, `services/orbit-relay/`

## Steps

### 1. Anti-patterns and compile

```bash
cd ~/path/to/orbit
source .venv/bin/activate
bash scripts/grep_antipatterns.sh
bash scripts/verify.sh --no-embed
```

**Pass:** exits 0; ends with `=== all checks passed ===`.

**Common failure:** missing `users` table in schema check — pull latest `main` (user scoping landed in #3).

### 2. Python unit tests

```bash
pytest tests/test_user_session.py tests/test_cloud_llm.py -q
cd services/orbit-relay && pip install -e ".[dev]" && pytest -q
```

**Pass:** all tests green.

### 3. Bridge API (in-process, no daemon)

```bash
cd ~/path/to/orbit
source .venv/bin/activate
python scripts/test_bridge_api.py
```

**Pass:** no tracebacks; shutdown route tested.

### 4. Swift build

```bash
cd OrbitAccessApp
swift build -c debug
```

**Pass:** `Build complete!` with no errors.

## Not covered here (see other plans)

- Real AX capture (`07-capture-and-compatibility.md`)
- GUI interactions (`06-orbit-access-ui.md`)
- `/Applications` install path (`02-install-and-app-bundle.md`)

## Pass criteria

- [ ] `verify.sh --no-embed` green
- [ ] `pytest` for user session + cloud LLM green
- [ ] `services/orbit-relay` pytest green
- [ ] `swift build` green

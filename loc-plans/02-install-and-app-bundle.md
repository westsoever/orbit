# Plan 02: Install and app bundle

Cloud agents implemented Ollama-style install and embedded Python in `Orbit.app`, but **bundle assembly only runs on macOS**.

**Commits:** `aafd682`, `f48476b`, `8bed29a`  
**Source plans:** `plans/10-one-line-install.md`, `plans/14-chat-enablement.md` Phase 1

## Part A — Dev bundle build

```bash
cd ~/path/to/orbit
source .venv/bin/activate
bash scripts/build-app-bundle.sh --output /tmp/Orbit.app
```

**Pass checks:**

```bash
test -f /tmp/Orbit.app/Contents/Resources/orbit-venv/lib/python3.13/site-packages/orbit/storage/schema.sql
/tmp/Orbit.app/Contents/Resources/orbit doctor
/tmp/Orbit.app/Contents/Resources/orbit start --detach --no-embed --no-statusbar
sleep 3
curl -sf http://127.0.0.1:8765/health
/tmp/Orbit.app/Contents/Resources/orbit stop
```

**Pass:** build prints `db ok`; health returns `{"ok": true}`; daemon stops cleanly.

**Failure — `schema.sql` missing:** rebuild after confirming `pyproject.toml` has `[tool.setuptools.package-data]` for `storage/schema.sql`. Do not copy schema into `orbit-core/` — runtime reads from the venv site-packages.

## Part B — One-line install (tester path)

On a machine **without** an existing Orbit install (or after uninstall):

```bash
ORBIT_NO_START=1 curl -fsSL https://raw.githubusercontent.com/westsoever/orbit/main/scripts/install.sh | bash
```

**Pass checks:**

```bash
test -d /Applications/Orbit.app
readlink /usr/local/bin/orbit   # → …/Orbit.app/Contents/Resources/orbit
orbit doctor
xattr -cr /Applications/Orbit.app   # if Gatekeeper blocks first open
open -a Orbit
```

**Pass:** Orbit appears in `/Applications`; CLI on PATH; app launches.

## Part C — Upgrade preserves data

1. Capture a few events (see `07-capture-and-compatibility.md`).
2. Re-run `install.sh` (or Part A build into `/Applications`).
3. Confirm `~/.orbit/orbit.db` still has rows:

```bash
sqlite3 ~/.orbit/orbit.db "SELECT count(*) FROM context_events;"
```

**Pass:** count unchanged after reinstall.

## Part D — Installed app daemon from UI

1. Open **Orbit** from `/Applications` (not `run_orbit_access_app.sh`).
2. Complete sign-up if prompted (`04-user-signup-and-scoping.md`).
3. Confirm daemon comes online without manual `orbit start` in Terminal.

```bash
curl -sf http://127.0.0.1:8765/api/status
```

**Pass:** `{"ok": true, …}`; sidebar CAPTURE shows running state.

## Pass criteria

- [ ] Part A: temp bundle builds and daemon starts
- [ ] Part B: one-line install succeeds
- [ ] Part C: `~/.orbit/` survives upgrade
- [ ] Part D: installed app starts daemon without Terminal

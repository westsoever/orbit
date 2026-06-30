# Plan 07: Capture and compatibility

Real Accessibility capture only runs on macOS with permission. Validates tier-1 AX pipeline and documents results in the compatibility matrix.

**Source plans:** `plans/03-universal-capture.md`, `plans/01-acceptance.md`  
**Docs:** `docs/capture-compatibility.md`, `orbit/capture/PERMISSIONS.md`

## Setup

```bash
source .venv/bin/activate
orbit stop 2>/dev/null || true
orbit start --no-embed    # foreground for easy Ctrl-C, or --detach
```

Grant Accessibility to Terminal or Orbit.app.

## Part A — Basic capture loop

1. Switch focus across **Terminal**, **Safari**, **Notes** for 2–3 minutes.
2. Watch daemon log or UI history.

```bash
sqlite3 ~/.orbit/orbit.db "SELECT count(*) FROM text_atoms;"
sqlite3 ~/.orbit/orbit.db \
  "SELECT app_name, capture_method, capture_tier FROM context_events ORDER BY id DESC LIMIT 10;"
```

**Pass:** atom count increases; tier 1 AX events for native apps.

## Part B — Probe script (per-app depth)

```bash
python scripts/probe_app.py --bundle com.apple.Terminal
python scripts/probe_app.py --bundle com.apple.Notes
python scripts/probe_app.py --all-visible
```

**Pass:** non-zero atoms for Terminal/Notes; Electron apps use deeper depth (24) if Cursor/VS Code open.

Update `docs/capture-compatibility.md` with your macOS version and results for any app you rely on.

## Part C — Chromium / browser tier 2

For Chrome, Arc, or Dia:

1. `orbit start --detach` (browser bridge on `:8765`).
2. Load unpacked extension from `orbit/browser-extension/` OR enable `chrome://accessibility/`.
3. Browse with visible page text; confirm browser events in DB.

```bash
python scripts/test_browser_bridge.py   # requires running daemon
```

**Pass:** browser_queue events; URL/title captured.

## Part D — FSEvents tier 3 (opt-in)

```bash
orbit privacy enable-fsevents
# Ensure watch_roots in ~/.orbit/policy.json exist
touch ~/Projects/orbit-fsevents-test.txt   # adjust path to a watched root
python scripts/test_fsevents.py
```

**Pass:** `fs_events` rows linked to recent focus events.

## Part E — Search over captured data

```bash
python -m orbit.search "phrase from a visible window"
orbit search "same phrase"    # if CLI alias exists
```

**Pass:** hybrid or lexical hits referencing recent atoms.

## Part F — 30-minute acceptance metrics (`plans/01-acceptance.md`)

Run daemon with embed **optional** (`--no-embed` OK for CPU):

1. Normal work session ≥ 30 minutes.
2. Record:

| Metric | Your value |
|--------|------------|
| Peak RSS | |
| CPU % (Activity Monitor) | |
| `text_atoms` count | |
| `vec_atoms` count (if embed on) | |

**Pass:** stable capture without runaway CPU; counts grow steadily.

## Pass criteria

- [ ] Part A: multi-app AX capture
- [ ] Part B: probe script results documented
- [ ] Part C: browser path (if you use Chromium daily)
- [ ] Part D: FSEvents (optional)
- [ ] Part E: search returns recent content
- [ ] Part F: 30-min session metrics filled in

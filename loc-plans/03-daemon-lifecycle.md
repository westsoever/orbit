# Plan 03: Daemon lifecycle

Validates auto-start on app launch, reliable stop/restart, and macOS notifications. Implemented in cloud sessions without runtime proof.

**Commits:** `dfaa495`, `1e24f82`, `1099aa`  
**Source plan:** `plans/12-daemon-restart-notifications.md`

## Setup

- Use installed `/Applications/Orbit.app` or dev build from `02-install-and-app-bundle.md`
- Sign in (see `04-user-signup-and-scoping.md`)
- Allow notifications: System Settings → Notifications → **Orbit**

## Part A — Auto-start on launch

1. `orbit stop` (or sidebar **Stop**) — confirm offline.
2. Quit Orbit completely (menu bar **Quit Orbit**).
3. Re-open Orbit from `/Applications` or Spotlight.

**Pass:**

- Within ~15 s, `curl -sf http://127.0.0.1:8765/api/status` succeeds.
- Sidebar CAPTURE shows online / capturing (after Accessibility granted).
- Chat placeholder no longer says “start the daemon first”.

## Part B — Stop → Start from sidebar (×3)

1. Sidebar **CAPTURE** → **Stop**.
2. Wait until status dot is red / offline (`curl` fails within 10 s).
3. Click **Start**.
4. Repeat **3 times** without quitting the app.

**Pass:**

- Each cycle recovers within ~15 s.
- No persistent `.error(startTimeout)` in sidebar.
- `pgrep -fl orbit.capture.daemon | wc -l` ≤ 1 after each start.

## Part C — HTTP-only stop then CLI restart (regression)

Simulates the old bug where HTTP shutdown left a stale PID:

```bash
orbit start --detach --no-embed
curl -X POST http://127.0.0.1:8765/api/shutdown
sleep 2
curl -sf http://127.0.0.1:8765/health || echo "health down"
orbit start --detach --no-embed
curl -sf http://127.0.0.1:8765/api/status | grep '"ok": true'
orbit stop
```

**Pass:** second `orbit start` succeeds after HTTP shutdown.

## Part D — System notifications

1. With notifications allowed, click **Stop** in sidebar.
2. Click **Start**.

**Pass:**

- macOS banner: capture stopped (on stop).
- macOS banner: capture running (on start).
- No notification spam every 5 s while idle.

**If denied:** Start/Stop still works; no crash.

## Part E — Status bar popover

1. Open menu bar Orbit popover.
2. Stop and start from popover (not sidebar).

**Pass:** same behavior as sidebar; no double-spawn on rapid clicks.

## Pass criteria

- [ ] Part A: auto-start on app launch
- [ ] Part B: stop/start ×3 without timeout
- [ ] Part C: CLI restart after HTTP shutdown
- [ ] Part D: notifications on user-initiated transitions
- [ ] Part E: popover controls match sidebar

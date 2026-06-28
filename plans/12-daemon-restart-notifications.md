# Plan: Fix daemon restart after stop + system notifications

**Goal:** After the user stops the Orbit capture daemon from Orbit Access, clicking **Start** reliably brings it back online. Post macOS **system notifications** when the daemon transitions to stopped and when it becomes healthy again.

**Scope:** Swift app (`OrbitAccessApp/`) + Python spawn/stop helpers (`orbit/daemon_ctl.py`). No bridge protocol changes required.

**Status:** Implemented (2026-06-29).

**Root issue (from Phase 0):** HTTP stop considers success when `/api/status` goes down, but `orbit start --detach` treats a **live PID** (even with dead bridge) as “already running” and skips spawn. Swift then times out → `.error(startTimeout)` while UI shows Start (`isDaemonOnline == false`).

**References:**
- Stop early-return (no CLI cleanup): `OrbitAccessApp/Services/DaemonManager.swift:112–117`
- Spawn skip on alive PID: `orbit/daemon_ctl.py:66–72`, `99–102`
- Status polling overwrites control state: `OrbitAccessApp/Services/DaemonManager.swift:145–156`
- Start UI gate: `OrbitAccessApp/Views/SidePane/DaemonStatusIndicator.swift:78–90`
- Shutdown hook: `orbit/browser_bridge/server.py:165–172`, `orbit/capture/daemon.py:135–138`
- In-app issue panel (do **not** duplicate daemon offline there): `plans/05-bottom-left-issue-notifications.md:54`

---

## Phase 0: Documentation Discovery (complete)

### Allowed APIs — daemon lifecycle (repo)

| API | Source | Notes |
|-----|--------|-------|
| `DaemonManager.start()` / `stop()` | `DaemonManager.swift:61–143` | Orchestrates `orbit start --detach` / `orbit stop` + HTTP shutdown |
| `OrbitBridgeClient.checkStatus()` | `OrbitBridgeClient.swift:13–29` | `GET /api/status` → `ok` |
| `OrbitBridgeClient.requestShutdown()` | `OrbitBridgeClient.swift:32–40` | `POST /api/shutdown` → 204 |
| `spawn_detached()` | `orbit/daemon_ctl.py:87–124` | Returns `(pid, started_new)`; skips spawn when `running_daemon_pid()` set |
| `is_daemon_running()` | `orbit/daemon_ctl.py:66–72` | **True if health OR alive PID** — causes false “already running” |
| `stop_daemon()` | `orbit/daemon_ctl.py:127–165` | HTTP shutdown + PID cleanup via `orbit stop` CLI |
| `AppViewModel.pollDaemonStatus()` | `AppViewModel.swift:126–131` | 5 s timer; calls `syncControlState` |
| `DaemonControlState` | `DaemonManager.swift:3–8` | `.offline`, `.starting`, `.running`, `.stopping`, `.error(String)` |

### Allowed APIs — macOS system notifications (Apple)

| API | Source | Notes |
|-----|--------|-------|
| `import UserNotifications` | [UNUserNotificationCenter](https://developer.apple.com/documentation/usernotifications/unusernotificationcenter) | Modern local notifications on macOS 10.14+ |
| `UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])` | Apple docs | Call once at launch; handle denial gracefully |
| `UNMutableNotificationContent` + `UNNotificationRequest(identifier:content:trigger:)` | Apple docs | `trigger: nil` → deliver immediately |
| `UNUserNotificationCenter.current().add(_:)` | Apple docs | Async; use unique `identifier` per event or replace by fixed ID |
| `UNUserNotificationCenterDelegate` | Apple docs | Optional; set on `AppDelegate` if foreground presentation needed |

**Sandbox:** `OrbitAccessApp.entitlements` has app sandbox + network client + `~/.orbit` RW. **No extra entitlement** is required to *post* local notifications. (Reading other apps’ notifications would need different entitlements — out of scope.)

**Repo state:** No `UserNotifications` usage in Swift today (`grep` over `OrbitAccessApp/**/*.swift` → empty).

### Anti-patterns to avoid

- Do **not** use deprecated `NSUserNotification` / `NSUserNotificationCenter`.
- Do **not** treat HTTP bridge offline as “process dead” without PID cleanup (`DaemonManager.stop` today).
- Do **not** let `is_daemon_running()` block spawn on **alive PID alone** when health is down — that is the restart bug.
- Do **not** add daemon-offline to the bottom-left `OrbitIssue` panel (`plans/05` explicitly excludes it).
- Do **not** spam notifications on the 5 s poll timer — fire only on **edge transitions** of `isDaemonOnline`.
- Do **not** block `start()` on `.error` — allow retry; clear error when entering `.starting`.
- Do **not** run `Process.waitUntilExit()` on `@MainActor` for long CLI calls — move to detached task or `Task.detached` (follow-up polish).

### Confidence & gaps

| Finding | Confidence |
|---------|------------|
| PID-alive / health-dead causes failed restart | **High (~75%)** |
| `syncControlState` race flips UI back to Stop | Medium (~60%) |
| Exact repro without runtime `ps` + `curl` logs | Not verified — manual checklist below |

---

## Phase 1: Fix Python spawn/stop semantics

**What to implement:** Copy health-first semantics into `daemon_ctl.py` so a dead bridge never blocks a new spawn.

### Tasks

1. **Split “running” vs “healthy”** in `orbit/daemon_ctl.py`:
   - Add `is_daemon_healthy(health_url)` → `_health_ok()` only.
   - Change `running_daemon_pid()` used by `spawn_detached` to return a PID **only when healthy** (or when health is up).
   - If health is down but PID is alive → treat as **stale/orphan** (not “already running”).

2. **Add `reap_stale_daemon(pid_path, health_url)`** (same file):
   - If `not _health_ok()` and `read_pid()` is alive → `stop_pid(pid)` + `remove_pid()`.
   - Call this inside `daemon_spawn_lock()` **before** spawning.

3. **Tighten `is_daemon_running()`** (used by `daemon.py` early-exit):
   - Require `_health_ok()` for “already running” exit in `capture/daemon.py:83–88`.
   - Alive PID without health should be reaped, not block startup.

4. **CLI messaging** (`orbit/cli.py` detach path):
   - When `spawn_detached` reaps then starts, log clearly in `~/.orbit/daemon.log`.

### Copy-ready pattern

Copy lock + spawn structure from existing `spawn_detached` (`daemon_ctl.py:99–112`); insert reap step immediately after lock acquisition.

### Verification checklist

```bash
# 1. Start daemon
orbit start --detach --no-embed --no-statusbar

# 2. HTTP stop only (simulate app stop path)
curl -X POST http://127.0.0.1:8765/api/shutdown
sleep 2
curl -sf http://127.0.0.1:8765/health || echo "health down"

# 3. Restart must succeed
orbit start --detach --no-embed --no-statusbar
curl -sf http://127.0.0.1:8765/api/status | grep '"ok": true'

# 4. PID file must match live healthy process
cat ~/.orbit/daemon.pid
```

---

## Phase 2: Fix Swift `DaemonManager` stop/start

**What to implement:** Always fully stop the OS process; make start resilient to stale state.

### Tasks

1. **Remove early return after HTTP shutdown** — copy full stop path from `DaemonManager.swift:124–142` and **always run `orbit stop`** after `requestShutdown()` (even when `waitForOffline` succeeds):
   ```swift
   // After HTTP shutdown attempt, always:
   // run `orbit stop` CLI + waitForOffline
   // Do NOT return at line 117 without CLI cleanup
   ```

2. **Add `forceStopCLI()` private helper** on `DaemonManager`:
   - Runs `orbit stop`, checks exit 0, waits for offline.
   - Used by both HTTP-first and CLI-only paths.

3. **Harden `start()`** (`DaemonManager.swift:61–100`):
   - Clear `.error` when entering `.starting`.
   - If `orbit start --detach` exits 0 but `waitForOnline` fails → run `forceStopCLI()` once, retry `orbit start` once.
   - Mark `@MainActor` on `DaemonManager` (entire type) to match `stop()` and avoid `controlState` races.

4. **Fix `syncControlState`** (`DaemonManager.swift:145–156`):
   - Do not promote `.offline` → `.running` from poll within N seconds after stop (optional `lastStoppedAt` timestamp), **or**
   - Simpler: only call `syncControlState` when `controlState` is `.running` or `.offline` (not after `.error` until user retries).

### Verification checklist

Manual in Orbit Access:

1. Start daemon → sidebar shows “Daemon running”, `curl /api/status` ok.
2. Stop daemon → offline within 10 s; `ps` shows no `orbit.capture.daemon`.
3. Start again → online within 10 s; **no** `.error(startTimeout)` in sidebar.
4. Repeat stop/start **3×** without quitting app.

---

## Phase 3: macOS system notifications

**What to implement:** Copy Apple’s `UNUserNotificationCenter` local-notification pattern; wire to daemon online/offline edges.

### Tasks

1. **Add `OrbitAccessApp/Services/DaemonNotificationService.swift`**:
   ```swift
   import UserNotifications

   @MainActor
   final class DaemonNotificationService {
       static let shared = DaemonNotificationService()
       private var authorized = false

       func requestAuthorizationIfNeeded() async { ... }

       func notifyDaemonStopped() async { ... }  // title: "Orbit capture stopped"
       func notifyDaemonStarted() async { ... }  // title: "Orbit capture running"
   }
   ```
   - Fixed notification identifiers: `com.orbit.daemon.stopped`, `com.orbit.daemon.started` (replace prior if re-fired).
   - Body: short status line; no sensitive capture content.

2. **Request permission in `AppDelegate.applicationDidFinishLaunching`** (`AppDelegate.swift:14`):
   - `Task { await DaemonNotificationService.shared.requestAuthorizationIfNeeded() }`
   - If denied, silently skip (no in-app nag for this slice).

3. **Fire on transitions in `AppViewModel.pollDaemonStatus()`** (`AppViewModel.swift:126–131`):
   - Track `@ObservationIgnored private var lastNotifiedDaemonOnline: Bool?`
   - On change `true → false`: `notifyDaemonStopped()`
   - On change `false → true`: `notifyDaemonStarted()`
   - Skip first poll (nil → value) to avoid notification on app launch when daemon already running — **unless** user explicitly started/stopped in-session (use a `userInitiatedDaemonChange` flag set from `startDaemon`/`stopDaemon`).

   **Product rule:** Notify when user clicks Start/Stop **and** when daemon drops unexpectedly (poll detects offline while was online). Do **not** notify on cold launch.

4. **Optional:** Set `UNUserNotificationCenter.current().delegate = self` on `AppDelegate` to show banner when app is frontmost (`willPresent` → `[.banner, .sound]`).

### Anti-patterns

- No notification on every 5 s poll if state unchanged.
- No `OrbitIssue` panel entry for daemon (per `plans/05`).

### Verification checklist

1. System Settings → Notifications → Orbit Access → allow alerts.
2. Stop daemon → macOS notification “capture stopped”.
3. Start daemon → macOS notification “capture running”.
4. Deny permission → Start/Stop still works; no crash.

---

## Phase 4: UI consistency (Start button + transitions)

**What to implement:** Copy transition guard from sidebar to status-bar popover.

### Tasks

1. **`StatusBarPopoverView.swift:40–52`** — copy `isTransitioning` pattern from `DaemonStatusIndicator.swift:94–100`:
   - Show `ProgressView` while `.starting` / `.stopping`.
   - Disable double-tap on Start/Stop.

2. **Gate buttons on `daemonControlState`**, not only `isDaemonOnline`:
   - Show Start when `!isDaemonOnline && !isTransitioning` **or** when `.error` (allow retry).

3. **Surface start failure** in status-bar popover (sidebar already shows `.error` message at `DaemonStatusIndicator.swift:25–29`).

### Verification checklist

- Rapid double-click Start does not spawn duplicate CLI processes (`pgrep -fl orbit.capture.daemon` count ≤ 1).

---

## Phase 5: Verification (final)

### Automated / script checks

```bash
# No deprecated notification API
rg 'NSUserNotification' OrbitAccessApp/ && exit 1 || true

# Python: spawn must not skip on PID-only
rg 'is_process_alive' orbit/daemon_ctl.py  # ensure used for reap, not spawn skip

bash scripts/verify.sh --no-embed  # if daemon tests exist in smoke path
cd OrbitAccessApp && swift build -c debug
```

### Manual acceptance

| Step | Expected |
|------|----------|
| Stop → Start (app UI) | Daemon online; one menubar icon |
| Stop → Start ×3 | No timeout error |
| Stop | System notification |
| Start | System notification |
| Kill daemon from Terminal (`orbit stop`) while app open | App poll detects offline; optional unexpected-stop notification |

### Session boundaries (for parallel agents)

| Phase | Owns | Depends on |
|-------|------|------------|
| 1 | `orbit/daemon_ctl.py`, `orbit/capture/daemon.py` | — |
| 2 | `DaemonManager.swift`, `AppViewModel.swift` | Phase 1 |
| 3 | `DaemonNotificationService.swift`, `AppDelegate.swift` | Phase 2 (transitions stable) |
| 4 | `StatusBarPopoverView.swift` | Phase 2 |
| 5 | Verification only | 1–4 |

Each phase agent should read this file’s Phase 0 table before coding.

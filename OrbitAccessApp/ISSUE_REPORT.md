# Orbit Access App — Build & Run Issues

## Fixed

- [x] **Build path:** `scripts/run_orbit_access_app.sh` uses `swift build` + manual `.app` bundle (no full Xcode required for local dev)
- [x] **Signing bypass (dev):** `project.yml` / `project.pbxproj` set `CODE_SIGNING_ALLOWED: NO` and `CODE_SIGN_IDENTITY: "-"` for unsigned local builds
- [x] **Bundle output:** `.app` written to `build/OrbitAccessApp.app` (repo root), not inside `OrbitAccessApp/`
- [x] **Daemon auto-start:** script checks `GET /health` on `:8765`; starts `orbit start --detach --no-embed` if down; waits up to 10s
- [x] **Daemon sidebar controls:** `DaemonStatusIndicator` Start/Stop; `DaemonManager` calls `orbit start --detach` / `orbit stop` (or `POST /api/shutdown`)
- [x] **`ORBIT_ROOT`:** exported by run script for `OrbitPaths` (privacy policy, docs resolution)
- [x] **Disk pressure (partial):** removed Xcode DerivedData, workspace `xcuserdata`, stray `*.db` in repo root; `.gitignore` covers `.build/`, `.swiftpm/`, old in-tree `.app`
- [x] **Task Approve → dispatch:** `POST /api/task/{id}/approve` now calls `orbit.check.dispatch.dispatch()` and sets status `dispatched`
- [x] **Bootstrap UX:** bottom-left issue notifications for serious bootstrap failures + `retryDatabaseBootstrap()` when DB selection fails
- [x] **Search panel:** Sidebane search triggers activate panel; hybrid falls back to lexical FTS5
- [x] **Routines:** loaded from `~/.orbit/routines.json` with sensible defaults
- [x] **Privacy policy:** resolved via `ORBIT_ROOT` / repo-relative `OrbitPaths`
- [x] **Chat focus:** agent shortcuts request focus on chat input
- [x] **Status bar glyphs:** `○` idle · `●` capturing · `×` offline
- [x] **Chat errors:** assistant failures shown above input bar
- [x] **Main window interactivity:** issue notification overlay no longer blocks clicks; chat enabled when daemon auto-starts via run script

## Remaining

- [ ] **Disk space:** host disk was near full during build; keep ≥5 GB free for SPM cache + `.build/` artifacts. Prune `~/Library/Developer/Xcode/DerivedData` and `OrbitAccessApp/.build` periodically
- [ ] **Xcode signing (distribution):** current flow is ad-hoc unsigned; Gatekeeper may block on first open. For release: enable signing in Xcode, set Team + `com.orbit.access` bundle ID, notarize
- [ ] **Sandbox DB access:** App Sandbox + security-scoped bookmark required; user must grant `~/.orbit/orbit.db` via NSOpenPanel on first launch
- [ ] **Full Xcode build:** `xcodebuild -scheme OrbitAccessApp` not verified on all machines; SPM path is the supported dev workflow
- [ ] **Menu bar / entitlements:** status item works unsigned locally; hardened-runtime entitlements need review before distribution

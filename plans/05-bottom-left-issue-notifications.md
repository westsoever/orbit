# Plan: Replace top status banner with bottom-left issue notifications

**Goal:** Remove the full-width top overlay row (e.g. "Database selection was cancelled. [Select orbit.db]") from `MainWindowView`. Surface **serious** issues only, in a compact notification panel anchored bottom-left that animates in with a subtle "ping" when a new issue appears.

**Scope:** Orbit Access macOS Swift app (`OrbitAccessApp/`). No changes to Python daemon or bridge protocol.

**Status:** Implemented (2026-06-28).

**References:**
- Current banner implementation: `OrbitAccessApp/Views/Root/MainWindowView.swift:10–84`
- Bootstrap state: `OrbitAccessApp/App/AppViewModel.swift:14–15`, `47–58`
- DB errors: `OrbitAccessApp/IPC/OrbitDBReader.swift:7–20`
- Card styling to copy: `OrbitAccessApp/Views/Components/OrbitCard.swift`
- Existing daemon status (non-banner): `OrbitAccessApp/Views/SidePane/DaemonStatusIndicator.swift`
- Design doc (bootstrap only, no banner spec): `plans/orbitaccessappdesign.md:380–385`

---

## Phase 0: Documentation Discovery (complete)

### Allowed APIs

| API | Source | Notes |
|-----|--------|-------|
| `AppViewModel.bootstrapError: String?` | `AppViewModel.swift:15` | Set from `error.localizedDescription` on bootstrap failure |
| `AppViewModel.isDatabaseReady: Bool` | `AppViewModel.swift:14` | `true` after successful `dbReader.bootstrap()` |
| `AppViewModel.isDaemonOnline: Bool` | `AppViewModel.swift:12` | Polled every 5 s via `pollDaemonStatus()` |
| `AppViewModel.retryDatabaseBootstrap()` | `AppViewModel.swift:47–58` | Clears error, re-runs `NSOpenPanel` path |
| `OrbitDBError.openPanelCancelled` | `OrbitDBReader.swift:11,18` | User dismissed file picker — **not serious** |
| `OrbitDBError.bookmarkMissing / bookmarkStale / databaseUnavailable` | `OrbitDBReader.swift:8–10,15–17` | **Serious** — app cannot read context |
| `ZStack(alignment:)` overlay pattern | `MainWindowView.swift:10` | Today `.top`; switch serious UI to `.bottomLeading` |
| `OrbitCard` surface/border/shadow | `OrbitCard.swift:9–26` | Copy card chrome for notification panel |
| `Color.orbitScoreRed`, `.orbitAccent` | `Color+Orbit.swift:4,12` | Severity accent colors |
| `.spring(response:dampingFraction:)` | `MainWindowView.swift:17`, `TaskCard.swift:76` | Existing motion language |
| `withAnimation` + `scaleEffect` / `offset` | SwiftUI stdlib | "Ping" entrance (no third-party toast lib) |
| `DaemonStatusIndicator` | `DaemonStatusIndicator.swift` | Already covers daemon offline in side pane |

### Anti-patterns to avoid

- Do **not** invent a global toast framework or `NotificationCenter` bus for this slice — one view + one model property is enough.
- Do **not** show `openPanelCancelled` as a serious issue (user explicitly dismissed the panel).
- Do **not** duplicate daemon-offline in the bottom-left panel — sidebar indicator already covers it; top banner for daemon is removed with the rest.
- Do **not** show the "Select orbit.db to load context history." prompt as a top row or ping on every launch flash — only ping when a **new serious issue** appears.
- Do **not** add AppKit `NSUserNotification` / UserNotifications framework — in-window SwiftUI overlay only.
- Do **not** block the three-pane layout with a modal for recoverable DB issues; keep optional action button on the panel.

### Severity matrix (product decision for this plan)

| Condition | Serious? | Bottom-left panel? | Action |
|-----------|----------|-------------------|--------|
| `OrbitDBError.openPanelCancelled` | No | Hidden | User can re-open via Capture section or a future menu item; no nag |
| `bootstrapError` (bookmark stale / DB unavailable) | Yes | Show + ping | "Select orbit.db" → `retryDatabaseBootstrap()` |
| `!isDatabaseReady` && no error (first launch, panel not yet shown) | No | Hidden | Bootstrap flow handles via panel when user initiates |
| `!isDaemonOnline` | No | Hidden | `DaemonStatusIndicator` in side pane |
| Chat/search inline errors | No | Hidden | Keep existing patterns in `MainChatView`, `SearchStore` |

---

## Phase 1: Serious-issue model on `AppViewModel`

**What to implement:** Add a typed issue surface so views don't parse error strings.

### Tasks

1. **Add `OrbitIssue` enum** — new file `OrbitAccessApp/Models/OrbitIssue.swift`:
   ```swift
   enum OrbitIssue: Equatable, Identifiable {
       case databaseBootstrapFailed(message: String)
       var id: String { ... }
       var message: String { ... }
       var actionTitle: String? { ... }  // "Select orbit.db" for DB failures
   }
   ```

2. **Store underlying error type on bootstrap failure** — extend `AppViewModel`:
   - Add `bootstrapFailure: OrbitDBError?` (or `Error`) alongside or instead of raw `bootstrapError: String?`.
   - In `start()` / `retryDatabaseBootstrap()` catch blocks, capture typed error:
     ```swift
     catch let error as OrbitDBError {
         bootstrapFailure = error
         bootstrapError = error.localizedDescription  // keep for logging if needed
     }
     ```
   - Copy catch pattern from `AppViewModel.swift:38–39`, `55–56`.

3. **Add computed `seriousIssue: OrbitIssue?`** on `AppViewModel`:
   ```swift
   var seriousIssue: OrbitIssue? {
       guard let failure = bootstrapFailure else { return nil }
       if case .openPanelCancelled = failure { return nil }
       return .databaseBootstrapFailed(message: failure.localizedDescription)
   }
   ```

4. **Clear serious state on success** — in both bootstrap success paths set `bootstrapFailure = nil`.

### Documentation references

- Error enum: `OrbitDBReader.swift:7–20`
- State mutations: `AppViewModel.swift:30–58`

### Verification checklist

```bash
rg 'seriousIssue|OrbitIssue|bootstrapFailure' OrbitAccessApp/
# Expect: OrbitIssue.swift, AppViewModel.swift references
rg 'openPanelCancelled' OrbitAccessApp/App/AppViewModel.swift
# Expect: explicit filter returning nil for seriousIssue
```

Build:

```bash
cd OrbitAccessApp && swift build
```

### Anti-pattern guards

- Do not compare localized strings like `"Database selection was cancelled."` — use `OrbitDBError` cases only.

---

## Phase 2: Bottom-left notification panel component

**What to implement:** Copy card chrome from `OrbitCard`; build a compact anchored panel with entrance "ping" animation.

### Tasks

1. **Create `OrbitIssueNotificationPanel.swift`** in `OrbitAccessApp/Views/Components/`:
   - Props: `issue: OrbitIssue`, optional `onAction: () -> Void`, optional `onDismiss: () -> Void`.
   - Layout: small `OrbitCard` (or inline copy of its background/border/shadow from `OrbitCard.swift:9–26`) with:
     - Leading accent: `Color.orbitScoreRed` for bootstrap failures
     - `Text(issue.message).font(.caption).lineLimit(3)`
     - Optional trailing `Button` when `issue.actionTitle != nil`
     - Optional dismiss `×` (small, plain) — recommended so cancelled-then-fixed flows don't leave stale UI
   - Max width ~320 pt; do not span full window width.

2. **Create `OrbitIssueNotificationHost.swift`** (or embed in `MainWindowView` if kept under 40 lines):
   - Observes `model.seriousIssue`.
   - When non-nil, render panel in bottom-left with padding (16 pt from leading and bottom edges).
   - **Ping animation** on appear and when `issue.id` changes:
     ```swift
     @State private var ping = false
     .scaleEffect(ping ? 1.0 : 0.92)
     .opacity(ping ? 1.0 : 0.0)
     .onChange(of: issue.id) { _, _ in
         ping = false
         withAnimation(.spring(response: 0.35, dampingFraction: 0.62)) {
             ping = true
         }
     }
     .onAppear { /* same spring */ }
     ```
   - Copy spring constants from `MainWindowView.swift:17` (`response: 0.3`, `dampingFraction: 0.85`) or use slightly lower damping (0.62) for visible bounce — tune visually once.

3. **Optional subtle secondary ping** — one-time `scaleEffect` 1.0 → 1.04 → 1.0 over 0.2 s after entrance (only if first animation feels too soft).

### Documentation references

- Card surface: `OrbitCard.swift:9–26`
- Colors: `Color+Orbit.swift:12–15`
- Motion: `MainWindowView.swift:17`, `TaskCard.swift:76`

### Verification checklist

- Preview or manual: panel appears bottom-left, does not overlap toolbar awkwardly.
- Panel width stays compact when side pane is collapsed (900 pt min window from `MainWindowView.swift:36`).

```bash
rg 'OrbitIssueNotification' OrbitAccessApp/
swift build  # from OrbitAccessApp/
```

### Anti-pattern guards

- Do not use `.alert` or `.sheet` for these issues.
- Do not reintroduce full-width `HStack { Text ... Spacer() }` banner layout from `statusBanner`.

---

## Phase 3: Remove top banner; wire notification host

**What to implement:** Delete top overlay; mount notification host on main window `ZStack`.

### Tasks

1. **Edit `MainWindowView.swift`:**
   - Remove `VStack` block lines 52–65 (all three `statusBanner` branches).
   - Remove private `statusBanner(...)` helper lines 69–84.
   - Change root layout to:
     ```swift
     ZStack(alignment: .bottomLeading) {
         ThreePaneLayout(...)
             .toolbar { ... }
         if let issue = model.seriousIssue {
             OrbitIssueNotificationHost(issue: issue) {
                 Task { await model.retryDatabaseBootstrap() }
             }
             .padding(.leading, 16)
             .padding(.bottom, 16)
         }
     }
     ```
   - Ensure `ThreePaneLayout` remains full-size (no top padding consumed by removed banner).

2. **Deprecate raw banner state (optional cleanup):**
   - If nothing else reads `bootstrapError`, remove it and use `bootstrapFailure` only.
   - Grep first: `rg 'bootstrapError' OrbitAccessApp/`

3. **Update `ISSUE_REPORT.md` fixed item** — change "status banners in main window" to "bottom-left issue notifications for serious bootstrap failures".

### Documentation references

- File to edit: `MainWindowView.swift:10–84`
- Retry hook: `AppViewModel.retryDatabaseBootstrap()`

### Verification checklist

Manual scenarios via `scripts/run_orbit_access_app.sh`:

| Scenario | Expected |
|----------|----------|
| Launch with valid Keychain bookmark | No top row; no bottom panel |
| Cancel `NSOpenPanel` on first DB pick | No top row; **no** bottom panel |
| Stale bookmark / corrupt DB path | Bottom-left panel pings with message + "Select orbit.db" |
| Click "Select orbit.db" on panel | Panel opens picker; on success panel disappears |
| Daemon stopped | No bottom panel; side pane shows red "Daemon offline" |

Screenshot regression: top edge of window shows search bar flush under title bar — no grey banner row.

```bash
rg 'statusBanner' OrbitAccessApp/
# Expect: zero matches
```

### Anti-pattern guards

- Do not leave dead `ZStack(alignment: .top)` wrapper if only child is full-size layout — use `.bottomLeading` or unaligned `ZStack` with explicit alignment on notification only.

---

## Phase 4: Verification

**What to implement:** Confirm behavior matches severity matrix and no banner regression.

### Tasks

1. **Static checks**
   ```bash
   rg 'statusBanner|Database selection was cancelled' OrbitAccessApp/Views/Root/
   rg 'seriousIssue|OrbitIssueNotification' OrbitAccessApp/
   ```

2. **Build**
   ```bash
   cd OrbitAccessApp && swift build
   bash scripts/run_orbit_access_app.sh   # if available
   ```

3. **Simulate serious bootstrap failure** (dev):
   - Temporarily force `OrbitDBError.bookmarkStale` in `bootstrap()` or invalidate Keychain bookmark in Keychain Access.
   - Confirm panel pings once on appear; action button retries bootstrap.

4. **Confirm non-serious paths unchanged**
   - `DaemonStatusIndicator` still updates when daemon stops.
   - `MainChatView` error strip still shows chat failures.
   - `SearchStore.lastError` still surfaces in search panel only.

### Success criteria

- [ ] Top banner row removed entirely (matches user screenshot request).
- [ ] Cancelled DB picker produces **no** nag UI.
- [ ] Real bootstrap failures show compact bottom-left panel with spring "ping".
- [ ] Panel includes recovery action where applicable.
- [ ] No new dependencies; SwiftUI + existing Orbit components only.

**Phase 4 static verification (2026-06-28):** `swift build` passes; no `statusBanner`/`bootstrapError` references; `seriousIssue` wired in `MainWindowView`.

---

## Session boundaries (for parallel agents)

| Phase | Own chat context | Inputs needed |
|-------|------------------|---------------|
| 1 | "Implement OrbitIssue + AppViewModel seriousIssue" | Phase 0 severity matrix |
| 2 | "Build OrbitIssueNotificationPanel + host" | `OrbitCard.swift`, `Color+Orbit.swift` |
| 3 | "Remove MainWindowView statusBanner; wire host" | Phase 1 + 2 merged |
| 4 | "Verify bootstrap scenarios" | Running app + Keychain bookmark state |

Each phase agent should read this file's Phase 0 table before coding.

# Plan: Today's Schedule — Calendar Placeholder

**Goal:** The Insight Sidebar "Today's Schedule" section represents the user's **actual calendar**, not Orbit capture activity. Until EventKit/CalDAV integration ships (Phase 4C), show a clear **"No calendar connected"** empty state. Context collection remains visible only under **Context Stream**.

**Status:** Phases 1–4 complete (2026-06-28). Static verification passed; `xcodebuild` unavailable in CI shell (Command Line Tools only).

**Scope:** `OrbitAccessApp` only. `orbit_dashboard/dashboard.html` already parses markdown "Scheduled Engagements" — leave unchanged unless explicitly requested.

**References:**
- Current (wrong) wiring: `OrbitAccessApp/Views/InsightSidebar/InsightSidebarView.swift:14-15`
- Context-as-schedule UI: `OrbitAccessApp/Views/InsightSidebar/DailyScheduleTimeline.swift`
- Context-as-schedule data: `OrbitAccessApp/Stores/InsightStore.swift:41`, `OrbitAccessApp/IPC/OrbitDBReader.swift:194-204`
- Design doc (needs update): `plans/orbitaccessappdesign.md:270-286`
- Future calendar source: `plans/03-universal-capture.md:308` (EventKit, Phase 4C)
- Empty-state pattern to copy: `OrbitAccessApp/Views/InsightSidebar/RecentCaptureList.swift:8-13`, `OrbitAccessApp/Views/Chat/ChatMessageList.swift:37-48`

---

## Phase 0: Documentation Discovery (complete)

### Allowed APIs & patterns

| API / pattern | Source | Notes |
|---------------|--------|-------|
| `SectionHeader(title:)` | `OrbitAccessApp/Views/Components/SectionHeader.swift` | Keep header text `"Today's Schedule"` |
| `Color.orbitSecondaryText(for: colorScheme)` | Orbit design tokens | Use for placeholder caption text |
| `@Environment(\.colorScheme)` | SwiftUI | Match `RecentCaptureList`, `DailyScheduleTimeline` |
| `RecentCaptureList` empty state | `RecentCaptureList.swift:8-13` | Copy layout: caption, centered, `.padding(.vertical, 8)` |
| `InsightStore.refreshAggregates()` | `InsightStore.swift:36-43` | **Remove** `schedule = fetchDailySchedule()` line only |
| `OrbitDBReader.fetchDailySchedule()` | `OrbitDBReader.swift:194-204` | **Delete** — no other callers after Phase 2 |
| `HourSlot` | `ProductivityScore.swift:28-35` | **Delete** if no references remain |
| EventKit (`EKEventStore`, `requestFullAccessToEvents`) | Apple docs — **Phase 4C only** | Do **not** import or call in this plan |

### Anti-patterns to avoid

- Do **not** query `context_events` for Today's Schedule (that belongs in Context Stream).
- Do **not** rename the section to "Activity" — user expects calendar semantics.
- Do **not** show Routines as a substitute for calendar events (Routines section stays separate).
- Do **not** add EventKit permissions, OAuth, or CalDAV in this plan.
- Do **not** invent `CalendarService.sync()` or similar — stub interface only if needed for compile-time clarity.

### Current vs desired behavior

| | Current | Desired (this plan) |
|---|---------|---------------------|
| Data source | `context_events` grouped by hour/app | None (disconnected) |
| Empty copy | `"No activity recorded today"` | `"No calendar connected"` |
| Non-empty | App name + event count per hour | N/A until Phase 4C |
| Context visibility | Mislabeled as schedule | Only in **Context Stream** section |

---

## Phase 1: Replace schedule UI with calendar placeholder

**What to implement:** Replace `DailyScheduleTimeline(slots:)` with a calendar-aware view that always shows the disconnected placeholder for now.

### Tasks

1. **Rename or replace `DailyScheduleTimeline.swift` → `CalendarScheduleView.swift`**
   - Copy empty-state pattern from `RecentCaptureList.swift:8-13`:
     ```swift
     struct CalendarScheduleView: View {
         @Environment(\.colorScheme) private var colorScheme

         var body: some View {
             VStack(spacing: 6) {
                 Image(systemName: "calendar")
                     .font(.title3)
                     .foregroundStyle(Color.orbitSecondaryText(for: colorScheme))
                 Text("No calendar connected")
                     .font(.caption)
                     .foregroundStyle(Color.orbitSecondaryText(for: colorScheme))
             }
             .frame(maxWidth: .infinity)
             .padding(.vertical, 8)
         }
     }
     ```
   - Optional (future hook, no logic yet): accept `events: [CalendarEvent]` and `isConnected: Bool` parameters defaulting to `[]` and `false`. When `isConnected == false`, always render placeholder regardless of `events`.
   - Remove all `HourSlot`, `TimeChip`, and timeline-row code from this file.

2. **Update `InsightSidebarView.swift:14-15`**
   - Replace:
     ```swift
     DailyScheduleTimeline(slots: model.insightStore.schedule)
     ```
   - With:
     ```swift
     CalendarScheduleView()
     ```
   - Do **not** pass `insightStore.schedule`.

3. **Update Xcode project**
   - In `OrbitAccessApp.xcodeproj/project.pbxproj`, swap file reference from `DailyScheduleTimeline.swift` to `CalendarScheduleView.swift` (copy existing PBX pattern from another InsightSidebar file).

### Documentation references

- Empty state: `RecentCaptureList.swift:8-13`
- Section wiring: `InsightSidebarView.swift:14-15`
- Icon + VStack empty state (richer): `ChatMessageList.swift:37-48`

### Verification checklist

```bash
# No HourSlot in schedule view
rg 'HourSlot|TimeChip|events recorded' OrbitAccessApp/Views/InsightSidebar/

# Placeholder copy present
rg 'No calendar connected' OrbitAccessApp/

# Build (unsigned local)
cd OrbitAccessApp && xcodebuild -scheme OrbitAccessApp -configuration Debug build CODE_SIGNING_ALLOWED=NO 2>&1 | tail -5
```

Manual: Open app → Insight Sidebar → Today's Schedule shows calendar icon + "No calendar connected". Context Stream still shows capture events when daemon is running.

---

## Phase 2: Remove context_events schedule data path

**What to implement:** Stop loading and storing capture aggregates as `schedule`. Delete dead types and DB query.

### Tasks

1. **`InsightStore.swift`**
   - Remove `var schedule: [HourSlot] = []` (line 10).
   - Remove `scheduleSlots` computed property (lines 11-13).
   - Remove `schedule = (try? dbReader.fetchDailySchedule()) ?? []` from `refreshAggregates()` (line 41).
   - Leave `productivityScore`, `atomsCapturedToday`, and `recentCaptures` unchanged.

2. **`OrbitDBReader.swift`**
   - Delete `fetchDailySchedule()` entirely (lines 194-204).

3. **`ProductivityScore.swift`**
   - Delete `HourSlot` struct (lines 28-35) if grep confirms zero references.

4. **Update design doc `plans/orbitaccessappdesign.md:270-286`**
   - Change Today's Schedule description from context_events SQL to:
     ```
     CalendarScheduleView — calendar events for today (EventKit, Phase 4C).
     Until connected: shows "No calendar connected" placeholder.
     ```
   - Confirm Context Stream section still documents `context_events` tail.

### Anti-pattern guards

- Do **not** move the deleted SQL into Context Stream — that section already uses `fetchRecentCapturesTail()`.
- Do **not** leave `fetchDailySchedule` "for later" — calendar will use EventKit, not SQLite context_events.

### Verification checklist

```bash
# No schedule data path
rg 'fetchDailySchedule|HourSlot|scheduleSlots|insightStore\.schedule' OrbitAccessApp/

# Context stream still wired
rg 'RecentCaptureList|fetchRecentCaptures' OrbitAccessApp/

# Productivity score still loads
rg 'computeScoreInputs|refreshAggregates' OrbitAccessApp/Stores/InsightStore.swift
```

---

## Phase 3: Calendar stub for future EventKit integration (minimal)

**What to implement:** A thin model + provider stub so Phase 4C can plug in without renaming UI again. Keep this phase small — no EventKit imports.

### Tasks

1. **Add `OrbitAccessApp/Models/CalendarEvent.swift`**
   - Copy shape from dashboard engagement parser (`orbit_dashboard/dashboard.html:635-639`):
     ```swift
     struct CalendarEvent: Identifiable, Sendable {
         let id: String
         let title: String
         let start: Date
         let end: Date
     }
     ```

2. **Add `OrbitAccessApp/Services/CalendarScheduleProvider.swift`**
   - Protocol:
     ```swift
     protocol CalendarScheduleProvider: Sendable {
         var isConnected: Bool { get }
         func todayEvents() async throws -> [CalendarEvent]
     }
     ```
   - Stub implementation:
     ```swift
     struct DisconnectedCalendarProvider: CalendarScheduleProvider {
         var isConnected: Bool { false }
         func todayEvents() async throws -> [CalendarEvent] { [] }
     }
     ```
   - Wire `DisconnectedCalendarProvider` as default on `InsightStore` (or `AppViewModel`) — **do not poll**; no timer needed while disconnected.

3. **Extend `CalendarScheduleView` (from Phase 1)**
   - Accept `events: [CalendarEvent]` and `isConnected: Bool`.
   - When `isConnected && events.isEmpty`: show `"Nothing scheduled today"`.
   - When `!isConnected`: show `"No calendar connected"` (Phase 1 copy).
   - When `isConnected && !events.isEmpty`: render timeline rows with `TimeChip` + title (copy row layout from old `DailyScheduleTimeline.swift:35-44`, but bind `CalendarEvent.title` and formatted start/end — **only implement the connected branch if trivial; stub can stay placeholder-only until 4C**).

4. **Add one-line roadmap comment in provider file**
   - Cite `plans/03-universal-capture.md:308` — EventKit local, Phase 4C.

### Verification checklist

```bash
rg 'CalendarEvent|CalendarScheduleProvider|DisconnectedCalendarProvider' OrbitAccessApp/
rg 'import EventKit' OrbitAccessApp/   # must return zero hits
```

---

## Phase 4: Verification

**What to implement:** Confirm the sidebar no longer mislabels capture as schedule and the app still builds.

### Checklist

1. **Grep anti-patterns**
   ```bash
   bash scripts/grep_antipatterns.sh   # if applicable to Swift scope
   rg 'context_events.*schedule|fetchDailySchedule|No activity recorded today' OrbitAccessApp/
   ```
   Expected: zero hits.

2. **Build**
   ```bash
   cd OrbitAccessApp && xcodebuild -scheme OrbitAccessApp -configuration Debug build CODE_SIGNING_ALLOWED=NO
   ```

3. **Manual UX**
   - [ ] Today's Schedule: "No calendar connected" (with calendar icon).
   - [ ] Context Stream: still lists recent captures when daemon + DB active.
   - [ ] Routines: unchanged (separate section).
   - [ ] Productivity gauge: still updates (unaffected by schedule removal).

4. **Design doc parity**
   - [ ] `plans/orbitaccessappdesign.md` §4.3 describes calendar placeholder, not context_events SQL.

---

## Future work (out of scope — Phase 4C)

When calendar integration ships:

1. Add `EventKitCalendarProvider: CalendarScheduleProvider` using `EKEventStore.requestFullAccessToEvents`.
2. Map `EKEvent` → `CalendarEvent`.
3. Poll or subscribe to `EKEventStoreChanged` (not 30s SQLite polling).
4. Settings UI: "Connect Calendar" toggle + permission prompt.
5. GDPR: document calendar access in privacy policy (`docs/gdpr/`).

See `plans/03-universal-capture.md:308`, `README.md:266`, `innitial.md` calendar roadmap.

---

## Execution order

| Phase | Depends on | Est. effort |
|-------|------------|-------------|
| 1 — UI placeholder | — | Small |
| 2 — Remove data path | 1 | Small |
| 3 — Calendar stub | 1 | Small (optional; can merge with 1) |
| 4 — Verification | 1–3 | Small |

Phases 1 and 2 are the **minimum shippable fix**. Phase 3 is recommended if you want a clean hook for EventKit without another rename pass.

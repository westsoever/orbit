# Orbit Access App — macOS SwiftUI Architecture & Design

> A native macOS frontend for the Orbit context-capture daemon. Three-pane layout,
> Littlebird.ai aesthetic, built modular so new AI functions, panes, and agents drop
> in without breaking the contract.

**Status:** Design document (no Swift code yet). Target build host: macOS 14+ on a Mac.
**Audience:** the macOS developer who will build this in Xcode.
**Backend:** the existing Orbit Python daemon — this app is a frontend over it, never a replacement.

---

## 0. Design principles

1. **The daemon owns the data.** Python captures, embeds, and writes. Swift reads, and writes *only* through the daemon's HTTP bridge (task approvals). Swift never mutates `context_events`, `text_atoms`, or `vec_atoms`.
2. **Offline-tolerant.** If the daemon is down, the app still opens and shows historical context from SQLite; only live search, chat, and task writes are disabled.
3. **Three panes are a contract.** Sidebane | Chat | Insight. New features are added *inside* a pane or as a *new* appended pane — never by restructuring the spine.
4. **Native only.** SwiftUI first, AppKit dropped in surgically (`NSStatusItem`, `NSPopover`, `NSWindow` positioning, `NSOpenPanel`). No web views for primary UI; no third-party UI frameworks.
5. **One dependency.** GRDB.swift for SQLite. Everything else is system frameworks (SwiftUI, AppKit, URLSession, Observation, Combine).

---

## 1. High-level architecture

```
┌──────────────────────────── Orbit Access App (.app) ─────────────────────────────┐
│                                                                                   │
│  MainScene  (NSWindow, hiddenTitleBar)            FloatingChatScene (hudWindow)   │
│  ┌───────────────┬──────────────────────┬──────────────────┐   ┌──────────────┐  │
│  │  SidebaneView │   MainChatView        │ InsightSidebar   │   │ FloatingChat │  │
│  │ (collapsible) │  (chat + spin-off)    │ (tasks/score/…)  │   │  View        │  │
│  └──────┬────────┴──────────┬───────────┴────────┬─────────┘   └──────┬───────┘  │
│         │                   │                     │                    │          │
│  ┌──────▼───────────────────▼─────────────────────▼────────────────────▼───────┐ │
│  │                         AppViewModel  (root @Observable)                     │ │
│  │     ChatStore   │   TaskStore   │   SearchStore   │   InsightStore           │ │
│  └──────────────────────────────────┬──────────────────────────────────────────┘ │
│                                      │                                            │
│  ┌───────────────────────────────────▼──────────────────────────────────────────┐ │
│  │                                IPC layer                                      │ │
│  │  OrbitBridgeClient (actor, URLSession)  │  OrbitDBReader (GRDB, read-only)    │ │
│  │                                          │  WALWatcher (DispatchSource)       │ │
│  └───────────────┬────────────────────────────────────────┬──────────────────────┘ │
│                  │                                          │                       │
│   ┌──────────────▼─────────────┐         AppKit track:  ┌──▼──────────────────────┐ │
│   │ NSStatusItem + NSPopover   │         menu-bar       │  read-only SQLite pool  │ │
│   │ (StatusBarController)      │         presence       │  WAL file watcher       │ │
│   └────────────────────────────┘                        └─────────────────────────┘ │
└──────────────────┬───────────────────────────────────────────┬────────────────────┘
                   │ HTTP 127.0.0.1:8765                          │ file: ~/.orbit/orbit.db (+ -wal)
        ┌──────────▼───────────────┐                  ┌───────────▼──────────────┐
        │  Orbit Python daemon     │  writes (WAL)     │  SQLite database          │
        │  search_hybrid · task_log│ ────────────────► │  context_events, atoms,   │
        │  /api/* (Track B)        │                   │  task_log, vec_atoms, …   │
        └──────────────────────────┘                  └───────────────────────────┘
```

**Two SwiftUI scenes + one AppKit track:**

| Element | Type | Role |
|---|---|---|
| `MainScene` | `WindowGroup` / `Window`, `.windowStyle(.hiddenTitleBar)` | The three-pane main window. Min 900×600, default 1200×740. |
| `FloatingChatScene` | `Window(id: "floating-chat")`, `.windowStyle(.hudWindow)`, `.windowResizability(.contentSize)` | The spun-off chat. Shares `ChatStore` via `@Environment`. |
| `StatusBarController` | `NSStatusItem` + `NSPopover` (AppKit) | Always-on menu-bar dot; popover hosts a mini Insight view via `NSHostingView`. |

App entry:

```swift
@main
struct OrbitAccessApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var model = AppViewModel()          // root @Observable

    var body: some Scene {
        Window("Orbit", id: "main") {
            MainWindowView().environment(model)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1200, height: 740)
        .commands { SidebarCommands() /* + custom toggle commands */ }

        Window("Orbit Chat", id: "floating-chat") {
            FloatingChatView().environment(model)
        }
        .windowStyle(.hudWindow)
        .windowResizability(.contentSize)
    }
}
```

---

## 2. IPC strategy — dual-track (locked)

Swift's bundled `SQLite3` cannot load the `sqlite-vec` extension (it needs the
Homebrew Python build the daemon ships with). So vector/hybrid search and any write
go through the daemon; cheap relational + FTS5 reads happen directly against the file.

### Track A — read-only SQLite (GRDB)

```swift
var config = Configuration()
config.readonly = true
let pool = try DatabasePool(path: orbitDBURL.path, configuration: config)
```

- **Reads:** `context_events`, `text_atoms`, `task_log`, `fs_events`, `capture_audit`.
- **Lexical search:** FTS5 over `atoms_fts` — `unicode61` tokenizer, built into system SQLite, no extension needed.
- **Why a `DatabasePool` (not `DatabaseQueue`):** WAL mode allows concurrent readers while Python writes; a pool gives parallel read connections with snapshot isolation.
- **Liveness:** `WALWatcher` observes `orbit.db-wal` via `DispatchSource.makeFileSystemObjectSource(eventMask: [.write, .extend])`. On change, stores do an **incremental** fetch (`WHERE id > lastSeenId`) rather than a full reload.

### Track B — extended HTTP bridge (URLSession)

Anything needing `sqlite-vec` or a write. Additive routes on the existing
`127.0.0.1:8765` server (see Appendix §10 — not implemented in this task):

| Method · Path | Purpose | Backed by |
|---|---|---|
| `GET /api/status` | Daemon alive + capture active | daemon state |
| `GET /api/tasks/pending` | Today's detected tasks | `get_pending_today()` |
| `POST /api/task/{id}/approve` | Approve + dispatch | `update_status(…, "approved", approved_prompt)` |
| `POST /api/task/{id}/skip` | Skip a task | `update_status(…, "skipped")` |
| `GET /api/search?q=&limit=` | Hybrid (vec+FTS) search | `search_hybrid(con, q, limit)` |
| `POST /api/chat` | NL query → search + LLM, **SSE stream** | `search_hybrid` + `orbit.check.llm` |

Client is an `actor` so concurrent stores can't race its connection state:

```swift
actor OrbitBridgeClient: OrbitBridgeProtocol {
    private let base = URL(string: "http://127.0.0.1:8765")!
    private let session = URLSession(configuration: .ephemeral)
    private(set) var isDaemonAlive = false

    func checkStatus() async -> Bool { … }            // GET /api/status
    func fetchPendingTasks() async -> [TaskLogEntry] { … }
    func approve(id: Int64, prompt: String) async throws { … }
    func skip(id: Int64) async throws { … }
    func search(_ q: String, limit: Int = 20) async -> [SearchHit] { … }
    func chatStream(_ q: String) -> AsyncThrowingStream<ChatChunk, Error> { … }  // SSE
}
```

### Offline fallback

`checkStatus()` failure (connection refused / 503) → app enters **read-only mode**:
- A "Daemon offline" badge renders in the Sidebane (`DaemonStatusIndicator` red).
- Approve/Skip buttons disable; the chat input shows "Start `orbit start` to enable search & chat".
- Historical browsing (timeline, recent captures, lexical search) keeps working via Track A.
- A 5s status poll auto-restores full mode when the daemon returns.

---

## 3. Component breakdown — responsibilities

| Component | Layer | Single responsibility | In | Out |
|---|---|---|---|---|
| `OrbitBridgeClient` | IPC | All HTTP I/O with the daemon | queries, task IDs | `[SearchHit]`, `[TaskLogEntry]`, SSE chunks |
| `OrbitDBReader` | IPC | All read-only SQL (relational + FTS5 + score queries) | SQL params | model rows, aggregates |
| `WALWatcher` | IPC | Detect daemon writes, fire change callback | db path | `onChange()` ticks |
| `ChatStore` | Store | Chat history + streaming state | user query | `messages`, `isStreaming` |
| `TaskStore` | Store | Pending tasks, approve/skip, polling | bridge client | `pendingTasks` |
| `SearchStore` | Store | Search results, mode (lexical/hybrid) | query | `hits` |
| `InsightStore` | Store | Score, schedule, routines, recent captures | db reader | score, timeline, routines |
| `AppViewModel` | Root | Owns the four stores, daemon-mode flag, DI | — | environment object |
| `ThreePaneLayout` | View | Lay out ordered panes; own collapse widths | `[PaneDescriptor]` | the spine |
| `StatusBarController` | AppKit | Menu-bar dot + popover lifecycle | score, task count | clicks → open main window |
| `AIFunctionRegistry` | Ext | Hold registered Sidebane functions | `register(_:)` | functions grouped by section |

---

## 4. Detailed UI layout — per pane

### 4.1 Left "Sidebane" — collapsible AI function palette

Fixed **220 pt** when expanded; collapses to **0** (content clipped, divider snaps).

```
SidebaneView
├─ SidePaneSectionHeader("SEARCH")
│  ├─ SidePaneSearchTrigger("Semantic Search", "magnifyingglass")
│  ├─ SidePaneSearchTrigger("Find by App",     "app.badge")
│  └─ SidePaneSearchTrigger("Find by Time",    "clock")
├─ SidePaneSectionHeader("AGENTS")
│  ├─ AgentShortcutRow(.writing)   ├─ AgentShortcutRow(.research)
│  ├─ AgentShortcutRow(.code)      └─ AgentShortcutRow(.admin)
├─ SidePaneSectionHeader("CAPTURE")
│  ├─ DaemonStatusIndicator()        // live green/red dot, polls /api/status
│  └─ CaptureStatsView()             // atoms captured today (Track A COUNT)
└─ SidePaneSectionHeader("PRIVACY")
   └─ PrivacyPolicyLink()            // opens docs/gdpr/PRIVACY_POLICY.md
```

**Collapse mechanics**

```swift
@AppStorage("sidebaneVisible") private var sidebaneVisible = true

SidebaneView()
    .frame(width: sidebaneVisible ? 220 : 0)
    .opacity(sidebaneVisible ? 1 : 0)
    .clipped()
    .animation(.spring(response: 0.3, dampingFraction: 0.85), value: sidebaneVisible)
```

Toggled by a toolbar button **and** `⌘\`:

```swift
Button { sidebaneVisible.toggle() } label: { Image(systemName: "sidebar.left") }
    .keyboardShortcut("\\", modifiers: .command)
```

- `AgentShortcutRow` — a `Button` that pre-fills the chat input with a typed
  template (e.g. tapping *Research* inserts `"Research: "` and focuses the field
  via `@FocusState`). It does **not** dispatch an agent directly — the chat card
  remains the single point of NL interaction.
- `DaemonStatusIndicator` — `@MainActor` 5 s poll; green `Circle` + "Daemon running",
  red + "Daemon offline".

### 4.2 Center — Main Chat Card

```
MainChatView
├─ ChatMessageList                       // ScrollView + LazyVStack, autoscroll to last
│  └─ ForEach(messages) { ChatBubbleView(message:) }
│        • user      → trailing, accent fill
│        • assistant → leading,  .regularMaterial, + ContextSourceChip row
└─ ChatInputBar
   ├─ TextField("Ask Orbit anything…", text:$input, axis:.vertical).lineLimit(1...6)
   ├─ SendButton          // ⏎  → ChatStore.send()
   └─ SpinOffButton       // "rectangle.on.rectangle"  → pop out
```

- **Citations:** each assistant message carries `sourceAtoms: [SearchHit]`. Rendered
  as `ContextSourceChip` pills (`app_name` · `window_title`). Tapping opens
  `ContextAtomDetailSheet` (`.sheet`) with the full atom text + timestamp + a link
  to the source event.
- **Streaming:** `ChatStore.send()` calls `POST /api/chat` and consumes the SSE
  `AsyncThrowingStream`, appending text deltas live; the `sources` event populates chips.

**Spin-off mechanic**

```swift
@Environment(\.openWindow) private var openWindow
@AppStorage("chatIsFloating") private var chatIsFloating = false

SpinOffButton { chatIsFloating = true; openWindow(id: "floating-chat") }
```

- `FloatingChatView` is the same view tree bound to the *same* `ChatStore` (shared
  via `.environment(model)`), so history is continuous.
- Window opens at the main window's screen origin — an `AppDelegate` hook sets
  `NSWindow.setFrameOrigin(_:)` on the new window to match (`hudWindow` floats above others).
- While floated, the center column of the main window shows
  `FloatingChatPlaceholderView` with a **"Return to main window"** button that
  closes the float and resets `chatIsFloating`.

### 4.3 Right — "Insight Sidebar"

Default **280 pt**, **also collapsible** (per the execution checklist) via
`@AppStorage("insightVisible")` and `⌘⌥\`, same spring animation as the Sidebane.

```
InsightSidebarView
├─ ProductivityScoreGauge(score:)         // Canvas arc, color-thresholded (§6)
├─ SectionHeader("RECOMMENDED TASKS")
│  └─ TaskCardList { ForEach(pendingTasks) { TaskCard(task:) } }
│        ├─ header: title + AgentTypeBadge
│        ├─ body:   description (truncated, tap to expand)
│        └─ actions: ApproveButton · SkipButton
├─ SectionHeader("TODAY'S SCHEDULE")
│  └─ CalendarScheduleView                 // calendar events for today (EventKit, Phase 4C)
├─ SectionHeader("ROUTINES")
│  └─ RoutineList                          // user-configured recurring blocks
└─ SectionHeader("CONTEXT STREAM")
   └─ RecentCaptureList                     // last 10 events, live via WALWatcher
```

- **`TaskCard`** — `OrbitCard` with a left accent bar colored by agent type. **Approve** → `POST /api/task/{id}/approve` (body `{"approved_prompt": …}`); on success the card animates out (`.move(edge: .trailing).combined(with: .opacity)`). **Skip** → `/skip`. Both disabled in offline mode.
- **`CalendarScheduleView`** — calendar events for today (EventKit, Phase 4C). Until connected: shows "No calendar connected" placeholder.
- **`RecentCaptureList`** — incremental tail (`id > lastSeenId`) refreshed by the WAL watcher.

---

## 5. Data layer

### 5.1 Swift models (columns verified against `orbit/storage/schema.sql`)

```swift
import GRDB

struct ContextEvent: Codable, FetchableRecord, Identifiable {
    let id: Int64
    let timestamp: String
    let appBundleId: String?       // app_bundle_id
    let appName: String?           // app_name
    let windowTitle: String?       // window_title
    let focusedElementRole: String?
    let focusedElementLabel: String?
    let visibleText: String?
    let rawJson: String?
    let captureMethod: String?
    let captureTier: Int?
    let pageUrl: String?
}

struct TextAtom: Codable, FetchableRecord, Identifiable {
    let id: Int64
    let eventId: Int64             // event_id
    let role: String
    let label: String?
    let text: String
    let elementPath: String
    let elementHash: String?
}

struct TaskLogEntry: Codable, FetchableRecord, Identifiable {
    let id: Int64
    let timestamp: String
    let title: String?
    let description: String?       // ⚠️ NOT in canonical schema.sql — added via migration.
                                   //    Decode as optional; tolerate absence.
    let originalPrompt: String?
    let approvedPrompt: String?
    let agentType: String?         // writing|research|code|admin|data|communication
    let status: String             // detected|approved|dispatched|skipped
    let exitCode: Int?
}

// Mirrors orbit/search/types.py Hit (field names match exactly).
struct SearchHit: Codable, Identifiable {
    let atomId: Int; let eventId: Int
    let atomUri: String; let eventUri: String
    let appBundleId: String; let appName: String
    let windowTitle: String?; let timestamp: String
    let role: String; let label: String?
    let snippetHtml: String; let score: Double
    var id: Int { atomId }
}

struct ChatMessage: Identifiable {
    let id = UUID()
    let role: MessageRole          // user | assistant | system
    let content: String
    let timestamp: Date
    var sourceAtoms: [SearchHit] = []
}
```

> Map snake_case columns with GRDB's `databaseColumnDecodingStrategy = .convertFromSnakeCase`,
> or explicit `CodingKeys`. `TaskLogEntry.description` must survive a missing column —
> use a tolerant decode (the bridge JSON includes it; direct SQLite may not), so prefer
> reading tasks via Track B `/api/tasks/pending` and reserve Track A for columns known to exist.

### 5.2 Stores (`@Observable`, Observation framework, macOS 14+)

```swift
@Observable final class TaskStore {
    var pendingTasks: [TaskLogEntry] = []
    var isLoading = false
    @ObservationIgnored private var timer: AnyCancellable?

    func startPolling(_ client: OrbitBridgeClient) {
        timer = Timer.publish(every: 5, on: .main, in: .common).autoconnect()
            .sink { _ in Task { await self.refresh(client) } }
    }
    @MainActor func refresh(_ client: OrbitBridgeClient) async {
        pendingTasks = await client.fetchPendingTasks()
    }
}
```

**Refresh cadence**

| Trigger | Cadence | What refreshes |
|---|---|---|
| Task poll | 5 s | `pendingTasks`, daemon status |
| Aggregate poll | 30 s | productivity score, schedule rollups |
| WAL watcher | event-driven | recent-capture tail, atom counts |

### 5.3 Database access bootstrapping (sandbox)

On first launch `OrbitDBReader` looks for a Keychain-stored **security-scoped
bookmark** to `~/.orbit/orbit.db`. If absent, an `NSOpenPanel` pre-set to `~/.orbit/`
asks the user to select `orbit.db`; the URL is bookmarked (`.withSecurityScope`)
and stored in Keychain (not `UserDefaults` — the path contains the home dir).

---

## 6. Productivity score formula

A **0–10** weighted score, computed in Swift from read-only SQL (no vec extension),
recomputed on the 30 s aggregate timer.

```
score = 10 × ( 0.35·taskCompletion
             + 0.25·focusDepth
             + 0.20·contextRichness
             + 0.20·captureConsistency )
```

| Component | Weight | Query (today = `date('now')`) | Normalization |
|---|---|---|---|
| **Task completion** | 0.35 | `SELECT SUM(status IN ('approved','dispatched')) done, SUM(status='detected') pending FROM task_log WHERE date(timestamp)=date('now')` | `done / max(1, done+pending)` |
| **Focus depth** | 0.25 | top app's event share: `MAX(c)/SUM(c)` over `GROUP BY app_bundle_id` | `min(1, topShare / 0.7)` |
| **Context richness** | 0.20 | `SELECT COUNT(*) FROM text_atoms a JOIN context_events e ON e.id=a.event_id WHERE date(e.timestamp)=date('now')` | `min(1, atoms / 500)` |
| **Capture consistency** | 0.20 | `SELECT COUNT(DISTINCT strftime('%H',timestamp)) FROM context_events WHERE date(timestamp)=date('now') AND strftime('%H',timestamp) BETWEEN '09' AND '17'` | `min(1, hours / 8)` |

```swift
func productivityScore(_ c: ScoreInputs) -> Double {
    let raw = 0.35 * c.taskCompletion
            + 0.25 * c.focusDepth
            + 0.20 * c.contextRichness
            + 0.20 * c.captureConsistency
    return (raw * 10).rounded(toPlaces: 1)
}
```

**Color ramp & labels — reused verbatim from `orbit_dashboard/dashboard.html`:**

| Range | Hex | Label |
|---|---|---|
| `< 5` | `#ef4444` red | Needs improvement |
| `< 7` | `#f59e0b` amber | Moderate |
| `< 8.5` | `#84cc16` lime | Good |
| `≥ 8.5` | `#10b981` emerald | Excellent |

---

## 7. Modularity & extensibility

### 7.1 Pane protocol — append, never restructure

```swift
struct PaneDescriptor: Identifiable {
    let id: String
    let position: PanePosition       // .leading | .center | .trailing | .appended
    let preferredWidth: CGFloat
    let isCollapsible: Bool
    let view: AnyView
}

struct ThreePaneLayout: View {
    let panes: [PaneDescriptor]      // ordered; spine = first leading/center/trailing
    // new panes with .appended slot into an HSplitView column without
    // touching the existing three.
}
```

Adding a pane = construct a `PaneDescriptor`, append it, add an `@AppStorage`
visibility flag. The Sidebane | Chat | Insight contract is preserved because the
three core descriptors are always present and always first.

### 7.2 AI function registry — self-registering Sidebane items

```swift
protocol AIFunction: Identifiable {
    var id: String { get }
    var title: String { get }
    var icon: String { get }              // SF Symbol
    var section: SidebaneSection { get }  // .search | .agents | .capture | .privacy
    func execute(_ ctx: AIFunctionContext) async
}

final class AIFunctionRegistry {
    static let shared = AIFunctionRegistry()
    private(set) var functions: [AIFunction] = []
    func register(_ f: AIFunction) { functions.append(f) }
    func grouped() -> [SidebaneSection: [AIFunction]] { … }
}
```

Register in `AppDelegate.applicationDidFinishLaunching`; the item appears under its
declared section automatically. New section? add a `SidebaneSection` case.

### 7.3 Agent types — data-driven cards

```swift
enum AgentType: String, CaseIterable { case writing, research, code, admin, data, communication }
// AgentType+UI.swift: var color & var icon. Adding `.audio` = one case + color/icon;
// TaskCard, AgentTypeBadge, and AgentShortcutRow pick it up with no further change.
```

### 7.4 Swappable IPC transport

Views never import `OrbitBridgeClient`; they depend on `OrbitBridgeProtocol`
injected via `@Environment`. Swapping HTTP for XPC later means a new conformer —
zero view changes.

---

## 8. UI / design system (Littlebird.ai cues)

Mirrors the existing `dashboard.html`: zinc surfaces, uppercase wide-tracked section
headers, rounded cards, soft shadows, indigo accent.

### 8.1 Color palette

| Token | Dark | Light |
|---|---|---|
| Background | `windowBackgroundColor` (adaptive) | `windowBackgroundColor` |
| Card surface | `#1C1C1E` | `#FFFFFF` |
| Card border | `#2C2C2E` | `#E5E5EA` |
| Primary text | `.primary` | `.primary` |
| Secondary text | `#8E8E93` | `#6D6D72` |
| Accent | `#636AFF` (indigo) | `#636AFF` |

**Agent accents:** writing `#4A90E2` · research `#9B59B6` · code `#27AE60` ·
admin `#E67E22` · data `#00B5D8` · communication `#5B73E8`.
**Score ramp:** see §6.

### 8.2 Typography (SF Pro, all system)

| Role | Font | Size · Weight |
|---|---|---|
| Window title | `.headline` | 15 semibold |
| Section header | `.caption` | 11 semibold, **UPPERCASE**, `.tracking(1.2)` |
| Card title | `.body` | 14 medium |
| Card body | `.callout` | 13 regular |
| Chat message | `.body` | 14 regular |
| Metadata / time | `.caption2` | 11 regular |
| Score number | `.system(size: 32, weight: .bold, design: .rounded)` | 32 bold |
| Badge | `.caption2` | 10 medium |

Apply `.kerning(-0.1)` to body/title text for the tighter Littlebird feel.

### 8.3 Spacing & shape tokens

Card padding **12** · card radius **12** · inter-card gap **8** · section-header→card **6** ·
pane horizontal padding **12** · pane top padding **16** · divider `1 pt Divider()` (no drag handle).

### 8.4 Reusable card shell

```swift
struct OrbitCard<Content: View>: View {
    var accent: Color = .clear
    @ViewBuilder var content: () -> Content
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if accent != .clear { accent.frame(width: 3) }   // left accent bar
            content().padding(12)
        }
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(.primary.opacity(0.06), lineWidth: 1))
        .shadow(color: .black.opacity(0.04), radius: 2, y: 1)
    }
}
```

### 8.5 Animations

Pane collapse `.spring(response:0.3, dampingFraction:0.85)` · card insert
`.opacity + .move(edge:.top)` · card dismiss `.move(edge:.trailing)+.opacity` ·
score gauge `.easeInOut(duration:1.0)` · chat message `.opacity` over `0.2 s`.

### 8.6 Menu-bar presence (AppKit drop)

`NSStatusItem` shows `○` idle / `●` capturing / `×` error (matching the Python
status-bar glyphs). Click → `NSPopover` hosting a SwiftUI `StatusBarPopoverView`
(`NSHostingView`) with a mini score gauge, pending-task count, and last-captured
app. (A plain `Menu` can't host the gauge, hence the popover.)

---

## 9. File / module structure

```
OrbitAccessApp/
├─ OrbitAccessApp.xcodeproj
├─ App/
│  ├─ OrbitAccessApp.swift          // @main, scenes
│  ├─ AppDelegate.swift             // NSApplicationDelegate, status bar, fn registration
│  └─ AppViewModel.swift            // root @Observable, owns stores + daemon mode
├─ IPC/
│  ├─ OrbitBridgeProtocol.swift     // transport abstraction
│  ├─ OrbitBridgeClient.swift       // actor, URLSession, SSE
│  ├─ OrbitDBReader.swift           // GRDB read-only pool + all SQL
│  └─ WALWatcher.swift              // DispatchSource on orbit.db-wal
├─ Models/
│  ├─ ContextEvent.swift  TextAtom.swift  TaskLogEntry.swift
│  ├─ SearchHit.swift     ChatMessage.swift
│  ├─ AgentType.swift     AgentType+UI.swift
│  └─ ProductivityScore.swift
├─ Stores/
│  ├─ ChatStore.swift  TaskStore.swift  SearchStore.swift  InsightStore.swift
├─ Views/
│  ├─ Root/        ThreePaneLayout.swift  MainWindowView.swift
│  ├─ SidePane/    SidebaneView.swift  SidePaneSectionHeader.swift
│  │               SidePaneSearchTrigger.swift  AgentShortcutRow.swift
│  │               DaemonStatusIndicator.swift  CaptureStatsView.swift
│  ├─ Chat/        MainChatView.swift  FloatingChatView.swift  ChatMessageList.swift
│  │               ChatBubbleView.swift  ChatInputBar.swift  ContextSourceChip.swift
│  │               ContextAtomDetailSheet.swift  FloatingChatPlaceholderView.swift
│  ├─ InsightSidebar/  InsightSidebarView.swift  ProductivityScoreGauge.swift
│  │                   TaskCard.swift  TaskCardList.swift  CalendarScheduleView.swift
│  │                   RoutineList.swift  RecentCaptureList.swift
│  ├─ StatusBar/   StatusBarController.swift  StatusBarPopoverView.swift
│  └─ Components/   OrbitCard.swift  SectionHeader.swift  AgentTypeBadge.swift
│                   TimeChip.swift  LoadingIndicator.swift
├─ AIFunctions/    AIFunctionProtocol.swift  AIFunctionRegistry.swift
│                  SemanticSearchFunction.swift  FindByAppFunction.swift
│                  AgentPromptFunction.swift
├─ Extensions/     Color+Orbit.swift  Double+Rounding.swift  Date+Formatting.swift
└─ Resources/      Assets.xcassets  Localizable.strings
```

**Project settings:** macOS 14.0 target · Swift 5.9+ · App Sandbox **on**.
**Entitlements:** `com.apple.security.network.client` (HTTP bridge) ·
`com.apple.security.files.user-selected.read-only` + security-scoped bookmark to
`orbit.db`. **No** `files.all`.
**SPM dependency (only one):** GRDB.swift `~> 6.0` — `https://github.com/groue/GRDB.swift.git`.

---

## 10. Appendix — Python bridge extension (integration reference, not built here)

The Swift app's Track B needs additive routes on the existing bridge. This is the
integration boundary for a **follow-up task**, not part of this design deliverable.

`orbit/browser_bridge/server.py` today: `start_browser_bridge(event_queue, port=8765)`
with a `BaseHTTPRequestHandler` exposing only `POST /capture` and `GET /health`.

**Minimal additive change:**

1. Pass a DB handle into the bridge:
   ```python
   # daemon.py — one-line change at startup
   start_browser_bridge(event_queue, db_ref=(con, lock), port=port)
   ```
2. In `_BridgeHandler.do_GET` / `do_POST`, branch on `self.path`:
   - `GET  /api/status`            → `{"ok": true, "capture_active": …}`
   - `GET  /api/tasks/pending`     → `get_pending_today(con, lock)` → JSON
   - `POST /api/task/{id}/approve` → `update_status(con, lock, id, "approved", approved_prompt=body["approved_prompt"])`
   - `POST /api/task/{id}/skip`    → `update_status(con, lock, id, "skipped")`
   - `GET  /api/search?q=&limit=`  → serialize `search_hybrid(con, q, limit)` `Hit` fields
   - `POST /api/chat`              → `search_hybrid` + `orbit.check.llm.complete`, stream SSE

Existing `/capture` and `/health` stay untouched; same port; no new server.

**Function references for the implementer:**
`orbit/check/log.py` → `get_pending_today`, `update_status`, `insert_task` ·
`orbit/search/hybrid.py` → `search_hybrid` (returns `Hit` from `orbit/search/types.py`) ·
`orbit/check/llm.py` → completion for `/api/chat`.

---

## Checklist coverage

- ✅ Three panes — §1, §4 (Sidebane | Chat | Insight).
- ✅ Sidebane **and** Insight Sidebar collapsible — §4.1, §4.3.
- ✅ Main chat linked to DB (Track A reads + Track B `/api/chat`) with floating spin-off — §2, §4.2.
- ✅ Insight Sidebar: recommended tasks (clickable Approve), daily schedule, routines, productivity score — §4.3, §6.
- ✅ Modular architecture — pane protocol, function registry, agent enum, swappable IPC — §7.
- ✅ SwiftUI-first with selective AppKit drops (`NSStatusItem`/`NSPopover`/`NSWindow`/`NSOpenPanel`) — §1, §8.6.
- ✅ Models cross-checked against `orbit/storage/schema.sql` (`task_log.description` optional; `Hit` field names) — §5.

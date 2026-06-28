# Plan: Offline-First Orbit Access App

> Make Orbit Access fully usable **without the daemon running** for everything that is already in `~/.orbit/orbit.db`. The daemon remains required only for **live capture**, **hybrid/semantic search**, **AI chat (LLM)**, and **task approve/dispatch** — not for browsing, lexical search, offline context lookup, or viewing pending tasks.

**Scope:** `OrbitAccessApp/` SwiftUI app. No Python daemon changes unless a read-only SQL helper is needed for schema tolerance (prefer Swift-side defensive queries).

**Motivation:** Design principle #2 (`plans/orbitaccessappdesign.md:16`) promises offline-tolerance, but the UI treats `isDaemonOnline == false` as “app is broken” — chat input disabled, pending tasks empty, messaging conflates browse + AI features.

**References:**
- Design offline contract: `plans/orbitaccessappdesign.md:144–152`
- Track A reader: `OrbitAccessApp/IPC/OrbitDBReader.swift`
- Track B bridge: `OrbitAccessApp/IPC/OrbitBridgeClient.swift`, `orbit/browser_bridge/server.py`
- Pending SQL: `orbit/check/log.py:76–101`
- Chat context formatting: `orbit/browser_bridge/server.py:96–106`, `_handle_chat:249–279`
- Prior interactivity fix: `plans/08-fix-chat-interactivity.md`

---

## Phase 0: Documentation Discovery (COMPLETE)

### Sources consulted

| Source | What was read |
|--------|---------------|
| `plans/orbitaccessappdesign.md:13–19, 144–152, 351–354` | Principles, offline mode, task read policy |
| `OrbitAccessApp/App/AppViewModel.swift` | `isDaemonOnline`, `isDatabaseReady`, store wiring |
| `OrbitAccessApp/IPC/OrbitDBReader.swift` | All read methods (FTS5, captures, score) |
| `OrbitAccessApp/IPC/OrbitBridgeClient.swift` | Bridge gating on `checkStatus()` |
| `OrbitAccessApp/Stores/SearchStore.swift` | Hybrid → lexical fallback (already exists) |
| `OrbitAccessApp/Stores/TaskStore.swift` | Bridge-only refresh |
| `OrbitAccessApp/Stores/ChatStore.swift` | Bridge-only `send()` |
| `OrbitAccessApp/Views/Chat/ChatInputBar.swift` | Blanket `.disabled(!isDaemonOnline)` |
| `OrbitAccessApp/Views/InsightSidebar/TaskCard.swift` | Approve/Skip gated on daemon |
| `orbit/check/log.py:76–101` | `get_pending_today` SQL |
| `orbit/search/hybrid.py` | sqlite-vec + MiniLM + RRF (daemon-only) |
| `orbit/browser_bridge/server.py:130–290` | All HTTP endpoints |

### Allowed APIs (verified — copy, do not invent)

**Track A — `OrbitDBReader` (read-only GRDB pool):**

```swift
// OrbitDBReader.swift — existing
func lexicalSearch(_ query: String, limit: Int = 20) throws -> [SearchHit]
func fetchRecentCaptures(afterId:limit:) throws -> [ContextEvent]
func fetchRecentCapturesTail(limit:) throws -> [ContextEvent]
func fetchAtomsByApp(_:limit:) throws -> [SearchHit]
func fetchAtomsByHour(_:limit:) throws -> [SearchHit]
func atomsCapturedToday() throws -> Int
func computeScoreInputs() throws -> ScoreInputs
var isReady: Bool
```

**Track B — `OrbitBridgeProtocol` (requires daemon for writes + hybrid + LLM):**

```swift
func checkStatus() async -> Bool
func search(_ query: String, limit: Int) async -> [SearchHit]      // hybrid
func chatStream(_ query: String) -> AsyncThrowingStream<ChatChunk, Error>
func fetchPendingTasks() async -> [TaskLogEntry]
func approve(id:prompt:) async throws
func skip(id: Int64) async throws
```

**Pending tasks SQL (copy from Python verbatim):**

```sql
SELECT id, title, description, original_prompt, agent_type
FROM task_log
WHERE status = 'detected'
  AND date(timestamp) = ?
```

**Search offline fallback (already implemented — extend, don't rewrite):**

```swift
// SearchStore.swift:60–90
if mode == .hybrid, isDaemonOnline, let bridge { ... }
// else → dbReader.lexicalSearch / fetchAtomsByApp / fetchAtomsByHour
```

**Chat context formatting (copy from bridge):**

```python
# server.py:96–106
f"[{i}] {hit.app_name} — {hit.window_title or 'untitled'}\n{hit.snippet_html}"
```

**Design offline contract (target behavior):**

```markdown
# plans/orbitaccessappdesign.md:144–152
- Historical browsing + lexical search via Track A ✓
- Hybrid search, LLM chat, task writes → daemon only
- Approve/Skip disabled offline; list may still show read-only tasks
```

### Capability matrix (product decision)

| Feature | Offline (DB ready) | Online (daemon) |
|---------|-------------------|-----------------|
| Recent captures / timeline | ✓ Track A | ✓ + WAL live updates |
| Productivity score | ✓ Track A | ✓ |
| Lexical search (FTS5) | ✓ Track A | ✓ (also hybrid via bridge) |
| Hybrid / semantic search | ✗ | ✓ bridge |
| **Offline context chat** (snippets, no LLM) | ✓ **NEW** Track A | ✓ (prefer LLM via bridge) |
| AI chat (LLM answers) | ✗ | ✓ bridge `/api/chat` |
| View pending tasks | ✓ **NEW** Track A | ✓ bridge (preferred when online) |
| Approve / Skip / dispatch | ✗ | ✓ bridge writes |
| New capture / embeddings | ✗ | ✓ daemon workers |
| `capture_active` indicator | ✗ (show "not capturing") | ✓ |

### Anti-patterns to avoid

- Do **not** make Swift DB pool writable — design rule: writes only through bridge (`orbitaccessappdesign.md:15`).
- Do **not** port sqlite-vec + MiniLM to Swift in this plan — hybrid stays daemon-only.
- Do **not** call OpenRouter / LLM from Swift — AI chat stays bridge-only.
- Do **not** use `isDaemonOnline` as a master “disable entire app” flag — split into `isDatabaseReady` (browse) vs `isDaemonOnline` (live/AI).
- Do **not** remove 5s status poll — auto-upgrade to online mode when daemon returns.
- Do **not** invent `ChatStore.submitSuggestion()` — use `prefillInput` + `send()`.
- Do **not** break existing bridge paths when daemon **is** online — online = bridge first, offline = Track A fallback.

---

## Phase 1: Explicit capability model on `AppViewModel`

**What to implement:** Replace implicit “daemon or dead” with typed capabilities views can bind to.

### Tasks

1. **Add computed capabilities on `AppViewModel`** (`AppViewModel.swift`):

   ```swift
   /// Historical data available from ~/.orbit/orbit.db
   var canBrowseContext: Bool { isDatabaseReady && dbReader.isReady }

   /// Hybrid search, LLM chat, capture indicator, task dispatch
   var canUseLiveServices: Bool { isDaemonOnline }

   /// Lexical search + offline snippet chat
   var canSearchLocally: Bool { canBrowseContext }

   /// AI streaming chat via bridge
   var canUseAIChat: Bool { canUseLiveServices }
   ```

2. **Wire `isDatabaseReady` into views** — today it is set but unused in UI. `canBrowseContext` should gate Insight sidebar empty states vs “select orbit.db”.

3. **Extend `AIFunctionContext`** (`AIFunctionProtocol.swift`) — replace unused `isDaemonOnline` with:
   ```swift
   let canBrowseContext: Bool
   let canUseLiveServices: Bool
   ```
   Update `AppViewModel.aiContext()` to pass these.

4. **Update `SemanticSearchFunction`** (if exists) — when `!canUseLiveServices`, call `searchStore.activateSemanticSearch()` but force `mode = .lexical` or pass flag so hybrid is not attempted.

### Documentation references

- State: `AppViewModel.swift:12–14, 36–52`
- Unused flag: grep `isDatabaseReady` in views (zero today)
- Design: `plans/orbitaccessappdesign.md:16`

### Verification checklist

```bash
rg 'canBrowseContext|canUseLiveServices|canUseAIChat' OrbitAccessApp/
rg 'isDatabaseReady' OrbitAccessApp/Views/
cd OrbitAccessApp && swift build
```

### Anti-pattern guards

- Do not add a third polling loop — reuse existing 5s daemon poll.
- Do not rename `isDaemonOnline` — views migrate gradually to capability flags.

---

## Phase 2: Pending tasks from Track A when offline

**What to implement:** Copy `get_pending_today` SQL into `OrbitDBReader`; dual-track `TaskStore.refresh()`.

### Tasks

1. **Add `fetchPendingTasksToday()` to `OrbitDBReader.swift`** — copy SQL from `orbit/check/log.py:84–90`:

   ```swift
   func fetchPendingTasksToday(reportDate: String? = nil) throws -> [TaskLogEntry] {
       let date = reportDate ?? ISO8601DateFormatter().string(from: .now).prefix(10) // or Calendar local YYYY-MM-DD
       return try read { db in
           try TaskLogEntry.fetchAll(db, sql: """
               SELECT id, '' AS timestamp, title, description, original_prompt,
                      NULL AS approved_prompt, agent_type, 'detected' AS status, NULL AS exit_code
               FROM task_log
               WHERE status = 'detected' AND date(timestamp) = ?
               """, arguments: [String(date)])
       }
   }
   ```

   **Schema tolerance:** If `description` column missing on old DBs, catch `DatabaseError` and retry without `description` (mirror bridge `migrate()` tolerance — grep `task_log` schema in `orbit/check/log.py` migrate).

2. **Configure `TaskStore` with `OrbitDBReader`** — copy `SearchStore.configure(bridge:dbReader:)` pattern:

   ```swift
   func configure(bridge: OrbitBridgeProtocol, dbReader: OrbitDBReader)
   ```

   Update `AppViewModel.init()`:
   ```swift
   taskStore.configure(bridge: bridge, dbReader: dbReader)
   ```

3. **Dual-track `TaskStore.refresh()`** — copy bridge-first, DB-fallback pattern from `SearchStore.search`:

   ```swift
   @MainActor
   func refresh(isDaemonOnline: Bool) async {
       isLoading = true
       defer { isLoading = false }
       if isDaemonOnline, let bridge {
           let bridgeTasks = await bridge.fetchPendingTasks()
           if !bridgeTasks.isEmpty || isDaemonOnline {
               pendingTasks = bridgeTasks
               return
           }
       }
       if let dbReader, dbReader.isReady {
           pendingTasks = (try? dbReader.fetchPendingTasksToday()) ?? []
       }
   }
   ```

   When online, prefer bridge (canonical JSON). When offline, show DB snapshot.

4. **Update poll sink** in `TaskStore.startPolling` / `AppViewModel` to pass `isDaemonOnline`.

### Documentation references

- SQL: `orbit/check/log.py:76–101`
- Model: `OrbitAccessApp/Models/TaskLogEntry.swift`
- Bridge shape: `server.py` `_task_to_dict` (no timestamp in bridge JSON — OK for cards)
- Design task policy: `plans/orbitaccessappdesign.md:351–354` (relax: read from Track A offline)

### Verification checklist

Manual:
- Daemon **stopped**, DB bootstrapped, seeded `task_log` row with `status='detected'` today → Insight sidebar shows task card (Approve disabled).
- Daemon **started** → same tasks via bridge; approve works.

```bash
rg 'fetchPendingTasksToday' OrbitAccessApp/
cd OrbitAccessApp && swift build
```

### Anti-pattern guards

- Do not implement approve/skip via direct SQL — stays bridge-only.
- Do not poll task_log every 5s when offline unless needed — refresh on timer is fine (read-only).

---

## Phase 3: Search — offline-first UX

**What to implement:** Search always works when DB is ready; show clear degraded-mode indicator when hybrid unavailable.

### Tasks

1. **Refactor `SearchStore.search`** — change signature to use capabilities:

   ```swift
   func search(canUseLiveServices: Bool, canSearchLocally: Bool) async
   ```

   Logic (copy existing flow, reorder messaging):
   - If `!canSearchLocally` → error: "Select orbit.db to search."
   - If `canUseLiveServices && mode == .hybrid` → try `bridge.search`; if non-empty, set `searchTier = .hybrid` and return.
   - Fall through to Track A lexical paths (existing lines 76–90).
   - Set `searchTier = .lexical` on DB path.

2. **Add `SearchStore.searchTier` enum** for UI badge:

   ```swift
   enum SearchTier: Sendable { case none, lexical, hybrid }
   var searchTier: SearchTier = .none
   ```

3. **Update `SidebaneSearchPanel.swift`** — remove any implied daemon requirement from placeholder text. Show caption when `searchTier == .lexical && !canUseLiveServices`: *"Keyword search (start daemon for semantic search)."*

4. **Update `SidebaneSearchPanel` call site** — pass `model.canUseLiveServices` / `model.canSearchLocally` instead of raw `isDaemonOnline`.

5. **`SemanticSearchFunction`** — if `!canUseLiveServices`, set `mode = .lexical` before activating panel (consume `AIFunctionContext` from Phase 1).

### Documentation references

- Fallback: `SearchStore.swift:47–95`
- Panel: `SidebaneSearchPanel.swift:52`

### Verification checklist

| Scenario | Expected |
|----------|----------|
| DB ready, daemon off, query "meeting" | Lexical hits or "No matches" |
| DB ready, daemon on, hybrid mode | Hybrid hits when embeddings exist |
| No DB | Clear error, no crash |

```bash
rg 'searchTier|canSearchLocally' OrbitAccessApp/
swift build
```

### Anti-pattern guards

- Do not disable search TextField when daemon offline — only hybrid tier unavailable.

---

## Phase 4: Offline context chat (Track A)

**What to implement:** Chat works offline by searching local FTS5 and returning formatted snippets — no LLM. Online path unchanged (bridge SSE).

### Tasks

1. **Configure `ChatStore` with `OrbitDBReader`**:

   ```swift
   func configure(bridge: OrbitBridgeProtocol, dbReader: OrbitDBReader)
   ```

2. **Add offline send path in `ChatStore`** — copy context formatting from `server.py:96–106`:

   ```swift
   @MainActor
   private func sendOffline(query: String, dbReader: OrbitDBReader) async {
       // append user message (same as send(bridge:))
       let hits = (try? dbReader.lexicalSearch(query, limit: 8)) ?? []
       let body: String
       if hits.isEmpty {
           body = "No matching context found in your local history. Start the daemon to capture new activity or try different keywords."
       } else {
           body = formatOfflineContext(hits) + "\n\n_(Offline mode — keyword matches only. Start the daemon for AI answers.)_"
       }
       // append assistant message with sourceAtoms = hits
   }

   private func formatOfflineContext(_ hits: [SearchHit]) -> String {
       hits.enumerated().map { i, hit in
           "[\(i+1)] \(hit.appName) — \(hit.windowTitle ?? "untitled")\n\(hit.snippetHtml)"
       }.joined(separator: "\n\n")
   }
   ```

3. **Branch in `ChatStore.send()`**:

   ```swift
   @MainActor
   func send(canUseAIChat: Bool, canSearchLocally: Bool) async {
       guard let bridge else { return }
       let query = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
       guard !query.isEmpty else { return }
       if canUseAIChat {
           await send(bridge: bridge)  // existing SSE path
       } else if canSearchLocally, let dbReader {
           await sendOffline(query: query, dbReader: dbReader)
       } else {
           errorMessage = "Select orbit.db or start the daemon to chat."
       }
   }
   ```

4. **Update `ChatInputBar.swift`** — copy gating from plan, replace blanket disable:

   ```swift
   // REMOVE: .disabled(!model.isDaemonOnline)

   private var canType: Bool {
       model.canBrowseContext || model.canUseLiveServices
   }
   private var canSend: Bool {
       !model.chatStore.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
       && !model.chatStore.isStreaming
       && (model.canUseAIChat || model.canSearchLocally)
   }
   private var placeholderText: String {
       if !model.canBrowseContext { return "Select orbit.db to load context…" }
       if model.canUseAIChat { return "Ask Orbit anything…" }
       return "Search your context (offline — start daemon for AI answers)…"
   }
   ```

   Apply `.disabled(!canType)` to TextField only when DB not ready.

5. **Update `sendMessage()`** to pass capabilities:

   ```swift
   Task { await model.chatStore.send(canUseAIChat: model.canUseAIChat, canSearchLocally: model.canSearchLocally) }
   ```

6. **Optional:** Add subtle badge in `MainChatView` when `canBrowseContext && !canUseAIChat`: *"Offline mode"* chip near input.

### Documentation references

- Online SSE: `ChatStore.swift:37–65`, `OrbitBridgeClient.chatStream`
- Context format: `server.py:96–106`
- Input bar: `ChatInputBar.swift:11–141`
- Design: chat disabled offline → **relax to offline snippet mode**

### Verification checklist

| Scenario | Expected |
|----------|----------|
| DB ready, daemon off, send query | User bubble + assistant snippet list with source chips |
| DB ready, daemon on, send query | Streaming AI answer via SSE |
| No DB | Input disabled; placeholder prompts DB selection |
| Suggestion chips offline | Prefill + send works (offline path) |

```bash
rg 'sendOffline|canUseAIChat|formatOfflineContext' OrbitAccessApp/
swift build
```

### Anti-pattern guards

- Do not import Python or call OpenRouter from Swift.
- Do not block `prefillInput` / `requestFocus` — already local.
- Guard `chatStream` with `canUseAIChat` at store level (defense in depth).

---

## Phase 5: UI messaging & per-feature gating

**What to implement:** Every pane communicates what works offline vs what needs daemon — no global “app is dead” messaging.

### Tasks

1. **`TaskCard.swift`** — change disable condition:

   ```swift
   .disabled(!model.canUseLiveServices)
   .help(model.canUseLiveServices ? "Approve task" : "Start daemon to approve")
   ```

   Show read-only tasks when offline (Phase 2).

2. **`DaemonStatusIndicator.swift`** — split messaging:
   - DB not ready → "Select orbit.db"
   - DB ready, daemon off → "Daemon stopped — browsing saved context" + **Start** button
   - Daemon on → existing green/capture states

3. **`ChatSuggestionChips.swift`** — no change required if Phase 4 unblocks input; verify chips call `send` path after prefill.

4. **`StatusBarController` / `StatusBarPopoverView`** — menu-bar glyph:
   - `canBrowseContext && !canUseLiveServices` → `◐` (browse-only) instead of `×` (broken)
   - `!canBrowseContext` → `×`
   - Online → existing ○/●

5. **Update `ISSUE_REPORT.md`** — add fixed item under Offline mode.

6. **Update design doc** (`plans/orbitaccessappdesign.md:144–152`) — one paragraph clarifying offline chat (snippet mode) and Track A pending tasks.

### Documentation references

- Task card: `TaskCard.swift:53–66`
- Daemon UI: `DaemonStatusIndicator.swift`
- Status bar: `StatusBarController.swift:48`

### Verification checklist

Manual copy audit — grep for misleading strings:

```bash
rg 'Start `orbit start` to enable search & chat' OrbitAccessApp/
# Expect: zero matches (replaced with precise offline/online messages)
rg 'canBrowseContext|canUseLiveServices' OrbitAccessApp/Views/
```

### Anti-pattern guards

- Do not hide Insight sidebar when daemon offline.
- Do not auto-start daemon without user action (keep Start button; run script auto-start is separate).

---

## Phase 6: Verification

**What to implement:** Prove offline-first behavior end-to-end.

### Acceptance criteria

> With daemon **stopped** and `~/.orbit/orbit.db` bootstrapped: user can browse recent captures, run lexical search, send offline chat queries and see snippet results, view pending tasks (read-only), and use suggestion chips. Approve/Skip and AI streaming chat show clear “needs daemon” state. With daemon **started**, app auto-upgrades to hybrid search + LLM chat + dispatch without restart.

### Tasks

1. **Static checks**

   ```bash
   rg 'isDaemonOnline' OrbitAccessApp/Views/ OrbitAccessApp/Stores/
   # Expect: only status indicators + capability plumbing, NOT ChatInputBar.disabled(isDaemonOnline)

   rg 'fetchPendingTasksToday|sendOffline|canBrowseContext' OrbitAccessApp/
   bash scripts/grep_antipatterns.sh
   ```

2. **Build**

   ```bash
   cd OrbitAccessApp && swift build
   ```

3. **Manual test matrix**

   | # | Setup | Action | Pass |
   |---|-------|--------|------|
   | 1 | DB ✓, daemon ✗ | Open app | Timeline populated, score visible |
   | 2 | DB ✓, daemon ✗ | Search "orbit" | Lexical hits, tier badge "keyword" |
   | 3 | DB ✓, daemon ✗ | Chat "what did I work on" | Snippet answer, source chips |
   | 4 | DB ✓, daemon ✗ | View pending task | Card visible, Approve disabled w/ help |
   | 5 | DB ✓, daemon ✗ → start daemon | Wait 5s | Search/chat upgrade; Approve enables |
   | 6 | DB ✓, daemon ✓ | Chat query | SSE streaming LLM answer |
   | 7 | No DB | Launch | Prompt select orbit.db; no crash |

4. **Regression:** Run `plans/08-fix-chat-interactivity.md` checks — issue overlay still click-through.

### Anti-pattern guards

- Do not commit `*.db`, `.build/`, credentials.
- Do not mark complete without manual offline test (daemon stopped).

---

## Execution order

```
Phase 1 (capabilities)
    → Phase 2 (tasks Track A)
    → Phase 3 (search UX)
    → Phase 4 (offline chat)
    → Phase 5 (UI copy)
    → Phase 6 (verify)
```

Phases 2–4 can run in parallel after Phase 1 if different agents own separate files; Phase 5 depends on 1–4. Each phase is one commit slice.

## Known gaps (out of scope)

| Gap | Reason deferred |
|-----|-----------------|
| Hybrid search in Swift | Requires sqlite-vec + MiniLM — daemon-only |
| LLM chat without daemon | No local LLM in app; would need on-device model project |
| Task approve offline queue | Writes forbidden on Track A; needs sync protocol |
| Browse atoms for apps with no FTS row | Existing capture gaps, not offline infra |

## Copy-ready file touch list

| File | Phases |
|------|--------|
| `App/AppViewModel.swift` | 1, 2 |
| `AIFunctions/AIFunctionProtocol.swift` | 1 |
| `IPC/OrbitDBReader.swift` | 2 |
| `Stores/TaskStore.swift` | 2 |
| `Stores/SearchStore.swift` | 3 |
| `Stores/ChatStore.swift` | 4 |
| `Views/Chat/ChatInputBar.swift` | 4, 5 |
| `Views/Chat/MainChatView.swift` | 4 (optional badge) |
| `Views/SidePane/SidebaneSearchPanel.swift` | 3 |
| `Views/InsightSidebar/TaskCard.swift` | 5 |
| `Views/SidePane/DaemonStatusIndicator.swift` | 5 |
| `Views/StatusBar/StatusBarController.swift` | 5 |
| `OrbitAccessApp/ISSUE_REPORT.md` | 5 |
| `plans/orbitaccessappdesign.md` | 5 (offline paragraph) |

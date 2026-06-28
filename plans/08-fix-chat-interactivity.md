# Plan: Fix Main Chat Interface Interactivity

> The Orbit Access App main window feels dead: chat input won't accept messages, buttons don't respond, and agents can't be dispatched. This plan restores click-through and chat/agent flows in the **center pane** (`MainChatView`) and removes window-level hit-test blockers that affect the whole UI.

**Scope:** `OrbitAccessApp/` SwiftUI app + `scripts/run_orbit_access_app.sh` daemon bootstrap. No Python bridge API changes unless status polling is broken.

**Out of scope:** React/Electron Kanban (Phase 2 roadmap), real MCP OAuth in `ChatIntegrationsStrip`, attach-button wiring.

---

## Phase 0: Documentation Discovery (COMPLETE)

### Sources consulted

| Source | What was read |
|--------|---------------|
| `OrbitAccessApp/Views/Root/MainWindowView.swift` | ZStack overlay for issue notifications |
| `OrbitAccessApp/Views/Components/OrbitIssueNotificationPanel.swift` | Notification host animation |
| `OrbitAccessApp/Views/Chat/MainChatView.swift` | Landing vs conversation layout |
| `OrbitAccessApp/Views/Chat/ChatInputBar.swift` | Input binding, send, daemon gating |
| `OrbitAccessApp/Views/Chat/ChatSuggestionChips.swift` | Chip → `prefillInput` + `requestFocus` |
| `OrbitAccessApp/Stores/ChatStore.swift` | `send()`, SSE streaming |
| `OrbitAccessApp/App/AppViewModel.swift` | `isDaemonOnline`, `seriousIssue` |
| `OrbitAccessApp/IPC/OrbitBridgeClient.swift` | `GET /api/status`, `POST /api/chat` |
| `OrbitAccessApp/AIFunctions/AgentPromptFunction.swift` | Agent sidebar = prefill only |
| `OrbitAccessApp/Views/InsightSidebar/TaskCard.swift` | Approve/skip dispatch |
| `orbit/browser_bridge/server.py:130–160` | `/health`, `/api/status` handlers |
| `scripts/run_orbit_access_app.sh` | Launch script (daemon auto-start removed in working tree) |
| `plans/05-bottom-left-issue-notifications.md:190–203` | Intended ZStack pattern (no infinite frame) |
| `plans/07-littlebird-chat-redesign.md:45–68` | Chat binding + gating contract |

### Allowed APIs (verified — do not invent)

**Chat input & send (copy these patterns verbatim):**

```swift
// ChatInputBar.swift — TextField binding
TextField(placeholderText, text: Bindable(model.chatStore).inputText, axis: .vertical)
    .focused($isFocused)
    .disabled(!model.isDaemonOnline)
    .onSubmit { sendMessage() }

// Send guard
private var canSend: Bool {
    model.isDaemonOnline
        && !model.chatStore.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        && !model.chatStore.isStreaming
}
private func sendMessage() {
    guard canSend else { return }
    Task { await model.chatStore.send() }
}

// ChatStore.send() — OrbitAccessApp/Stores/ChatStore.swift:37–65
// Bridge SSE — OrbitBridgeClient.chatStream(_:) :74–104
```

**Suggestion / agent prefill (no daemon required for typing):**

```swift
// ChatSuggestionChips.swift:52–54
model.chatStore.prefillInput(text)
model.chatStore.requestFocus()

// AgentPromptFunction.swift:11–14
context.prefillChat("\(agentType.displayName): ")
```

**Task dispatch (requires daemon):**

```swift
// TaskCard.swift — Approve → POST /api/task/{id}/approve
Task { await model.taskStore.approve(task: task) }
```

**Issue overlay (intended layout from plan 05):**

```swift
ZStack(alignment: .bottomLeading) {
    ThreePaneLayout(...) { ... }
    if let issue = model.seriousIssue {
        OrbitIssueNotificationHost(issue: issue) { ... }
            .padding(.leading, 16)
            .padding(.bottom, 16)
    }
}
```

**Daemon bootstrap (committed script pattern):**

```bash
# scripts/run_orbit_access_app.sh — ensure_daemon()
curl -sf http://127.0.0.1:8765/health
orbit start --no-embed --db ~/.orbit/orbit.db   # background if health fails
```

**Status polling:**

```swift
// AppViewModel.pollDaemonStatus() → bridge.checkStatus()
// OrbitBridgeClient → GET http://127.0.0.1:8765/api/status
```

### Root-cause matrix

| Symptom | Likely cause | Evidence |
|---------|--------------|----------|
| **Nothing clickable** (toolbar, sidebar, chat) | Full-window invisible hit target on issue overlay | `MainWindowView.swift:52–58` applies `.frame(maxWidth: .infinity, maxHeight: .infinity)` to `OrbitIssueNotificationHost`. Plan 05 explicitly avoids this (`plans/05-bottom-left-issue-notifications.md:190–203`). SwiftUI ZStack children with infinite frame intercept all clicks in transparent areas. |
| **Chat input greyed out, send dead** | Daemon offline (`isDaemonOnline == false`) | `ChatInputBar.swift:23, 129–131`. Working tree removed `ensure_daemon()` from run script. |
| **Agents menu "does nothing"** | Expectation mismatch OR overlay blocker | `AgentPromptFunction` only prefills chat (`AgentPromptFunction.swift:11–14`); real dispatch is TaskCard Approve. Overlay blocker prevents menu clicks entirely. |
| **Suggestion chips tap but can't type/send** | Daemon offline disables TextField | Chips call `prefillInput` but field stays `.disabled(!model.isDaemonOnline)`. |
| **Attach (+) never works** | Intentional stub | `ChatInputBar.swift:72–82` — `.disabled(true)`, not a bug. |

### Anti-patterns to avoid

- Do **not** use `.frame(maxWidth: .infinity, maxHeight: .infinity)` on overlay siblings in a ZStack — use `ZStack(alignment: .bottomLeading)` and pad the panel only.
- Do **not** add `allowsHitTesting(false)` to the entire chat column — only decorative strips (`ChatIntegrationsStrip` already uses it locally).
- Do **not** invent new bridge endpoints — use existing `/api/status`, `/api/chat`, `/health`.
- Do **not** remove daemon gating on **send** without product sign-off — chat answers require bridge SSE.
- Do **not** wire agent dropdown to task dispatch — copy `AgentPromptFunction` prefill pattern; dispatch stays on `TaskCard`.
- Do **not** reintroduce the removed top status banner (`plans/05-bottom-left-issue-notifications.md`).

---

## Phase 1: Remove full-window hit-test blocker

**What to implement:** Fix `MainWindowView` so the issue notification panel does not steal clicks from the three-pane layout and chat column.

### Tasks

1. **Edit `OrbitAccessApp/Views/Root/MainWindowView.swift`** — copy layout from `plans/05-bottom-left-issue-notifications.md:190–203`:
   - Change root `ZStack` to `ZStack(alignment: .bottomLeading)`.
   - **Remove** `.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)` from `OrbitIssueNotificationHost`.
   - Keep `.padding(.leading, 16)` and `.padding(.bottom, 16)` on the host only.

2. **Harden `OrbitIssueNotificationHost`** (`OrbitIssueNotificationPanel.swift:25–46`):
   - Wrap panel content so only the card receives hits:
     ```swift
     OrbitIssueNotificationPanel(...)
         .frame(maxWidth: 320)
         // no infinite frame on this view
     ```
   - Optional safety: if a container must fill space for animation, add `.allowsHitTesting(false)` on the container and `.allowsHitTesting(true)` on `OrbitIssueNotificationPanel` only.

### Documentation references

- Buggy implementation: `MainWindowView.swift:10–59`
- Intended pattern: `plans/05-bottom-left-issue-notifications.md:190–203`
- Panel max width: `OrbitIssueNotificationPanel.swift:33` (`maxWidth: 320`)

### Verification checklist

Manual (requires stale bookmark or simulate `seriousIssue` in preview):

| Action | Expected |
|--------|----------|
| Trigger `seriousIssue` (stale DB bookmark) | Bottom-left panel visible |
| Click chat TextField | Focus works |
| Click sidebar Agents menu | Menu opens |
| Click toolbar sidebar toggles | Panes collapse/expand |
| Click "Select orbit.db" on panel | Opens picker |

Static:

```bash
rg 'frame\(maxWidth: \.infinity, maxHeight: \.infinity' OrbitAccessApp/Views/Root/MainWindowView.swift
# Expect: zero matches on OrbitIssueNotificationHost
rg 'ZStack\(alignment: \.bottomLeading\)' OrbitAccessApp/Views/Root/MainWindowView.swift
# Expect: one match
```

Build:

```bash
cd OrbitAccessApp && swift build
```

### Anti-pattern guards

- Do not fix by lowering ZStack overlay z-order with hacks — remove the infinite frame.
- Do not convert issue UI to `.alert` or modal sheet.

---

## Phase 2: Restore daemon connectivity for chat & dispatch

**What to implement:** Re-copy `ensure_daemon()` into `scripts/run_orbit_access_app.sh` so `isDaemonOnline` becomes true after launch, enabling chat send and task approve/skip.

### Tasks

1. **Restore `ensure_daemon()` in `scripts/run_orbit_access_app.sh`** — copy from last committed version (`git show HEAD:scripts/run_orbit_access_app.sh`):
   - Poll `GET http://127.0.0.1:8765/health` (not `/api/status` — both exist; script uses `/health`).
   - If down, background `orbit start --no-embed --db ~/.orbit/orbit.db` with venv activated.
   - Wait up to 10s; warn on stderr if still down (non-fatal — app should still launch).

2. **Sync `ISSUE_REPORT.md` line 8** with script reality after restore (already claims auto-start is fixed).

3. **Verify bridge status path matches app** — app uses `/api/status` (`OrbitBridgeClient.swift:15`); daemon serves both (`server.py:132–136`). No change needed if `/health` passes.

### Documentation references

- Run script (committed): `scripts/run_orbit_access_app.sh` — `ensure_daemon()` block
- Bridge status: `OrbitBridgeClient.swift:13–29`, `server.py:158–160`
- Daemon gating: `ChatInputBar.swift:23, 85–88, 129–131`

### Verification checklist

```bash
# Daemon down → launch script starts it
pkill -f "orbit start" || true
bash scripts/run_orbit_access_app.sh
curl -sf http://127.0.0.1:8765/health && echo OK
curl -sf http://127.0.0.1:8765/api/status && echo OK
```

In app (daemon running):

| UI element | Expected |
|------------|----------|
| Chat placeholder | "Ask Orbit anything…" (not orbit start message) |
| TextField | Enabled, accepts typing |
| Send (↑) | Enabled when text non-empty |
| Side pane `DaemonStatusIndicator` | Green "Daemon running" |
| TaskCard Approve | Enabled |

### Anti-pattern guards

- Do not hard-fail the launch script if daemon slow — `ensure_daemon || true` pattern is intentional.
- Do not switch app polling to `/health` unless `/api/status` is broken — they serve different payloads.

---

## Phase 3: Chat column interaction polish

**What to implement:** Ensure landing-mode chat controls work end-to-end after Phases 1–2; tighten UX edges that feel "broken" when daemon is warming up.

### Tasks

1. **Confirm landing layout wiring** — no code change expected; verify structure matches `plans/07-littlebird-chat-redesign.md`:
   - `MainChatView.landingView` → `ChatInputBar` + `ChatSuggestionChips` (`MainChatView.swift:24–37`)
   - Conversation mode → bottom compact `ChatInputBar` (`MainChatView.swift:40–56`)

2. **Suggestion chips → focus chain** — verify existing pattern works when daemon online:
   - Copy from `ChatSuggestionChips.swift:52–54` + `ChatInputBar.swift:42–47` (`focusRequested` / `@FocusState`).
   - Manual: tap chip → input populated → field focused → Return sends.

3. **Agent dropdown → chat prefill** — verify `AgentsDropdownMenu.swift:19–21` calls `AgentPromptFunction.execute`. Document for user: sidebar agents **prefill** chat; **dispatch** is Insight sidebar Approve on detected tasks.

4. **Optional (only if daemon lag still feels broken):** Allow typing while daemon offline, keep send disabled:
   - Remove `.disabled(!model.isDaemonOnline)` from TextField only (`ChatInputBar.swift:23`).
   - Keep `canSend` daemon check so send stays gated.
   - Update placeholder to clarify: "Start `orbit start` to send messages" vs current combined message.
   - **Skip unless product approves** — default fix is Phase 2 daemon auto-start.

5. **`chatIsFloating` stuck state** — if user closed float window without "Return to main window", center may show `FloatingChatPlaceholderView`. Verify `FloatingChatPlaceholderView.swift:20–22` button resets `@AppStorage("chatIsFloating")`. Reset manually if needed: `defaults delete com.orbit.access chatIsFloating` (confirm bundle ID in `Info.bundle.plist`).

### Documentation references

- Landing layout: `MainChatView.swift:24–37`
- Focus request: `ChatStore.swift:23–28`, `ChatInputBar.swift:42–47`
- Agent prefill: `AgentsDropdownMenu.swift`, `AgentPromptFunction.swift`
- Float placeholder: `FloatingChatPlaceholderView.swift`

### Verification checklist

End-to-end chat smoke test (daemon running):

1. Launch via `bash scripts/run_orbit_access_app.sh`
2. Type "What did I work on today?" → Cmd+Return or send button
3. Confirm streaming assistant bubble (`ChatStore.send` SSE)
4. Tap suggestion chip → input prefilled → send works
5. Agents menu → "Research" → input shows `Research: `
6. Spin-off button → float window opens; main shows placeholder; "Return to main window" restores center chat

```bash
# Static: chat wiring intact
rg 'prefillInput|requestFocus|chatStream|sendMessage' OrbitAccessApp/Views/Chat/
rg 'AgentPromptFunction' OrbitAccessApp/
```

### Anti-pattern guards

- Do not add new `ChatStore` methods — use `prefillInput`, `requestFocus`, `send()`.
- Do not enable send without daemon — SSE requires bridge.

---

## Phase 4: Verification

**What to implement:** Prove interactivity matches acceptance criteria; grep for regressions.

### Acceptance criteria

> From main window center pane, with daemon running: user can type in chat, send a message and receive a streamed reply, tap suggestion chips, use agent prefill from sidebar, and approve a pending task from Insight sidebar. No invisible overlay blocks toolbar or pane clicks when a serious issue notification is shown.

### Tasks

1. **Build & launch**
   ```bash
   cd OrbitAccessApp && swift build
   bash scripts/run_orbit_access_app.sh
   ```

2. **Static anti-pattern sweep**
   ```bash
   bash scripts/grep_antipatterns.sh
   rg 'statusBanner' OrbitAccessApp/          # expect 0
   rg 'frame\(maxWidth: \.infinity, maxHeight: \.infinity' OrbitAccessApp/Views/Root/
   ```

3. **Bridge API smoke** (optional, no UI)
   ```bash
   source .venv/bin/activate
   python scripts/test_bridge_api.py   # if daemon running
   ```

4. **Manual matrix**

   | # | Scenario | Pass condition |
   |---|----------|----------------|
   | 1 | Normal launch, DB OK, daemon auto-started | Chat input enabled; send works |
   | 2 | `seriousIssue` visible (stale bookmark) | Panel bottom-left; rest of window still clickable |
   | 3 | Daemon stopped mid-session | Input disabled; sidebar still clickable; indicator red |
   | 4 | Agent menu → Writing | Chat input prefilled |
   | 5 | Pending task → Approve | `POST /api/task/{id}/approve` (daemon logs or network) |

5. **Update `OrbitAccessApp/ISSUE_REPORT.md`** — add fixed item: "Main window click-through when issue notification visible; chat interactivity when daemon auto-started."

### Anti-pattern guards

- Do not mark complete without manual click test — this bug is hit-testing/UI, not unit-test covered.
- Do not commit `*.db`, `.build/`, or `build/OrbitAccessApp.app`.

---

## Execution order summary

```
Phase 1 (hit-test fix)  →  Phase 2 (daemon auto-start)  →  Phase 3 (chat E2E polish)  →  Phase 4 (verify)
```

Phases 1 and 2 are both required for the reported symptoms. Phase 3 is mostly verification with one optional TextField gating tweak. Each phase is independently committable.

## Known gaps (not blocking this plan)

- Runtime confirmation of invisible overlay on user's machine (plan inferred from code vs `plans/05` spec deviation).
- Whether user has `seriousIssue` active vs daemon-only failure — Phase 4 matrix covers both.
- `AgentShortcutRow.swift` is dead code (superseded by dropdown); delete in separate cleanup.
- Attach button and integrations strip remain non-functional by design (`plans/07-littlebird-chat-redesign.md:305`).

# Plan: Littlebird-Style Central Chat Redesign

> Redesign the **center pane** of Orbit Access App (`MainChatView` and its children) to resemble the Littlebird.ai chat landing experience: warm background, centered hero greeting, card-style composite input, and suggestion chips — while preserving streaming chat, citations, spin-off, and daemon gating.

**Reference screenshot:** `assets/Screenshot_2026-06-28_at_9.37.26_PM-45949ee7-36cc-46bd-9765-a6817381934b.png` (Littlebird.ai, June 28 2026)

**Scope:** Center chat column only. Do **not** redesign Sidebane or Insight Sidebar in this plan.

**Out of scope (defer):** Voice input (mic), LLM model picker ("Max"), real MCP/app OAuth connect flow, web/React Kanban UI.

---

## Phase 0: Documentation Discovery (COMPLETE)

### Sources consulted

| Source | What was read |
|--------|---------------|
| `OrbitAccessApp/Views/Chat/MainChatView.swift` | Current center-pane shell |
| `OrbitAccessApp/Views/Chat/ChatInputBar.swift` | Flat bottom input row |
| `OrbitAccessApp/Views/Chat/ChatMessageList.swift` | Scroll + minimal empty state |
| `OrbitAccessApp/Views/Chat/ChatBubbleView.swift` | Message bubbles + source chips |
| `OrbitAccessApp/Views/Chat/FloatingChatView.swift` | Compact float window |
| `OrbitAccessApp/Stores/ChatStore.swift` | `inputText`, `send()`, `prefillInput()`, `requestFocus()` |
| `OrbitAccessApp/AIFunctions/AIFunctionProtocol.swift` | `AIFunctionContext.prefillChat(_:)` |
| `OrbitAccessApp/Extensions/Color+Orbit.swift` | Existing design tokens |
| `OrbitAccessApp/Views/Components/OrbitCard.swift` | Card shell pattern |
| `OrbitAccessApp/Models/AgentType+UI.swift` | Agent colors + `chatTemplate` |
| `OrbitAccessApp/Stores/TaskStore.swift` | `pendingTasks` for dynamic suggestions |
| `plans/orbitaccessappdesign.md` §4.2, §8 | Authoritative layout + design system |
| `plans/orbitaccessappdesign.md` §4.2 spin-off | Float window contract |

### Allowed APIs (verified — use these, do not invent)

**SwiftUI views (existing, extend in place or compose):**

```swift
// MainChatView.swift — current shell
VStack(spacing: 0) {
    ChatMessageList(...)
    Divider()
    ChatInputBar(showSpinOff: true)
}

// ChatInputBar.swift — binding pattern to preserve
TextField(placeholderText, text: Bindable(model.chatStore).inputText, axis: .vertical)
    .lineLimit(1...6)
    .focused($isFocused)
    .disabled(!model.isDaemonOnline)
    .onSubmit { sendMessage() }

// ChatStore.swift — state + actions
chatStore.inputText          // @Observable bindable
chatStore.prefillInput(_:)    // set text
chatStore.requestFocus()      // triggers @FocusState via onChange
chatStore.send()              // async, clears input, streams SSE
chatStore.messages.isEmpty    // drives landing vs conversation mode
chatStore.isStreaming         // disable send while true
model.isDaemonOnline          // from AppViewModel

// AIFunctionContext — suggestion chip tap
context.prefillChat("Research: ")  // sets input + focus

// Spin-off (must keep working)
@Environment(\.openWindow) private var openWindow
@AppStorage("chatIsFloating") private var chatIsFloating
openWindow(id: "floating-chat")
```

**Design tokens (existing — extend, don't replace):**

| Token | Location | Value |
|-------|----------|-------|
| `Color.orbitAccent` | `Color+Orbit.swift:4` | `#636AFF` |
| `Color.orbitCardLight` | `Color+Orbit.swift:6` | `#FFFFFF` |
| `Color.orbitCardBorderLight` | `Color+Orbit.swift:8` | `#E5E5EA` |
| `Color.orbitSecondaryText(for:)` | `Color+Orbit.swift:24-26` | adaptive gray |
| Card radius / padding | `OrbitCard.swift:20-27` | 12pt radius, 12pt padding |
| Body kerning | `ChatInputBar.swift:20` | `.kerning(-0.1)` |
| Pane collapse spring | `MainWindowView.swift:17` | `(0.3, 0.85)` |

**New token to add (Littlebird warm background):**

| Token | Light | Dark (suggested) |
|-------|-------|------------------|
| `orbitChatBackground` | `#F9F8F3` | `windowBackgroundColor` or `#141414` |

### Anti-patterns to avoid

- Do **not** add React/Electron or web views — native SwiftUI only (`orbitaccessappdesign.md` §0 principle 4).
- Do **not** restructure the three-pane spine — changes stay inside `MainChatView` / `Chat/*` (`orbitaccessappdesign.md` §0 principle 3).
- Do **not** invent `ChatStore` methods like `submitSuggestion()` — use `prefillInput` + `send()` or `prefillChat`.
- Do **not** remove spin-off, SSE streaming, `ContextSourceChip`, or daemon-offline gating.
- Do **not** use third-party UI packages — copy patterns from `OrbitCard.swift` and `FlowLayout` in `ChatBubbleView.swift`.
- Do **not** block the float window with hero/suggestion UI — `FloatingChatView` stays compact.

### Visual target (Littlebird → Orbit mapping)

| Littlebird element | Orbit implementation |
|--------------------|----------------------|
| Warm cream page bg | `orbitChatBackground` on center pane |
| "Got something for me?" | `ChatHeroView` — configurable greeting |
| Date subtitle | `Text(Date.now, format: .dateTime.weekday(.wide).month().day())` |
| Large rounded input card | Refactor `ChatInputBar` → card with white fill + border |
| "Ask Littlebird" placeholder | Keep daemon-aware placeholder from `ChatInputBar.swift:41-45` |
| + attach button | Optional stub `Button` (disabled, tooltip "Coming soon") |
| "Connect your apps…" strip | `ChatIntegrationsStrip` — static placeholder icons + copy |
| Model "Max" dropdown | **Omit** (no multi-model API) |
| Mic button | **Omit** (no voice API) |
| Dark circle send (↑) | Restyle existing send — `arrow.up` in filled near-black circle |
| Suggestion pills below input | `ChatSuggestionChips` — `FlowLayout` or `LazyVGrid` |
| Message thread (when active) | Keep `ChatMessageList` + `ChatBubbleView` |

---

## Phase 1: Design Tokens & Center-Pane Background

### What to implement

1. **Copy** the `Color` hex initializer pattern from `Color+Orbit.swift:17-22`.
2. Add chat-background helpers:

```swift
// Color+Orbit.swift — ADD
static let orbitChatBackgroundLight = Color(hex: 0xF9F8F3)
static let orbitChatBackgroundDark = Color(hex: 0x141414)  // or Color(nsColor: .windowBackgroundColor)

static func orbitChatBackground(for colorScheme: ColorScheme) -> Color {
    colorScheme == .dark ? .orbitChatBackgroundDark : .orbitChatBackgroundLight
}
```

3. Apply background in `MainChatView.swift` only (not whole window):

```swift
.background(Color.orbitChatBackground(for: colorScheme))
```

### Documentation references

- `plans/orbitaccessappdesign.md` §8.1 — extend palette, don't replace accent
- `Color+Orbit.swift` — copy hex init + secondary-text helper pattern

### Verification checklist

- [ ] Light mode center pane is warm off-white (`#F9F8F3`), side panes unchanged
- [ ] Dark mode center pane remains readable (no pure white flash)
- [ ] `swift build` in `OrbitAccessApp/` succeeds (or Xcode build)

### Anti-pattern guards

- Do not change global `NSWindow` background — scope to center pane view tree only.

---

## Phase 2: Landing Hero (Empty-State Layout)

### What to implement

1. **Create** `OrbitAccessApp/Views/Chat/ChatHeroView.swift`:

```swift
struct ChatHeroView: View {
    var greeting: String = "Got something for me?"
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 6) {
            Text(greeting)
                .font(.system(size: 28, weight: .semibold))
                .kerning(-0.3)
            Text(Date.now, format: .dateTime.weekday(.wide).month(.wide).day())
                .font(.subheadline)
                .foregroundStyle(Color.orbitSecondaryText(for: colorScheme))
        }
        .multilineTextAlignment(.center)
    }
}
```

2. **Restructure** `MainChatView.swift` into two modes:

**Landing mode** (`messages.isEmpty && !isStreaming`):

```
VStack {
    Spacer(minLength: 40)
    ChatHeroView()
    Spacer(minLength: 24)
    // input + suggestions inserted in Phase 3–4
    Spacer()
}
.frame(maxWidth: 640)          // centered column like Littlebird
.frame(maxWidth: .infinity)
```

**Conversation mode** (`!messages.isEmpty || isStreaming`):

```
VStack(spacing: 0) {
    ChatMessageList(...)       // existing
    // input at bottom (Phase 3)
}
```

3. **Remove** the old empty-state icon block from `ChatMessageList.swift:37-48` once hero handles landing — list should render nothing when empty in conversation rebuild, or keep a minimal fallback only for float window.

### Documentation references

- `ChatMessageList.swift:37-48` — replace this empty state
- `MainChatView.swift:6-21` — restructure shell
- Littlebird screenshot — hero typography hierarchy

### Verification checklist

- [ ] Fresh launch: hero + date visible, no bubble icon empty state
- [ ] After first message: hero hidden, message list fills space
- [ ] During streaming of first reply: conversation mode (no hero flash)

### Anti-pattern guards

- Do not put hero inside `ScrollView` — it should not scroll away on landing.
- Do not hard-code "Sunday, June 28" — use `Date.now` formatting.

---

## Phase 3: Card-Style Composite Input

### What to implement

Refactor `ChatInputBar.swift` visual structure into a **card** while keeping all logic (`canSend`, `sendMessage`, spin-off, focus, daemon disable).

**Target structure** (copy layout from Littlebird screenshot + `OrbitCard.swift` surface/border):

```
┌─────────────────────────────────────────────┐
│  [TextField multiline — top area]           │
│                                             │
├─────────────────────────────────────────────┤  ← subtle divider
│  [+]   Connect apps strip (Phase 4)   [↗][⬆]│  ← toolbar row
└─────────────────────────────────────────────┘
```

1. Wrap content in white card:

```swift
// Copy surface/border from OrbitCard.swift:20-25
.background(cardSurface, in: RoundedRectangle(cornerRadius: 16))
.overlay(RoundedRectangle(cornerRadius: 16).stroke(cardBorder, lineWidth: 1))
```

Use **16pt** radius on input card (slightly larger than generic `OrbitCard` 12pt — matches Littlebird).

2. **TextField** — top section, min height ~80pt on landing, ~44pt in conversation mode. Pass `isCompact: Bool` param.

3. **Toolbar row** (bottom):
   - Leading: `+` circle button (disabled stub, `.help("Attachments coming soon")`)
   - Center: `ChatIntegrationsStrip()` (Phase 4)
   - Trailing: spin-off (if `showSpinOff`) + send button

4. **Send button restyle** — copy interaction from `ChatInputBar.swift:47-57`, change visuals:

```swift
Image(systemName: "arrow.up")
    .font(.system(size: 14, weight: .semibold))
    .foregroundStyle(.white)
    .frame(width: 32, height: 32)
    .background(canSend ? Color(white: 0.15) : Color.orbitSecondaryText(...), in: Circle())
```

5. **Landing placement:** In `MainChatView` landing mode, input card sits below hero with horizontal padding 24. In conversation mode, pin to bottom (current behavior) with softer or no `Divider()` — use 12pt top padding instead.

6. **`FloatingChatView`:** Pass `isCompact: true`, hide integrations strip and `+` stub; keep send + optional spin-off hidden.

### Documentation references

- `ChatInputBar.swift` — preserve all logic lines 41-84
- `OrbitCard.swift:28-34` — copy surface/border color helpers
- `plans/orbitaccessappdesign.md` §8.3 — spacing tokens (adapt: 16 horizontal padding on landing)

### Verification checklist

- [ ] Multiline input still works (`axis: .vertical`, `lineLimit(1...6)`)
- [ ] ⌘↩ send shortcut still works
- [ ] Daemon offline disables input + shows existing placeholder text
- [ ] Spin-off opens float window; shared history intact
- [ ] Side pane agent prefill still focuses input (`focusRequested` onChange)
- [ ] Card visually matches: white fill, thin border, rounded corners

### Anti-pattern guards

- Do not split send logic into a new store — keep `ChatStore.send()`.
- Do not use `.textFieldStyle(.roundedBorder)` — Littlebird uses borderless inside card.

---

## Phase 4: Integrations Strip & Suggestion Chips

### 4A — Integrations strip (placeholder)

**Create** `OrbitAccessApp/Views/Chat/ChatIntegrationsStrip.swift`:

- Gray caption: "Connect your apps to get better answers"
- Row of SF Symbol stand-ins (Slack → `number`, Notion → `doc.text`, GitHub → `chevron.left.forwardslash.chevron.right`, Calendar → `calendar`) at ~16pt, muted colors
- Entire strip is non-interactive (`allowsHitTesting(false)`) or single disabled button — **no OAuth/MCP wiring in this plan**

Hide when `isCompact == true` (float window).

### 4B — Suggestion chips

**Create** `OrbitAccessApp/Views/Chat/ChatSuggestionChips.swift`:

**Copy** wrapping layout from `ChatBubbleView.swift:58-97` (`FlowLayout`).

Chip visual spec (Littlebird pills):

```swift
Text(label)
    .font(.callout)
    .padding(.horizontal, 14)
    .padding(.vertical, 8)
    .background(Color.orbitCardLight, in: Capsule())
    .overlay(Capsule().stroke(Color.orbitCardBorderLight, lineWidth: 1))
```

**Chip content priority** (max 4 visible + optional "More"):

1. **Dynamic:** Top 2 `TaskStore.pendingTasks` titles (if non-empty) — read via `@Environment(AppViewModel.self)`
2. **Static defaults** (always available as fallback):
   - `"Summarize what I worked on today"`
   - `"Research: "` (uses agent template pattern from `AgentType+UI.swift:27`)
   - `"Draft a status update email"` (Writing agent angle)
   - `"What should I focus on next?"`

**Tap action** — copy from `AIFunctionProtocol.swift:27-30`:

```swift
model.chatStore.prefillInput(text)
model.chatStore.requestFocus()
// Do NOT auto-send — user edits then sends (Littlebird behavior)
```

Show chips only in **landing mode** (`messages.isEmpty && !isStreaming`).

Optional: "More suggestions" chip with `sparkle` SF Symbol toggles expanded static list.

### Documentation references

- `FlowLayout` in `ChatBubbleView.swift:59-97` — reuse (move to `Views/Components/FlowLayout.swift` if needed to avoid duplication)
- `AgentType+UI.swift:27` — `chatTemplate` for agent chips
- `TaskStore.swift:7` — `pendingTasks`
- `AIFunctionContext.prefillChat` — same behavior as chip tap

### Verification checklist

- [ ] Chips render below input on landing, wrap on narrow center pane
- [ ] Chip tap prefills input and focuses — does not send
- [ ] Pending task titles appear when `TaskStore` has items
- [ ] Chips hidden during active conversation
- [ ] Integrations strip visible on main window, hidden in float

### Anti-pattern guards

- Do not call `chatStore.send()` on chip tap.
- Do not fetch new APIs for suggestions — use existing `TaskStore` poll data.

---

## Phase 5: Conversation Mode Polish

### What to implement

1. **Soften transition** landing → conversation: when first message sends, cross-fade hero/chips out (`.opacity` + `.animation(.easeInOut(duration: 0.2))` — matches `ChatMessageList.swift:18`).

2. **Message list padding:** Increase horizontal padding to 20–24 on warm background for readability.

3. **Optional bubble tweak** (minimal): assistant bubbles use white/card surface instead of `.regularMaterial` on light mode for cleaner Littlebird look:

```swift
// ChatBubbleView.swift — assistant branch only, light mode
RoundedRectangle(cornerRadius: 12)
    .fill(colorScheme == .dark ? AnyShapeStyle(.regularMaterial) : AnyShapeStyle(Color.orbitCardLight))
    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.orbitCardBorderLight, lineWidth: colorScheme == .dark ? 0 : 1))
```

4. **Remove hard `Divider()`** between list and input in conversation mode — replace with 8pt spacing + card shadow.

5. **Error strip** (`MainChatView.swift:10-17`): render above input card, styled as red caption (unchanged logic).

### Documentation references

- `plans/orbitaccessappdesign.md` §8.5 — message opacity animation 0.2s
- `ChatBubbleView.swift:28-35` — bubble backgrounds

### Verification checklist

- [ ] Multi-turn conversation scrolls correctly, autoscroll still works
- [ ] Source citation chips still tappable → `ContextAtomDetailSheet`
- [ ] Streaming indicator appears at bottom of list
- [ ] Light-mode assistant bubbles readable on warm background

---

## Phase 6: Floating Chat Parity

### What to implement

Update `FloatingChatView.swift` to use the refactored `ChatInputBar(isCompact: true)`:

- No hero, no suggestion chips, no integrations strip
- Keep `360×480` frame
- Card input at bottom with compact single-line feel

Verify `FloatingChatPlaceholderView` in main window still makes sense visually on warm background (may need one-line copy tweak only).

### Documentation references

- `FloatingChatView.swift:6-13`
- `plans/orbitaccessappdesign.md` §4.2 spin-off mechanic

### Verification checklist

- [ ] Float window: compact input, send works, history shared
- [ ] Main window placeholder visible when floated
- [ ] Return from float restores landing/conversation mode correctly

---

## Phase 7: Verification & Regression

### Build & manual QA

```bash
cd OrbitAccessApp && swift build
# Or: open OrbitAccessApp.xcodeproj and ⌘B
```

**Manual test script:**

1. Launch app with daemon **offline** → landing hero visible, input disabled with placeholder
2. Start `orbit start` → input enables
3. Tap suggestion chip → text prefills, focus in field
4. Send message → hero/chips disappear, stream renders, sources appear
5. Spin off chat → float compact UI; main shows placeholder
6. Toggle light/dark mode → backgrounds and borders adapt
7. Side pane agent shortcut → still prefills chat

### Grep checks (anti-patterns)

```bash
# No web views in chat
rg -n "WKWebView|WebView" OrbitAccessApp/Views/Chat/

# No invented ChatStore APIs
rg -n "submitSuggestion|connectApps|setModel" OrbitAccessApp/

# FlowLayout not duplicated 3+ times (acceptable: 1 component file + usage)
rg -n "struct FlowLayout" OrbitAccessApp/
```

### File checklist (expected new/modified)

| File | Action |
|------|--------|
| `Extensions/Color+Orbit.swift` | Add chat background tokens |
| `Views/Chat/MainChatView.swift` | Landing vs conversation layout |
| `Views/Chat/ChatInputBar.swift` | Card composite input |
| `Views/Chat/ChatHeroView.swift` | **New** |
| `Views/Chat/ChatSuggestionChips.swift` | **New** |
| `Views/Chat/ChatIntegrationsStrip.swift` | **New** |
| `Views/Chat/ChatMessageList.swift` | Remove/replace empty state |
| `Views/Chat/ChatBubbleView.swift` | Optional light-mode bubble |
| `Views/Chat/FloatingChatView.swift` | Compact input flag |
| `Views/Components/FlowLayout.swift` | **Optional** — extract shared layout |
| `OrbitAccessApp.xcodeproj/project.pbxproj` | Register new Swift files |

---

## Execution Order Summary

| Phase | Delivers | Depends on |
|-------|----------|------------|
| 0 | Discovery (done) | — |
| 1 | Warm center-pane background | 0 |
| 2 | Hero greeting + dual layout modes | 1 |
| 3 | Card-style input + send restyle | 2 |
| 4 | Integrations strip + suggestion chips | 3 |
| 5 | Conversation polish + bubble tweak | 3 |
| 6 | Floating chat compact variant | 3 |
| 7 | Build + manual QA | 1–6 |

Each phase is independently shippable; phases 1–3 deliver the core Littlebird resemblance. Phases 4–5 add fidelity. Phase 6–7 ensure parity and no regressions.

---

## Open Questions (resolve before Phase 4 if needed)

1. **Greeting copy:** Keep Littlebird's "Got something for me?" or Orbit-branded "What can I help with?" — default to Littlebird phrase for visual match; one-line change in `ChatHeroView`.
2. **Dark mode warm bg:** Use `#141414` vs system `windowBackgroundColor` — pick one in Phase 1 and stick with it.
3. **FlowLayout extraction:** If moving `FlowLayout` out of `ChatBubbleView.swift`, do it in Phase 4 to avoid duplicate layout code.

# Plan: Sidebane Search & Agents Dropdown Menus

**Goal:** Replace the three stacked Search rows and four stacked Agent rows in the left Sidebane with two compact dropdown menus — one for Search, one for Agents — preserving all existing actions and visual language.

**Status:** Phases 1–4 complete (2026-06-28). Static verification passed; `swift build` green. Manual UI smoke test pending.

**Scope:** `OrbitAccessApp/Views/SidePane/` only. No changes to `SearchStore`, AIFunction executors, or chat prefill logic.

**References:**
- Current wiring: `OrbitAccessApp/Views/SidePane/SidebaneView.swift:9-27`
- Search row styling: `OrbitAccessApp/Views/SidePane/SidePaneSearchTrigger.swift`
- Agent row styling: `OrbitAccessApp/Views/SidePane/AgentShortcutRow.swift`
- Agent colors/icons: `OrbitAccessApp/Models/AgentType+UI.swift`
- Design doc (needs update): `plans/orbitaccessappdesign.md:173-186`, `587-589`
- Screenshot (before): `assets/Screenshot_2026-06-28_at_18.32.25-bde46948-2c86-4ac1-a431-43a34d5465c8.png`

---

## Phase 0: Documentation Discovery (complete)

### Allowed APIs & patterns

| API / pattern | Source | Notes |
|---------------|--------|-------|
| SwiftUI `Menu { … } label: { … }` | [Apple SwiftUI Menu docs](https://developer.apple.com/documentation/swiftui/menu) | Native macOS pulldown; **no existing usage in OrbitAccessApp** — first introduction |
| `Button { … } label: { … }` inside `Menu` | SwiftUI standard | Each menu item fires the same action the current row button fires |
| `SidePaneSearchTrigger` row layout | `SidePaneSearchTrigger.swift:9-26` | Copy HStack, padding, corner radius for dropdown **trigger** label |
| `AgentShortcutRow` tinted background | `AgentShortcutRow.swift:11-25` | Copy per-agent icon color for **menu items** (not trigger) |
| `SemanticSearchFunction().execute(_:)` | `SemanticSearchFunction.swift:10-12` | Unchanged activation path |
| `FindByAppFunction().execute(_:)` | `FindByAppFunction.swift:10-14` | Unchanged activation path |
| `searchStore.activateFindByTime()` | `SearchStore.swift:40-45` | Unchanged activation path |
| `AgentPromptFunction(agentType:).execute(_:)` | `AgentPromptFunction.swift:11-14` | Unchanged prefill path |
| `model.aiContext()` | `AppViewModel.swift` | Pass to all AIFunction executors |
| `SidebaneSearchPanel` conditional | `SidebaneView.swift:10-12` | Keep **above** the Search dropdown; panel still expands inline when a mode activates |

### Anti-patterns to avoid

- Do **not** refactor to `AIFunctionRegistry.grouped()` in this plan — registry is unused by views today; keep hardcoded item lists inside the new dropdown components.
- Do **not** add `data` or `communication` agents to the Agents menu — sidebar currently shows four agents only; scope is consolidation, not expansion.
- Do **not** introduce AppKit `NSMenu` / `NSPopover` — SwiftUI `Menu` is sufficient for sidebar pulldowns.
- Do **not** change search execution, chat prefill, or `SearchStore` mode logic.
- Do **not** remove `SidePaneSearchTrigger` or `AgentShortcutRow` files yet — mark deprecated or leave in tree until a follow-up cleanup confirms zero references.
- Do **not** invent a custom popover dropdown when SwiftUI `Menu` covers the use case.

### Current vs desired layout

| | Current | Desired |
|---|---------|---------|
| SEARCH section | Header + 3 full-width rows | Header + 1 pulldown trigger ("Search") |
| AGENTS section | Header + 4 full-width rows | Header + 1 pulldown trigger ("Agents") |
| Search panel | Inline when `panelActive` | Unchanged — still appears above Search dropdown |
| Actions on pick | Row tap → activate mode / prefill chat | Menu item tap → **same** handlers |
| Vertical space saved | 7 rows | 2 rows (+ optional last-selection label) |

---

## Phase 1: Add reusable dropdown trigger component

**What to implement:** Create `SidePaneDropdownTrigger.swift` — a styled pulldown button matching existing Sidebane row aesthetics.

### Tasks

1. **Create `OrbitAccessApp/Views/SidePane/SidePaneDropdownTrigger.swift`**

   Copy row chrome from `SidePaneSearchTrigger.swift:10-25` and add a trailing chevron:

   ```swift
   import SwiftUI

   struct SidePaneDropdownTrigger<MenuContent: View>: View {
       let title: String
       let icon: String
       var iconColor: Color = Color.orbitAccent
       var backgroundColor: Color = Color.primary.opacity(0.04)
       @ViewBuilder let menuContent: () -> MenuContent

       var body: some View {
           Menu {
               menuContent()
           } label: {
               HStack(spacing: 8) {
                   Image(systemName: icon)
                       .font(.body)
                       .foregroundStyle(iconColor)
                       .frame(width: 20)
                   Text(title)
                       .font(.callout)
                       .foregroundStyle(.primary)
                       .kerning(-0.1)
                   Spacer(minLength: 0)
                   Image(systemName: "chevron.up.chevron.down")
                       .font(.caption2.weight(.semibold))
                       .foregroundStyle(.secondary)
               }
               .padding(.horizontal, 10)
               .padding(.vertical, 8)
               .background(backgroundColor, in: RoundedRectangle(cornerRadius: 8))
               .contentShape(Rectangle())
           }
           .menuStyle(.borderlessButton)
           .fixedSize(horizontal: false, vertical: true)
       }
   }
   ```

   **Documentation reference:** Row dimensions and typography from `SidePaneSearchTrigger.swift:10-25`.

2. **Add file to Xcode project** — append to `OrbitAccessApp.xcodeproj/project.pbxproj` under the SidePane group (copy pattern from `SidePaneSearchTrigger.swift` entry).

### Verification checklist

- [ ] File compiles in isolation (preview or build).
- [ ] Trigger row height matches `SidePaneSearchTrigger` (~36pt with 8pt vertical padding).
- [ ] Chevron appears on trailing edge; label text does not truncate at 220pt pane width.

### Anti-pattern guards

- Do not use `.menuStyle(.button)` on macOS — it renders a bordered button unlike the flat sidebar rows.
- Do not nest a `Button` inside the `Menu` label — the label is the trigger only.

---

## Phase 2: Search dropdown

**What to implement:** Replace the three `SidePaneSearchTrigger` rows in `SidebaneView` with one Search dropdown.

### Tasks

1. **Create `OrbitAccessApp/Views/SidePane/SearchDropdownMenu.swift`**

   Encapsulate menu items and wire existing actions:

   ```swift
   import SwiftUI

   struct SearchDropdownMenu: View {
       @Environment(AppViewModel.self) private var model

       var body: some View {
           SidePaneDropdownTrigger(title: "Search", icon: "magnifyingglass") {
               Button("Semantic Search") {
                   Task { await SemanticSearchFunction().execute(model.aiContext()) }
               }
               Button("Find by App") {
                   Task { await FindByAppFunction().execute(model.aiContext()) }
               }
               Button("Find by Time") {
                   model.searchStore.activateFindByTime()
               }
           }
       }
   }
   ```

   **Copy actions verbatim from** `SidebaneView.swift:13-21`.

2. **Optional enhancement (recommended):** Track `@State private var lastSelection: String?` and update trigger title to `"Search · Semantic"` etc. after pick. Default label remains `"Search"` when nil. Keeps sidebar compact while showing context.

3. **Update `SidebaneView.swift`** — replace lines 13-21:

   ```swift
   SidePaneSectionHeader(title: "SEARCH")
   if model.searchStore.panelActive {
       SidebaneSearchPanel()
   }
   SearchDropdownMenu()
   ```

   Remove the three `SidePaneSearchTrigger` calls.

### Verification checklist

- [ ] Tap Search dropdown → menu shows three items with correct labels.
- [ ] **Semantic Search** → `panelActive == true`, `mode == .hybrid`, search panel appears.
- [ ] **Find by App** → panel active, query prefilled `"find in app: "`.
- [ ] **Find by Time** → panel active, query prefilled `"time: "`.
- [ ] Search panel still renders **above** the dropdown (not inside the menu).
- [ ] Grep confirms no remaining `SidePaneSearchTrigger` usage in `SidebaneView`.

---

## Phase 3: Agents dropdown

**What to implement:** Replace the four `AgentShortcutRow` rows with one Agents dropdown showing colored icons per agent.

### Tasks

1. **Create `OrbitAccessApp/Views/SidePane/AgentsDropdownMenu.swift`**

   ```swift
   import SwiftUI

   struct AgentsDropdownMenu: View {
       @Environment(AppViewModel.self) private var model

       private let agents: [AgentType] = [.writing, .research, .code, .admin]

       var body: some View {
           SidePaneDropdownTrigger(title: "Agents", icon: "person.2", iconColor: .secondary) {
               ForEach(agents, id: \.self) { agent in
                   Button {
                       Task { await AgentPromptFunction(agentType: agent).execute(model.aiContext()) }
                   } label: {
                       Label(agent.displayName, systemImage: agent.icon)
                   }
               }
           }
       }
   }
   ```

   **Copy agent list and action from** `SidebaneView.swift:24-27` and `AgentShortcutRow.swift:8-9`.

   macOS `Menu` renders `Label` icons in the menu list automatically. Agent tint colors in the **menu list** are system-default unless you add a custom `Label` with `.foregroundStyle(agent.color)` — optional polish, not required for MVP.

2. **Optional enhancement:** Same `lastSelection` pattern as Search — trigger shows `"Agents · Research"` after pick.

3. **Update `SidebaneView.swift`** — replace lines 23-27:

   ```swift
   SidePaneSectionHeader(title: "AGENTS")
   AgentsDropdownMenu()
   ```

### Verification checklist

- [ ] Tap Agents dropdown → four items: Writing, Research, Code, Admin.
- [ ] Each item prefills chat input (`"Writing: "`, etc.) and focuses `ChatInputBar`.
- [ ] Agent list matches previous four hardcoded rows (not `AgentType.allCases`).
- [ ] Grep confirms no remaining `AgentShortcutRow` usage in `SidebaneView`.

---

## Phase 4: Design doc & project hygiene

**What to implement:** Update documentation and confirm Xcode project membership.

### Tasks

1. **Update `plans/orbitaccessappdesign.md` §4.1** — replace the Sidebane tree:

   ```
   SidebaneView
   ├─ SidePaneSectionHeader("SEARCH")
   │  ├─ SidebaneSearchPanel()          // conditional
   │  └─ SearchDropdownMenu()
   ├─ SidePaneSectionHeader("AGENTS")
   │  └─ AgentsDropdownMenu()
   …
   ```

2. **Update file tree in §8** — add `SidePaneDropdownTrigger.swift`, `SearchDropdownMenu.swift`, `AgentsDropdownMenu.swift`.

3. **Leave `SidePaneSearchTrigger.swift` and `AgentShortcutRow.swift` in tree** for now (zero call sites after Phase 2–3). A follow-up can delete them once confirmed unused.

### Verification checklist

- [ ] Design doc §4.1 matches implemented hierarchy.
- [ ] All three new Swift files appear in `project.pbxproj` and compile target.

---

## Phase 5: Verification

**What to implement:** Build and manually smoke-test the Sidebane.

### Tasks

1. **Build**

   ```bash
   cd OrbitAccessApp
   xcodebuild -scheme OrbitAccessApp -configuration Debug build \
     CODE_SIGN_IDENTITY="-" CODE_SIGNING_ALLOWED=NO 2>&1 | tail -20
   ```

2. **Static grep checks**

   ```bash
   # No stale row usage in SidebaneView
   rg 'SidePaneSearchTrigger|AgentShortcutRow' OrbitAccessApp/Views/SidePane/SidebaneView.swift
   # New components present
   rg 'SearchDropdownMenu|AgentsDropdownMenu|SidePaneDropdownTrigger' OrbitAccessApp/
   ```

3. **Manual UI checklist** (requires running app on macOS)

   - [ ] Sidebane shows 2 pulldown rows under SEARCH and AGENTS headers (not 7 stacked buttons).
   - [ ] Dropdown menus open on click; items are selectable.
   - [ ] Search modes and agent prefills behave identically to pre-change behavior.
   - [ ] 220pt pane width: no layout overflow or clipped chevron.
   - [ ] Dark mode: trigger background readable (`Color.primary.opacity(0.04)`).

### Anti-pattern guards

- Grep for `NSMenu(` or custom popover code — should return zero new hits in SidePane.
- Confirm `AIFunctionRegistry` still registers functions at launch (unchanged in `AppDelegate`).

---

## File change summary

| File | Action |
|------|--------|
| `Views/SidePane/SidePaneDropdownTrigger.swift` | **Add** — shared pulldown chrome |
| `Views/SidePane/SearchDropdownMenu.swift` | **Add** — Search menu + actions |
| `Views/SidePane/AgentsDropdownMenu.swift` | **Add** — Agents menu + actions |
| `Views/SidePane/SidebaneView.swift` | **Edit** — swap rows for dropdowns |
| `OrbitAccessApp.xcodeproj/project.pbxproj` | **Edit** — register new files |
| `plans/orbitaccessappdesign.md` | **Edit** — §4.1 tree + §8 file list |
| `SidePaneSearchTrigger.swift` | Keep (unused after) |
| `AgentShortcutRow.swift` | Keep (unused after) |

---

## Session boundaries

Each phase is independently executable in a fresh chat:

| Phase | Inputs needed | Done when |
|-------|---------------|-----------|
| 1 | Phase 0 (this doc) | `SidePaneDropdownTrigger` compiles |
| 2 | Phase 1 complete | Search dropdown wired, three actions work |
| 3 | Phase 1 complete | Agents dropdown wired, four prefills work |
| 4 | Phases 2–3 complete | Design doc updated |
| 5 | Phases 1–4 complete | Build green + manual checklist passed |

Phases 2 and 3 can run **in parallel** after Phase 1.

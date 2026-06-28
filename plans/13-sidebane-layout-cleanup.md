# Plan: Sidebane Layout Cleanup

**Goal:** Declutter the left sidebar by removing redundant section headers, pinning capture/daemon controls to the bottom, and converting Privacy Policy into a compact icon button beside the atoms stat.

**Status:** Complete (2026-06-29). Phases 1–4 verified; `swift build` green.

**Scope:** `OrbitAccessApp/Views/SidePane/` only. No store, daemon, or privacy URL logic changes.

**References:**
- Current layout: `OrbitAccessApp/Views/SidePane/SidebaneView.swift:7-28`
- Atoms stat row: `OrbitAccessApp/Views/SidePane/CaptureStatsView.swift:7-25`
- Daemon row (Stop/Start box buttons): `OrbitAccessApp/Views/SidePane/DaemonStatusIndicator.swift:8-88`
- Box button style: `OrbitAccessApp/Views/Components/OrbitFlatButtonStyle.swift:3-48`
- Hover tooltip precedent: `OrbitAccessApp/Views/Chat/ChatInputBar.swift:84,118,132` (`.help(...)`)
- Design doc (stale): `plans/orbitaccessappdesign.md:184-194`
- Screenshot (before): `assets/Screenshot_2026-06-29_at_1.35.17_AM-b53a6ff9-e5f2-4351-993c-c04921e0f31c.png`

---

## Phase 0: Documentation Discovery (complete)

### Allowed APIs & patterns

| API / pattern | Source | Notes |
|---------------|--------|-------|
| `VStack` + `Spacer(minLength: 0)` footer pin | SwiftUI standard | Copy from `MainWindowView.swift` ZStack pattern; replaces full-height `ScrollView` wrapper |
| `SidePaneDropdownTrigger` | `SidePaneDropdownTrigger.swift:11-37` | Keep Search/Agents rows unchanged except spacing |
| `OrbitFlatButtonStyle(variant: .secondary)` | `OrbitFlatButtonStyle.swift:3-48`, `DaemonStatusIndicator.swift:82` | Copy for icon-only Privacy button — same bordered box as Stop |
| `.help("Privacy Policy")` | `ChatInputBar.swift:132`, `TaskCard.swift:58` | Native macOS hover tooltip; **existing project convention** |
| `OrbitPaths.privacyPolicyURL()` + `NSWorkspace.shared.open` | `SidebaneView.swift:58-60` | Keep open behavior unchanged |
| `model.insightStore.atomsCapturedToday` | `CaptureStatsView.swift:14` | Keep data binding unchanged |
| `OrbitShape.radiusControl`, `.orbitHairlineBorder` | `OrbitShape.swift:6-39` | Shared control chrome |

### Anti-patterns to avoid

- Do **not** invent AppKit `NSTooltip` / custom NSPopover when `.help()` already matches "show on hover".
- Do **not** change daemon start/stop logic, polling, or status strings.
- Do **not** move Search/Agents dropdowns to the footer — only capture + privacy + daemon.
- Do **not** add new section headers or dividers to replace the removed ones.
- Do **not** use `ScrollView` wrapping the entire sidebar if it prevents footer pinning; scroll only the top block if the search panel overflows.
- Do **not** delete `SidePaneSectionHeader.swift` until grep confirms zero references (may remain for future panes).

### Current vs desired layout

| | Current | Desired |
|---|---------|---------|
| Section headers | 4 uppercase labels (Search, Agents, Capture, Privacy) | **None** |
| Top block | Headers + Search panel + Search menu + Agents menu | Search panel + Search menu + Agents menu (tighter spacing) |
| Middle | Daemon row, then atoms stat | **Empty** — `Spacer` pushes footer down |
| Bottom | Privacy full-width text row | Atoms stat (left) + hand icon box (right), then daemon row below |

---

## Phase 1: Remove section headers & restructure SidebaneView

**What to implement:** Rewrite `SidebaneView` body to a pinned-footer `VStack`. Remove all `SidePaneSectionHeader` usages.

### Tasks

1. **Edit `OrbitAccessApp/Views/SidePane/SidebaneView.swift`**

   Replace the `ScrollView` + flat `VStack` with:

   ```swift
   VStack(alignment: .leading, spacing: 12) {
       // Top — may scroll if search panel grows
       VStack(alignment: .leading, spacing: 12) {
           if model.searchStore.panelActive {
               SidebaneSearchPanel()
           }
           SearchDropdownMenu()
           AgentsDropdownMenu()
       }

       Spacer(minLength: 0)

       // Bottom footer — pinned
       VStack(alignment: .leading, spacing: 8) {
           SidebaneCaptureFooter()
           DaemonStatusIndicator()
       }
   }
   .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
   .padding(.horizontal, 12)
   .padding(.top, 16)
   .padding(.bottom, 12)
   ```

2. **Remove** the four `SidePaneSectionHeader(...)` lines and the inline `PrivacyPolicyLink` struct (moved to Phase 2).

3. **Optional:** If `SidebaneSearchPanel` overflow is a concern in testing, wrap only the top `VStack` in `ScrollView` — not the footer block.

### Verification checklist

- [ ] `grep SidePaneSectionHeader SidebaneView.swift` returns no matches
- [ ] Search panel still appears above Search dropdown when active
- [ ] Agents/Search dropdown actions unchanged
- [ ] Footer| grep SidePaneSectionHeader OrbitAccessApp/` — note remaining refs (file may still exist)

---

## Phase 2: Create SidebaneCaptureFooter (atoms + privacy icon row)

**What to implement:** New component combining `CaptureStatsView` content and an icon-only Privacy button in one `HStack`, mirroring the daemon row's left-stat / right-control layout.

### Tasks

1. **Create `OrbitAccessApp/Views/SidePane/SidebaneCaptureFooter.swift`**

   Copy layout from `CaptureStatsView.swift:8-24` for the left side. Copy button chrome from `DaemonStatusIndicator.swift:79-82` for the right side:

   ```swift
   struct SidebaneCaptureFooter: View {
       @Environment(AppViewModel.self) private var model
       @Environment(\.colorScheme) private var colorScheme

       var body: some View {
           HStack(spacing: 8) {
               // Left — atoms stat (copy from CaptureStatsView)
               Image(systemName: "doc.text")
                   ...
               VStack(alignment: .leading, spacing: 2) { ... }

               Spacer(minLength: 4)

               // Right — privacy icon box
               Button { openPrivacyPolicy() } label: {
                   Image(systemName: "hand.raised")
                       .font(.callout)
               }
               .buttonStyle(OrbitFlatButtonStyle(variant: .secondary))
               .help("Privacy Policy")
           }
           .padding(.horizontal, 10)
           .padding(.vertical, 8)
       }

       private func openPrivacyPolicy() {
           guard let url = OrbitPaths.privacyPolicyURL() else { return }
           NSWorkspace.shared.open(url)
       }
   }
   ```

2. **Decide on `CaptureStatsView.swift`:**
   - **Preferred:** Delete file and inline into `SidebaneCaptureFooter` (single consumer).
   - **Alternative:** Keep `CaptureStatsView` as a private subview inside the footer file if reuse is anticipated.

3. **Remove** `PrivacyPolicyLink` from `SidebaneView.swift` (replaced by footer icon).

### Verification checklist

- [ ] Atoms count still binds to `model.insightStore.atomsCapturedToday`
- [ ] Privacy icon opens same URL as before
- [ ] Hovering hand icon shows "Privacy Policy" tooltip (`.help`)
- [ ] No visible "Privacy Policy" text at rest
- [ ] Icon box visually matches Stop button (bordered, `OrbitFlatButtonStyle` secondary)

---

## Phase 3: Spacing & visual polish

**What to implement:** Tighten vertical rhythm now that headers are gone; ensure footer reads as one unit.

### Tasks

1. **Reduce top-block spacing** from 12 → 8 pt if the sidebar feels too airy after header removal.

2. **Align footer padding** with `DaemonStatusIndicator` (both use `.padding(.horizontal, 10)` / `.padding(.vertical, 8)` — keep consistent).

3. **Confirm dark mode:** icon colors use `Color.orbitSecondaryText(for: colorScheme)` on the doc icon; hand icon inherits button foreground.

4. **Update stale design doc** (optional follow-up, not blocking): `plans/orbitaccessappdesign.md:184-194` tree diagram.

### Verification checklist

- [ ] Screenshot comparison: headers gone, daemon at bottom, atoms above daemon
- [ ] Privacy icon sits right of atoms on same row
- [ ] Sidebar height 600pt (min window): footer flush to bottom, menus at top

---

## Phase 4: Verification

**What to implement:** Build + grep checks; manual UI smoke test.

### Tasks

1. **Build**
   ```bash
   cd OrbitAccessApp && swift build
   ```

2. **Grep anti-patterns**
   ```bash
   rg 'SidePaneSectionHeader' OrbitAccessApp/Views/SidePane/SidebaneView.swift   # expect: no matches
   rg 'Privacy Policy' OrbitAccessApp/Views/SidePane/                             # expect: only in .help(...) string
   rg 'ScrollView' OrbitAccessApp/Views/SidePane/SidebaneView.swift               # expect: none unless panel overflow fix applied
   ```

3. **Manual smoke test**
   - [ ] Search dropdown still fires Semantic / App / Time actions
   - [ ] Agents dropdown still prefills chat
   - [ ] Start/Stop daemon works; status dot + label correct
   - [ ] Atoms count updates (or shows 0 when empty)
   - [ ] Privacy icon click opens policy doc; hover shows tooltip only
   - [ ] ⌘S sidebar collapse still works (footer hidden with pane)

### Rollback

Single commit touching `SidebaneView.swift` + new `SidebaneCaptureFooter.swift` (+ optional delete `CaptureStatsView.swift`). Revert commit to restore prior layout.

---

## File touch list

| File | Action |
|------|--------|
| `Views/SidePane/SidebaneView.swift` | Rewrite layout, remove headers & PrivacyPolicyLink |
| `Views/SidePane/SidebaneCaptureFooter.swift` | **New** — atoms + privacy icon row |
| `Views/SidePane/CaptureStatsView.swift` | Delete or fold into footer |
| `Views/SidePane/SidePaneSectionHeader.swift` | Keep unless grep shows zero refs project-wide |
| `plans/orbitaccessappdesign.md` | Optional doc update |

**Estimated effort:** 1 phase per chat session; ~30 min total.

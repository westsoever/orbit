# Plan: Mistral-Inspired Calm UI Revamp (Full App)

> Shift Orbit Access App from the rounded Littlebird aesthetic to a **Mistral Le Chat–inspired** calm, seamless UI across all three panes, status bar popover, and floating chat. **Keep** warm chat background `#F9F8F3` / `#141414` and indigo accent `#636AFF`. Borrow Mistral/Vercel **layout and interaction**, not their gray color scheme.

**Status:** Implemented (June 2026)

**Reference:** Mobbin patterns — Mistral Le Chat (unified input card), Vercel dashboard (hairline dividers, flat cards).

---

## Shape tokens (`OrbitShape.swift`)

| Token | Value | Use |
|-------|-------|-----|
| `radiusCard` | 8pt | Input card, OrbitCard, message bubbles |
| `radiusChip` | 6pt | Suggestion pills, citation chips, send button |
| `radiusControl` | 4pt | Badges, flat buttons, dropdown triggers |
| `borderHairlineWidth` | 0.5pt | Card borders, pane separators |
| `orbitSurfaceMuted` | `primary @ 4%` | Toolbar icon pill |
| `orbitBorderHairline` | `primary @ 8%` | Card strokes |
| `orbitDividerHairline` | `primary @ 6%` | In-card / popover dividers |

**Anti-patterns removed:** `Capsule()`, card drop shadows, `.regularMaterial` on assistant bubbles, 12–16pt card radii.

---

## Unified input card (`ChatInputBar`)

```
┌──────────────────────────────────────────┐
│  multiline TextField                     │
├──────────────────────────────────────────┤  OrbitHairlineDivider
│  [paperclip] [icon pill]     [pop] [↑]   │
├──────────────────────────────────────────┤  landing only
│  [suggestion pills — horizontal scroll]  │
└──────────────────────────────────────────┘
```

- Send: `RoundedRectangle(cornerRadius: 6)` near-black fill (not circle).
- Suggestion chips embedded inside card on landing; omitted in compact/conversation mode.
- `ChatIntegrationsStrip`: icon-only cluster in muted pill.

---

## Shared primitives

| Component | File |
|-----------|------|
| Shape tokens + `orbitHairlineBorder` | `Extensions/OrbitShape.swift` |
| In-card / pane dividers | `Views/Components/OrbitHairlineDivider.swift` |
| Flat primary/secondary buttons | `Views/Components/OrbitFlatButtonStyle.swift` |
| Card shell (8pt, hairline, no shadow) | `Views/Components/OrbitCard.swift` |
| Pane seams | `Views/Root/ThreePaneLayout.swift` → `OrbitPaneHairline` |

---

## Verification checklist

- [x] Warm chat bg unchanged (`#F9F8F3` / `#141414`)
- [x] No `Capsule()` in `OrbitAccessApp/`
- [x] No `.shadow(` on cards
- [x] Landing: unified input card with internal suggestion row
- [x] Conversation + floating chat: compact input, no shadow
- [x] `swift build` succeeds via SPM
- [ ] Manual visual pass: `bash scripts/run_orbit_access_app.sh`

---

## Files touched

**New:** `OrbitShape.swift`, `OrbitHairlineDivider.swift`, `OrbitFlatButtonStyle.swift`

**Chat:** `ChatInputBar`, `ChatIntegrationsStrip`, `ChatSuggestionChips`, `ChatHeroView`, `ChatBubbleView`, `ContextSourceChip`, `MainChatView`, `CloudAIEnableCard`

**Shell:** `OrbitCard`, `ThreePaneLayout`, `SectionHeader`, SidePane triggers, `SidebaneView`, `RecentCaptureList`, `ProductivityScoreGauge`, `TaskCard`, `DaemonStatusIndicator`, `StatusBarPopoverView`, `AgentTypeBadge`, `TimeChip`, `AgentShortcutRow`

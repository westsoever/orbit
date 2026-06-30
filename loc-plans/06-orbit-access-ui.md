# Plan 06: Orbit Access UI smoke test

Visual and interaction checks for SwiftUI work that cloud agents could only compile, not run. One session, ~20 minutes.

**Commits:** `aa18df1`, `872b64f`, `7939cd7`, `ef4c912`, `f7c849c`, `4d647e7`, `bcda968`  
**Source plans:** `plans/06-sidebar-dropdown-menus.md`, `plans/07-littlebird-chat-redesign.md`, `plans/08-fix-chat-interactivity.md`, `plans/11-mistral-calm-ui-revamp.md`, `plans/05-bottom-left-issue-notifications.md`

## Launch

```bash
# Dev (forces rebuild even if /Applications/Orbit.app exists):
ORBIT_FORCE_DEV_BUILD=1 bash scripts/run_orbit_access_app.sh

# Or installed app:
open -a Orbit
```

Daemon should auto-start (`03-daemon-lifecycle.md`).

## Checklist

### Insight sidebar — recent notes (`aa18df1`)

1. Capture text in Notes or a browser for 1 min.
2. Open insight sidebar **Recent notes** (or equivalent section).

**Pass:** short text snippets from atoms — not raw “capture event” rows with bundle IDs only.

### Today's schedule placeholder (`f53afe6`)

**Pass:** calendar icon + “No calendar connected” (or similar); not a list of capture events.

### Chat layout (`7939cd7`, `872b64f`)

**Pass:**

- Empty chat: hero / suggestion chips visible.
- Calm flat styling (Mistral-inspired); no broken layout at default window size.
- Suggestion chip tap → fills input → Return sends (if AI configured).

### Sidebar dropdowns (`f7c849c`)

**Pass:** Sidebane search and agent rows collapse into menus; panels still open on selection.

### Keyboard shortcuts (`4d647e7`)

**Pass:** ⌘S toggles sidebar; ⌘B toggles secondary panel (per current binding).

### Bottom-left issues (`ef4c912`)

Simulate or trigger a bootstrap issue (e.g. temporarily rename `~/.orbit/orbit.db` while app runs, then restore).

**Pass:**

- Issue appears bottom-left, not a blocking top banner.
- Overlay does not block chat clicks when dismissed / no issue.
- Retry action works when offered.

### App icon (`bcda968`, `f48476b`)

**Pass:** Dock and `/Applications` show honeycomb Orbit icon (not generic Swift placeholder).

### Status bar (`ISSUE_REPORT.md`)

**Pass:** menu bar glyph reflects state: idle / capturing / browse-only / no database.

### Account settings (`5126edf`)

**Pass:** Settings shows signed-in user; sign-out/sign-in flows without layout break.

## Regression — do not break

- [ ] Offline browse when daemon stopped (`plans/09-offline-orbit-access.md`)
- [ ] Lexical search without daemon
- [ ] Daemon Start/Stop in sidebar and menu bar popover

## Pass criteria

All checklist items pass on **both** dev bundle and installed `/Applications/Orbit.app` (pick at least one path you ship to testers).

# Capture Compatibility Matrix

Manual compatibility reference for Orbit tiered capture (`plans/03-universal-capture.md` Phase 6).

| App | Bundle | Tier expected | Atoms | Notes |
|-----|--------|---------------|-------|-------|
| Terminal | `com.apple.Terminal` | 1 | ✓ | Baseline native AX |
| Cursor | `com.todesktop.*` | 1+ | ✓ | Adaptive depth 24; AX enable on Electron |
| VS Code | `com.microsoft.VSCode` | 1+ | ✓ | Electron depth 24 |
| Slack | `com.slack.*` | 1+ | ✓ | Electron depth 24 |
| Dia | `company.thebrowser.dia` | 2 | ✓ | AX empty by default; use browser extension or `chrome://accessibility` |
| Chrome | `com.google.Chrome` | 1+ or 2 | TBD | Enable renderer accessibility or install Orbit browser companion |
| Arc | `company.thebrowser.Browser` | 1+ or 2 | TBD | Same as Chromium |
| Safari | `com.apple.Safari` | 1+ or 2 | TBD | AX or extension |
| 1Password | `com.1password.*` | excluded | — | Default exclusion list |
| Dock | `com.apple.dock` | excluded | — | Default exclusion list |
| Workspace files | user `watch_roots` | 3 | paths only | Opt-in via `orbit privacy enable-fsevents`; paths + mtimes, no file contents |

## Success criteria (from plan)

- ≥90% of daily apps (by focus time) produce at least Tier 0 metadata
- ≥70% produce Tier 1+ text atoms without enhanced modes
- Zero silent skips without INFO log
- B2C: user can disable any tier and delete all data via `orbit privacy delete --yes`

## Verification

```bash
scripts/probe_app.py --all-visible
scripts/verify.sh
bash scripts/grep_antipatterns.sh
scripts/test_fsevents.py
```

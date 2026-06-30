# Orbit

Always-on agentic system for macOS. Captures working context via the Accessibility API (no screenshots by default), stores it locally, detects tasks, and dispatches approved work to an LLM agent.

> *A mediocre model with perfect context outperforms a frontier model starting from zero every session.*

---

## Install & test (macOS)

Orbit ships as a native macOS app (`Orbit.app`) plus a terminal CLI. **Testers do not need to clone the repo** — use one of the paths below.

### Requirements

| Requirement | Notes |
|-------------|-------|
| **macOS 14+** (Sonoma or later) | Apple Silicon or Intel |
| **[Homebrew](https://brew.sh)** | Installs Python 3.13 if missing |
| **Xcode Command Line Tools** | `xcode-select --install` (needed to build the Swift UI) |
| **~10 GB free disk** | Build cache + PyTorch/sentence-transformers download (~1–2 GB) |
| **Internet on first install** | Source build downloads Python deps; capture itself stays local |

First install typically takes **15–30 minutes** (Swift compile + pip install). Later reinstalls are faster.

### Option A — One-line install (recommended for testers)

Builds from the latest `main` branch and installs to `/Applications`:

```bash
curl -fsSL https://raw.githubusercontent.com/westsoever/orbit/main/scripts/install.sh | bash
```

Skip auto-launch after install:

```bash
ORBIT_NO_START=1 curl -fsSL https://raw.githubusercontent.com/westsoever/orbit/main/scripts/install.sh | bash
```

When finished you should have:

- `/Applications/Orbit.app` — open from Spotlight or Dock
- `orbit` on your PATH (symlinked to `/usr/local/bin/orbit`)

User data lives in `~/.orbit/` (database, policy, logs) and survives app upgrades.

### Option B — Pre-built zip (GitHub Releases)

When a [GitHub Release](https://github.com/westsoever/orbit/releases) is published, download **`Orbit-darwin.zip`** and unzip, or install via:

```bash
ORBIT_VERSION=0.0.1 ORBIT_INSTALL_FROM_SOURCE=0 \
  curl -fsSL https://raw.githubusercontent.com/westsoever/orbit/main/scripts/install.sh | bash
```

Replace `0.0.1` with the tag shown on the release page. Pre-built installs skip the compile step and finish in a few minutes.

### First launch (all installs)

1. **Gatekeeper (unsigned beta builds):** If macOS says the app is from an unidentified developer, right-click **Orbit** in `/Applications` → **Open**, or run:
   ```bash
   xattr -cr /Applications/Orbit.app
   open -a Orbit
   ```
2. **Accessibility:** System Settings → Privacy & Security → **Accessibility** → enable **Orbit**. Capture will not work without this ([full guide](orbit/capture/PERMISSIONS.md)).
3. **Start capture:** In the Orbit sidebar under **CAPTURE**, click **Start** (or run `orbit start --detach --no-embed` from Terminal).

Verify the install:

```bash
orbit doctor
curl -s http://127.0.0.1:8765/health    # {"ok": true} when daemon is running
```

### Tester checklist

Work through these after install and report anything that fails in a [GitHub issue](https://github.com/westsoever/orbit/issues):

| Step | What to do | Expected |
|------|------------|----------|
| 1 | `orbit doctor` | Python 3.13 + SQLite extensions OK |
| 2 | Open Orbit → **Start** in CAPTURE | Green status dot; "Capturing" pulse |
| 3 | Switch between 2–3 apps (Terminal, Safari, Notes) | History panel shows new entries within ~2 s |
| 4 | Sidebar search for a word from a visible window | Results appear (lexical or hybrid) |
| 5 | Chat tab → send a message | Response (needs Cloud AI enabled or local daemon + API key) |
| 6 | `orbit stop` or sidebar **Stop** | Daemon stops; health check fails |

Low-CPU testing: use `orbit start --detach --no-embed` (skips embedding model). Full smoke tests for contributors: `bash scripts/verify.sh --no-embed`.

### Update or reinstall

Re-run the install command — the script removes the old `/Applications/Orbit.app` first. Your data in `~/.orbit/` is kept unless you delete it manually.

### Uninstall

```bash
orbit stop 2>/dev/null || true
rm -rf /Applications/Orbit.app /usr/local/bin/orbit
# Optional — delete all captured data:
# rm -rf ~/.orbit
```

---

## Development

Clone the repo and use an editable install for hacking on capture, search, or the Swift UI:

```bash
git clone https://github.com/westsoever/orbit.git
cd orbit
brew install python@3.13
/opt/homebrew/bin/python3.13 -m venv .venv
source .venv/bin/activate
pip install -e .
bash scripts/run_orbit_access_app.sh   # build + launch dev app (skips if /Applications/Orbit.app exists)
```

Embeddings need Homebrew Python (not the python.org installer):

```bash
python -c "import sqlite3; sqlite3.connect(':memory:').enable_load_extension(True)"
```

Grant Accessibility to Terminal or your IDE. See `orbit/capture/PERMISSIONS.md`.

---

## What it does

1. **Capture** — Event-driven app-focus listener walks the active window's `AXUIElement` tree and stores structured text atoms in SQLite. Tiered fallbacks cover Electron apps, browsers, file workspace events, and opt-in OCR.
2. **Embed** — Optional background worker embeds atoms with `all-MiniLM-L6-v2` into a `sqlite-vec` table (384-dim). Skip with `--no-embed` for lower CPU/RAM.
3. **Search** — Hybrid BM25 + cosine similarity via Reciprocal Rank Fusion (`orbit search`).
4. **Check** — LLM task detection from a context document; approval gate before dispatch.
5. **Dispatch** — Streams approved prompts through OpenRouter; saves output to `mvp-output/`.

---

## Capture tiers

Orbit uses a GDPR-aligned tier model (`plans/03-universal-capture.md`). Defaults are minimal; enhanced modes are opt-in.

| Tier | Method | Default | What is stored |
|------|--------|---------|----------------|
| 0 | Metadata only | fallback | App name, bundle ID, window title |
| 1 | AX text | **on** | UI text atoms (`AXStaticText`, `AXTextField`, …) |
| 2 | Browser extension | on (bridge) | URL, title, selection via local HTTP bridge |
| 3 | FSEvents | **off** | File paths + mtimes in watched folders (no contents) |
| 4 | OCR (Vision) | **off** | On-screen text when AX fails; no image files stored |
| 5 | Sampled OCR | **off** | Rate-limited (60s) allowlist variant of tier 4 |

Policy file: `~/.orbit/policy.json` — toggles tiers, `watch_roots`, exclusions, retention.

---

## Architecture

```
NSWorkspace (app focus)          Browser extension (optional)
        │                                    │
        ▼                                    ▼
  focus_queue                         browser_queue
        │                                    │
        ▼                                    ▼
 capture_worker ◄── policy.json      browser_worker
   AX walk + fallbacks                      │
        ├──► context_events + text_atoms ◄──┘
        ├──► capture_audit (every event)
        └──► embed_queue (optional)
                    │
                    ▼
              embed_worker → vec_atoms

FSEvents (opt-in) ──► fs_worker ──► fs_events
                      (links to nearest focus event ±30s)
```

### Key modules

| Path | Role |
|------|------|
| `orbit/capture/listener.py` | App-focus events (1.5s debounce per bundle) |
| `orbit/capture/worker.py` | AX capture, metadata/OCR fallbacks |
| `orbit/capture/profiles.py` | Adaptive depth: 12 native / 20 Chromium / 24 Electron |
| `orbit/browser_bridge/` | Localhost HTTP ingest + Orbit Access API (`:8765`) |
| `orbit/daemon_pid.py`, `orbit/daemon_ctl.py` | PID file + detached start / graceful stop |
| `orbit/capture/fsevents_listener.py` | Tier 3 workspace path events |
| `orbit/privacy/` | Export, delete, purge (GDPR Art. 15/17) |
| `orbit/check/` | Task detection + dispatch |
| `orbit/search/` | Hybrid lexical + semantic search |

### Storage schema

| Table | Purpose |
|-------|---------|
| `context_events` | App-focus or browser events: method, tier, window, timestamp |
| `text_atoms` | Extracted UI text linked to events |
| `vec_atoms` | sqlite-vec embeddings (when embed worker enabled) |
| `atoms_fts` | FTS5 full-text index |
| `fs_events` | File create/modify/delete in watched folders (Tier 3) |
| `capture_audit` | Accountability log: method, tier, atom count |
| `task_log` | Task detection / dispatch audit |

Database default: `~/.orbit/orbit.db`  
Daemon PID file (when running): `~/.orbit/daemon.pid`  
Daemon log (detached mode): `~/.orbit/daemon.log`

---

## Orbit Access App

Native SwiftUI macOS frontend (`OrbitAccessApp/`) for browsing captured context, hybrid search, chat, and task approval. Installed users open **Orbit** from `/Applications`; developers use `scripts/run_orbit_access_app.sh`.

```bash
open -a Orbit                        # installed app
bash scripts/run_orbit_access_app.sh   # dev: build from repo (ORBIT_FORCE_DEV_BUILD=1 if /Applications/Orbit.app exists)
```

**Daemon controls in the UI**

| Location | Control |
|----------|---------|
| Sidebar → **CAPTURE** → `DaemonStatusIndicator` | **Start** / **Stop**, green/red status dot, **Capturing** pulse when active |
| Menu bar popover | **Start daemon** / **Stop daemon** |

The app polls `GET /api/status` every 5 seconds. When offline, chat send and hybrid search are disabled; local FTS5 history still works.

Design reference: `plans/orbitaccessappdesign.md`

Requires **macOS 14+** and **Accessibility** permission for Orbit (or Terminal when using the CLI).

---

## Usage

Activate the venv first: `source .venv/bin/activate`

### Capture daemon

```bash
# Foreground (terminal attached; Ctrl-C to stop)
orbit start --no-embed

# Background (recommended for Orbit Access App and daily use)
orbit start --detach --no-embed
orbit stop

# Full stack: capture + embeddings + browser bridge
orbit start --detach

# Options
orbit start --no-embed --no-browser-bridge --no-fsevents
orbit start --max-depth 16          # override AX depth
orbit start --purge-retention       # delete events older than policy retention_days
orbit start --ocr                   # session-only OCR enable (also set in policy)
```

**Lifecycle**

| Command | Behavior |
|---------|----------|
| `orbit start` | Runs in the foreground; blocks the terminal until Ctrl-C or menu bar **Quit Orbit** |
| `orbit start --detach` | Spawns a background process; logs to `~/.orbit/daemon.log`; writes `~/.orbit/daemon.pid` |
| `orbit stop` | Graceful shutdown via `POST /api/shutdown`, then SIGTERM if needed; removes PID file |

Verify the bridge is up:

```bash
curl -s http://127.0.0.1:8765/health        # {"ok": true}
curl -s http://127.0.0.1:8765/api/status    # {"ok": true, "capture_active": false}
```

Bridge routes used by Orbit Access App: `/api/status`, `/api/search`, `/api/chat`, `/api/tasks/pending`, `/api/task/{id}/approve`, `/api/task/{id}/skip`, `/api/shutdown`.

### Privacy & opt-in tiers

```bash
orbit privacy show-policy
orbit privacy enable-fsevents       # Tier 3: watch ~/Projects (edit watch_roots in policy)
orbit privacy enable-ocr            # Tier 4: requires Screen Recording permission
orbit privacy export --out ~/orbit-export.jsonl
orbit privacy purge --days 90
orbit privacy delete --yes
```

### Task detection

```bash
orbit check                         # detect + optionally dispatch
orbit check skipped                 # review skipped tasks
orbit check --dry-run
orbit check --source local --context path/to/context.md
```

### Search

```bash
python -m orbit.search "query text"
```

### Verification & debugging

```bash
orbit doctor                        # Python + SQLite extension diagnosis
bash scripts/verify.sh --no-embed   # smoke tests (skip heavy embed model)
bash scripts/grep_antipatterns.sh
python scripts/probe_app.py --bundle com.apple.Terminal
python scripts/probe_app.py --all-visible
python scripts/test_fsevents.py
python scripts/test_browser_bridge.py   # requires running daemon
python scripts/test_bridge_api.py       # in-process bridge tests (+ shutdown route)
```

Compatibility matrix: `docs/capture-compatibility.md`

---

## Browser companion (Tier 2)

For Chromium browsers where AX returns empty trees (Dia, Chrome, Arc):

1. `orbit start --detach` (bridge on `http://127.0.0.1:8765`)
2. Load unpacked extension from `orbit/browser-extension/` — see that README
3. Or enable renderer accessibility: `chrome://accessibility/`

---

## Low-CPU defaults

Orbit is event-driven (no polling loops). For minimal overhead:

- Use `orbit start --detach --no-embed --no-browser-bridge --no-fsevents`
- Keep `tier_ocr` and `tier_fsevents` off in `~/.orbit/policy.json`
- AX walks are capped at 5000 nodes; atoms capped at 300 per event
- Focus debounce: 1.5s per bundle; FSEvents latency: 1s

Embeddings load MiniLM (~90MB) on first capture batch when enabled.

---

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| `enable_load_extension` / SQLite extensions warning | Run `orbit doctor`. Orbit auto-restarts via `.venv/bin/orbit` when the project venv exists. Otherwise: `source .venv/bin/activate && pip install -e .` |
| Daemon won't start in background | Check `~/.orbit/daemon.log`. Ensure Accessibility permission granted; try `orbit start --detach --no-embed` from activated venv |
| Orbit Access shows "Daemon offline" | Tap **Start** in sidebar CAPTURE section, or run `orbit start --detach --no-embed` |
| `orbit stop` says not running but port busy | Stale process: `lsof -i :8765`, then `kill <pid>` and `rm -f ~/.orbit/daemon.pid` |
| Cursor/Electron: 0 atoms | Fixed by adaptive depth 24; probe with `scripts/probe_app.py` |
| Browser: empty_tree | Enable `chrome://accessibility` or install browser extension |
| OCR returns nothing | Grant Screen Recording; run `orbit privacy enable-ocr` |
| FSEvents inactive | Run `orbit privacy enable-fsevents`; ensure `watch_roots` paths exist |
| No captures at all | Accessibility permission + restart terminal |

Full permission guide: `orbit/capture/PERMISSIONS.md`

---

## Privacy & GDPR

- **Local-first:** capture data stays in `~/.orbit/` on device
- **No screenshots by default** — text via Accessibility API only
- **Exclusion list** by app bundle ID (banking, password managers, Dock)
- **Opt-in** enhanced tiers (browser ext bridge, FSEvents, OCR)
- **Data subject rights:** `orbit privacy export` / `delete` / `purge`

Compliance templates (not legal advice): `docs/gdpr/`

| Document | Purpose |
|----------|---------|
| `PRIVACY_POLICY.md` | Tier descriptions, retention, LLM dispatch |
| `DPIA_TEMPLATE.md` | B2B Data Protection Impact Assessment |
| `LIA_TEMPLATE.md` | Legitimate Interest Assessment (WP29) |

Internet is off during capture; used only when `orbit check` dispatches an approved task.

---

## Dependencies

| Package | Role |
|---------|------|
| `pyobjc-framework-Cocoa` | `NSWorkspace` focus events |
| `pyobjc-framework-ApplicationServices` | `AXUIElement` tree |
| `pyobjc-framework-FSEvents` | Tier 3 workspace file events |
| `pyobjc-framework-Quartz` + `Vision` | Tier 4 window OCR |
| `sqlite-vec` | Vector search in SQLite |
| `sentence-transformers` | Local embeddings |
| `openai` | OpenRouter client for task dispatch |

---

## Documentation map

| File | Contents |
|------|----------|
| `orbit-context.md` | Product brief and architecture decisions |
| `innitial.md` | Full roadmap and feasibility matrix |
| `plans/03-universal-capture.md` | Universal capture implementation plan |
| `plans/orbitaccessappdesign.md` | Orbit Access App (SwiftUI) design + bridge API |
| `OrbitAccessApp/ISSUE_REPORT.md` | Access app build/run notes |
| `docs/capture-compatibility.md` | App-by-app capture matrix |
| `docs/architecture-context-routing.md` | Context routing diagram (capture vs check) |
| `docs/diagrams/context-routing.mmd` | Mermaid source for architecture diagram |
| `docs/gdpr/` | Privacy policy and compliance templates |
| `orbit/capture/PERMISSIONS.md` | macOS permission setup |

---

## Roadmap

| Phase | Status | Scope |
|-------|--------|-------|
| 1 — Context Foundation | **Done** | Capture daemon, SQLite store, hybrid search, universal AX, Orbit Access App |
| 2 — Kanban MVP | Planned | Orchestrator + retrieval, Kanban UI |
| 3 — Agent Execution | Planned | MCP integration, approval gates, audit log |
| 4 — Full Agent Fleet | Future | Code Agent (Docker), local LLM mode |
| SQLCipher encryption | Future | Encrypted context store at rest |
| Whisper / calendar / email | Future | Phase 4B/4C complementary sources |

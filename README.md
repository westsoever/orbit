# Orbit

Always-on agentic system for macOS. Captures working context via the Accessibility API (no screenshots by default), stores it locally, detects tasks, and dispatches approved work to an LLM agent.

> *A mediocre model with perfect context outperforms a frontier model starting from zero every session.*

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
| `orbit/browser_bridge/` | Localhost HTTP ingest for browser companion |
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

---

## Install

Requires **macOS 14+**, **Python 3.10+**, and **Accessibility** permission for Terminal/Python.

Embeddings need a Python build with loadable SQLite extensions (Homebrew Python; not the python.org installer):

```bash
brew install python@3.13
/opt/homebrew/bin/python3.13 -m venv .venv
source .venv/bin/activate
pip install -e .

# Verify — use venv `python`, not system `python3`:
python -c "import sqlite3; sqlite3.connect(':memory:').enable_load_extension(True)"
which orbit   # .../orbit/.venv/bin/orbit
```

Grant Accessibility: System Settings → Privacy & Security → Accessibility → enable Terminal (or your IDE). See `orbit/capture/PERMISSIONS.md` for browsers, OCR, and FSEvents.

---

## Usage

Activate the venv first: `source .venv/bin/activate`

### Capture daemon

```bash
# Recommended: capture + FTS, minimal CPU/RAM
orbit start --no-embed

# Full stack: capture + embeddings + browser bridge
orbit start

# Options
orbit start --no-embed --no-browser-bridge --no-fsevents
orbit start --max-depth 16          # override AX depth
orbit start --purge-retention       # delete events older than policy retention_days
orbit start --ocr                   # session-only OCR enable (also set in policy)
```

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
```

Compatibility matrix: `docs/capture-compatibility.md`

---

## Browser companion (Tier 2)

For Chromium browsers where AX returns empty trees (Dia, Chrome, Arc):

1. `orbit start` (bridge on `http://127.0.0.1:8765`)
2. Load unpacked extension from `orbit/browser-extension/` — see that README
3. Or enable renderer accessibility: `chrome://accessibility/`

---

## Low-CPU defaults

Orbit is event-driven (no polling loops). For minimal overhead:

- Use `orbit start --no-embed --no-browser-bridge --no-fsevents`
- Keep `tier_ocr` and `tier_fsevents` off in `~/.orbit/policy.json`
- AX walks are capped at 5000 nodes; atoms capped at 300 per event
- Focus debounce: 1.5s per bundle; FSEvents latency: 1s

Embeddings load MiniLM (~90MB) on first capture batch when enabled.

---

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| `enable_load_extension` / SQLite extensions warning | Run `orbit doctor`. Orbit auto-restarts via `.venv/bin/orbit` when the project venv exists. Otherwise: `source .venv/bin/activate && pip install -e .` |
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
| `docs/capture-compatibility.md` | App-by-app capture matrix |
| `docs/architecture-context-routing.md` | Context routing diagram (capture vs check) |
| `docs/diagrams/context-routing.mmd` | Mermaid source for architecture diagram |
| `docs/gdpr/` | Privacy policy and compliance templates |
| `orbit/capture/PERMISSIONS.md` | macOS permission setup |

---

## Roadmap

| Phase | Status | Scope |
|-------|--------|-------|
| 1 — Context Foundation | **Done** | Capture daemon, SQLite store, hybrid search, universal AX |
| 2 — Kanban MVP | Planned | Orchestrator + retrieval, Kanban UI |
| 3 — Agent Execution | Planned | MCP integration, approval gates, audit log |
| 4 — Full Agent Fleet | Future | Code Agent (Docker), local LLM mode |
| SQLCipher encryption | Future | Encrypted context store at rest |
| Whisper / calendar / email | Future | Phase 4B/4C complementary sources |

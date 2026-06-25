# Orbit

Always-on agentic system for macOS. Captures your working context via the Accessibility API, detects tasks from that context, and dispatches them to an LLM agent — all without screenshots.

> *A mediocre model with perfect context outperforms a frontier model starting from zero every session.*

---

## What it does

1. **Capture** — Listens for app-focus events via `NSWorkspace`. On each switch, walks the active window's `AXUIElement` tree and stores structured text atoms (roles, labels, values) in SQLite.
2. **Embed** — A background worker embeds every stored atom with `all-MiniLM-L6-v2` and writes 384-dim float32 vectors to a `sqlite-vec` virtual table.
3. **Search** — Hybrid search fuses BM25 full-text and cosine-nearest-neighbour results via Reciprocal Rank Fusion (RRF). Returns ranked `Hit` objects with source app, window, timestamp, and snippet.
4. **Check** — Reads a context document (from GitHub or a local file), calls an LLM to detect 1–3 actionable tasks with confidence ≥ 0.7, presents them for approval, and dispatches approved tasks.
5. **Dispatch** — Streams the approved prompt through OpenRouter and saves the full output as a `.md` file in `mvp-output/`.

---

## Architecture

```
macOS OS events
    │
    ▼
AppFocusListener          (orbit/capture/listener.py)
    │  NSWorkspaceDidActivateApplicationNotification
    ▼
focus_queue (Queue)
    │
    ▼
capture_worker            (orbit/capture/worker.py)
    │  AXUIElement tree walk → flatten text atoms
    │  exclusion list enforced here (no-capture zones)
    ├──► SQLite context_events + text_atoms
    └──► embed_queue (Queue)
              │
              ▼
         embed_worker     (orbit/embed/worker.py)
              │  batch encode via sentence-transformers
              └──► sqlite-vec vec_atoms (384-dim embeddings)

orbit search <query>      (orbit/search/)
    └──► hybrid.py — BM25 + vec, RRF fusion → Hit[]

orbit check               (orbit/check/)
    ├── detector.py  — LLM detects tasks from context text
    ├── log.py       — SQLite cache: detected/skipped/done
    └── dispatch.py  — stream prompt → OpenRouter → mvp-output/*.md

orbit/ui/statusbar.py     macOS menu-bar icon (active/idle)
```

### Storage schema

| Table | Purpose |
|---|---|
| `context_events` | One row per app-focus event: app name, bundle ID, window title, timestamp |
| `text_atoms` | Extracted UI elements: role, label, text, linked to `context_events` |
| `vec_atoms` | sqlite-vec virtual table: 384-dim embeddings for `text_atoms` |
| `atoms_fts` | FTS5 virtual table: full-text index over `text_atoms` |
| `detected_tasks` | Task detection cache: title, description, prompt, agent type, status |

---

## Install

Requires macOS 14+, Python 3.10+, and Accessibility permission granted to Terminal (System Settings → Privacy & Security → Accessibility).

```bash
pip install -e .
```

---

## Usage

```bash
# Start the capture daemon (logs context to ~/.orbit/orbit.db)
orbit start

# Detect tasks from today's context and optionally dispatch one
orbit check

# Review tasks you previously skipped
orbit check skipped

# Dry-run: detect and print tasks without dispatching
orbit check --dry-run

# Use a local context file instead of GitHub
orbit check --source local --context path/to/context.md
```

---

## Dependencies

| Package | Role |
|---|---|
| `pyobjc-framework-Cocoa` | `NSWorkspace` app-focus events |
| `pyobjc-framework-ApplicationServices` | `AXUIElement` tree access |
| `sqlite-vec` | Vector similarity search inside SQLite |
| `sentence-transformers` | Local embeddings (`all-MiniLM-L6-v2`) |
| `openai` | OpenRouter-compatible client for task dispatch |

---

## Privacy

- No screenshots. Text only via the Accessibility API.
- All capture and embeddings stored locally in `~/.orbit/orbit.db`.
- No-capture zones enforced by app bundle ID before any data is written.
- Internet is off during capture; only used when `orbit check` dispatches an approved task.

---

## Roadmap

| Phase | Status | Scope |
|---|---|---|
| 1 — Context Foundation | **In progress** | Capture daemon, SQLite atom store, semantic search |
| 2 — Kanban MVP | Planned | Orchestrator LLM + retrieval, task Kanban UI |
| 3 — Agent Execution | Planned | MCP integration, Writing + Research agents, approval gates |
| 4 — Full Agent Fleet | Future | Code Agent (Docker), multi-agent coordination, local LLM mode |

# Orbit — Architecture Analysis

> **Repository:** [westsoever/orbit](https://github.com/westsoever/orbit) (private)
> **Analysed:** 2026-06-25

---

## What It Is

Orbit is a macOS-only, always-on AI context daemon. It silently watches what the user is working on by reading the macOS Accessibility Tree (AXUIElement API), stores captured UI context locally in SQLite, and builds a searchable memory — the foundation for an AI agent that can detect tasks and execute them under human approval.

**One-liner:** *"Always-on agent with context collection and task execution"*

---

## Data Flow (End-to-End)

```
App focus change
      │
      ▼
AppFocusListener          [capture/listener.py]
(NSWorkspace notifications)
      │
      ▼   focus_queue
capture-worker thread     [capture/worker.py]
      │
      ├── ax_walker.py    Walk macOS AXUIElement tree (in-process, no subprocess)
      │                   → up to 5,000 nodes, max depth 12
      ├── extract.py      Extract semantic text atoms (AXTextField, AXTextArea, etc.)
      ├── exclusions.py   Drop sensitive apps from exclusion list
      │
      ▼   SQLite write
context_events table      [app_bundle_id, window_title, visible_text, raw_json]
text_atoms table          [role, label, text, element_path, element_hash]
FTS5 index (atoms_fts)    [kept in sync via triggers]
      │
      ▼   embed_queue
embed-worker thread       [embed/worker.py]
      │
      ├── all-MiniLM-L6-v2   (sentence-transformers, 384-dim, local-first)
      ├── batch 32 atoms / 200ms flush
      │
      ▼   sqlite_vec write
vec_atoms table           [embedding float[384], cosine distance]
      │
      ▼
Search layer              [search/]
      ├── lexical.py      FTS5 full-text keyword search
      ├── semantic.py     Vector cosine similarity search
      └── hybrid.py       Combines both signals
```

---

## Module Map

| Module | Key Files | Role |
|---|---|---|
| `orbit/capture/` | `daemon.py`, `listener.py`, `ax_walker.py`, `worker.py`, `extract.py`, `exclusions.py` | Core capture pipeline |
| `orbit/storage/` | `schema.sql`, `db.py`, `writer.py`, `links.py` | SQLite persistence layer |
| `orbit/embed/` | `worker.py` | Async embedding pipeline |
| `orbit/search/` | `hybrid.py`, `lexical.py`, `semantic.py`, `links.py`, `types.py` | Retrieval layer |
| `orbit/ui/` | `statusbar.py` | macOS status bar (active / idle indicator) |
| `orbit/cli.py` | — | `orbit start` CLI entrypoint |
| `orbit_dashboard/` | — | Separate web/Electron dashboard (future MVP) |
| `scripts/` | `sanity_*.py`, `verify.sh` | Component sanity checks |
| `plans/` | `01-acceptance.md`, `01-content-collection.md` | Spec / planning docs |

---

## Database Schema

### `context_events`
Stores high-level UI capture events.

| Column | Type | Notes |
|---|---|---|
| `id` | INTEGER PK | Autoincrement |
| `timestamp` | TEXT | ISO timestamp |
| `app_bundle_id` | TEXT | e.g. `com.apple.Safari` |
| `app_name` | TEXT | Human-readable name |
| `window_title` | TEXT | Focused window title |
| `focused_element_role` | TEXT | AX role of focused element |
| `focused_element_label` | TEXT | AX label |
| `visible_text` | TEXT | Extracted visible text |
| `raw_json` | TEXT | Full AX tree snapshot |

### `text_atoms`
Granular text elements extracted from a context event.

| Column | Type | Notes |
|---|---|---|
| `id` | INTEGER PK | Autoincrement |
| `event_id` | INTEGER FK | → `context_events.id` (CASCADE) |
| `role` | TEXT | AX element role |
| `label` | TEXT | AX element label |
| `text` | TEXT | Extracted text content |
| `element_path` | TEXT | Path in the AX hierarchy |
| `element_hash` | TEXT | Dedup hash |

### `atoms_fts` (FTS5 virtual table)
Full-text search index over `text_atoms.text`, kept in sync by INSERT/DELETE/UPDATE triggers.  
Tokenizer: `unicode61 remove_diacritics 2`

### `vec_atoms` (vec0 virtual table)
Vector store: `embedding float[384]`, cosine distance. Populated by the embed worker.

---

## Key Technical Decisions

| Decision | Rationale |
|---|---|
| **PyObjC in-process** (not `macapptree` subprocess) | Avoids focus theft and subprocess overhead |
| **SQLite + sqlite_vec** for everything | Local-first, no external vector DB, single file |
| **FTS5 + vec0 hybrid search** | Combines keyword recall with semantic understanding |
| **Two daemon threads** via queues | `capture-worker` + `embed-worker`, graceful shutdown via `None` sentinel |
| **`--no-embed` flag** | Run capture without embedding for faster debugging |
| **Privacy by design** | Text-only (no screenshots), app exclusion list, OS keychain + SQLCipher encryption planned |

---

## Capture Loop Detail

`ax_walker.py` — in-process macOS AX tree walker:
- Targets a process by PID; prioritises `AXFocusedWindow`, falls back to first in `AXWindows`
- Recursive `_walk()` with max 5,000 nodes and depth 12 to prevent runaway on complex elements (e.g. `AXWebArea`)
- `_coerce_scalar()` filters to plain text payloads only (str, int, float, bool); discards `AXValueRef`, `CFArray`, etc.
- Returns a nested dict: `{ role, name, value, description, role_description, id, children[] }`

---

## Embedding Pipeline Detail

`embed/worker.py` — background thread:
- Model: `sentence-transformers/all-MiniLM-L6-v2` (384 dimensions), loaded local-first
- Thread-safe singleton via `_MODEL_LOCK`
- Batches: up to 32 atoms per batch, 200ms flush deadline
- Serialises vectors via `sqlite_vec.serialize_float32` before writing to `vec_atoms`
- Termination signal: `None` in the queue

---

## Tech Stack

| Layer | Technology |
|---|---|
| Language | Python + PyObjC |
| macOS integration | `AXUIElement` via `ApplicationServices` framework |
| Storage | SQLite (append-only, thread-safe) |
| Full-text search | SQLite FTS5 |
| Vector search | `sqlite-vec` (vec0 extension) |
| Embeddings | `sentence-transformers/all-MiniLM-L6-v2` (local) |
| LLM (planned) | Claude Sonnet 4 (cloud POC) → Llama 3.3 70B (local privacy mode) |
| Agent framework | LangGraph or custom ReAct loop (planned) |
| Dashboard UI | React + Electron or localhost web app (planned) |
| macOS event loop | `PyObjCTools.AppHelper.runConsoleEventLoop` |

---

## Roadmap Status

| Phase | Status | Description |
|---|---|---|
| **1 — Context Foundation** | ✅ Active (POC working) | Capture daemon, SQLite atom store, FTS5 + vector search |
| **2 — Kanban MVP** | Planned | Task detection from context, Kanban board UI |
| **3 — Agent Execution** | Planned | MCP integration, Writing/Research agents |
| **4 — Full Agent Fleet** | Planned | Code agent in Docker, multi-agent coordination |
| **5 — Polish & Scale** | Planned | Mobile companion, plugin system |

---

## POC Success Criteria

> One real task detected from context, approved by user, completed by an agent, with an auditable log entry. UX: CLI prompt for approval (Kanban UI is later MVP scope).

---

## Security & Privacy Constraints

- No screenshots by default (text-only capture)
- Local-first storage; encrypted with OS keychain + SQLCipher (planned)
- App exclusion list for sensitive apps (password managers, banking, etc.)
- Event-driven, not polling
- Two human approval gates: plan approval and ambiguity unblocking
- Hyper-ephemeral permissions per task
- Internet OFF by default; Code Agent runs in Docker/devcontainer
- External content treated as untrusted data
- Approval-fatigue budget: 2–5 high-quality requests per day

---

## Reference Links

- [MacPaw macapptree](https://github.com/MacPaw/macapptree) — inspiration for AX tree capture
- [macOS-MCP (CursorTouch)](https://github.com/CursorTouch/MacOS-MCP)
- [Screenpipe](https://github.com/screenpipe/screenpipe)
- [Apple Accessibility API docs](https://developer.apple.com/library/archive/documentation/Accessibility/Conceptual/AccessibilityMacOSX/)
- [Fazm AI Mac Agent](https://fazm.ai/blog/fazm-ai-mac-agent)

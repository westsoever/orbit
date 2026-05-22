# Orbit — Agent Context Brief
*Generated: May 2026. Inject this into a new agent session to continue building Orbit.*

---

## What Is Orbit

**Orbit** is an Always-On Agentic System for macOS. It continuously captures the user's working context (without screenshots), builds a structured memory of tasks and activity, maintains an AI-managed Kanban board, and spawns typed sub-agents to autonomously complete work — all under strict human approval gates.

Core design principle: *a mediocre model with perfect context outperforms a frontier model starting from zero every session.*

**Target user:** Startup founders and executives managing high-context, multi-project work.
**Business model:** Freemium + Pro tier.
**Team status:** Solo founder, pre-funding.

---

## Architecture Overview (Three Planes)

### 1. Perception & Context Capture
- Event-driven capture triggered by OS-level events (window focus, mouse clicks, keyboard activity) — NOT polling
- **No screenshots.** Uses macOS Accessibility Tree API for structured text capture (element roles, labels, values, window titles, app names)
- Local Whisper model for real-time audio/meeting transcription
- File system indexing via FSEvents (macOS)
- Browser history/tab tracking via accessibility API or browser extension
- Email + calendar via local IMAP/CalDAV sync
- Selective no-capture zones (banking apps, password managers, etc.)
- All data stays on-device. No raw data leaves the machine. Context store encrypted with OS keychain + SQLCipher.

### 2. Cognition & Orchestration
- Five-layer memory: Immediate (last 15 min) → Working (hourly summaries) → Episodic (vector-retrieved) → Semantic (entity graph) → Archived (compressed daily)
- Automated task detection from context stream (verbal commitments in meeting transcripts become task cards)
- Project clustering via semantic similarity and entity co-occurrence
- Dynamic context payload assembly (pulls only relevant context at reasoning time)
- Target: 2–5 high-quality approval requests per day (no approval fatigue)

### 3. Human-in-the-Loop Oversight
- Dual approval gates: (1) approve the plan before execution; (2) unblock the agent if it hits ambiguity or irreversible action mid-task
- Local Kanban board (React + Electron or localhost web app) as the full control surface
- Each task card shows exact permissions/resources required before approval

### 4. Agent Execution
- Six typed sub-agent profiles: Writing, Research, Code, Admin, Data, Communication
- ReAct loop: Reason → Act → Observe → Update State → Check (state written to file after every action for resumability)
- MCP (Model Context Protocol) as the standard execution bridge between Orchestrator and all tools
- Code Agent runs inside Docker/devcontainer — never directly on host

### 5. Security
- Hyper-ephemeral permissions: granted per task, scoped to minimum resources, revoked on completion
- Internet OFF by default; explicitly enabled per task
- All external content treated as untrusted data (never as instructions)

---

## Technology Stack

| Component | Technology |
|---|---|
| **Context capture (macOS)** | macOS Accessibility Tree API (AXUIElement) via `pyobjc` or Swift |
| **Audio transcription** | Whisper (local, quantised) |
| **Vector database** | LanceDB or ChromaDB (embedded, no separate server) |
| **Knowledge graph** | SQLite + custom entity graph |
| **Orchestrator LLM** | Claude Sonnet 4 (cloud) or Llama 3.3 70B (local/privacy mode) |
| **Agent framework** | LangGraph or custom ReAct loop |
| **MCP servers** | Official MCP servers + custom (file system, browser, calendar, terminal) |
| **Kanban UI** | React + Electron or localhost web app |
| **Encryption** | OS keychain + SQLCipher |
| **File system events** | FSEvents (macOS) / inotify (Linux) |

**Minimum hardware:** Apple M2, 16 GB RAM (cloud LLM mode), 256 GB SSD, macOS 14+
**Recommended:** Apple M3 Pro+, 32–64 GB RAM (local LLM mode), 1 TB+ NVMe SSD

---

## POC Scope — What to Build First

**Chosen POC goal:** Validate the end-to-end agent loop before building the full capture stack.

The POC has two sequential parts:

**Part 1 — Context capture (prerequisite)**
Build a minimal, structured context capture daemon using the macOS Accessibility API. This replaces screenshot-based tools. The daemon should:
- Trigger on OS-level events (app focus change, window switch) using `NSWorkspace` notifications
- Query the active application's accessibility tree via `AXUIElement`
- Extract: active app name, window title, focused element role/label/value, visible text fields
- Log structured JSON events to SQLite (no images, no OCR)
- Support a no-capture exclusion list (app bundle IDs)

**Part 2 — Agent loop**
Wire the context log to a single agent that:
- Reads recent context events
- Proposes one task (e.g. "Draft a follow-up email based on this meeting note")
- Presents it to the user for approval via a minimal UI (even a CLI prompt is fine for POC)
- On approval, executes via an MCP tool (e.g. write a file, create a draft)
- Logs the result

Success criteria for the POC: one real task, detected from real context, approved by the user, completed by an agent, with an auditable log entry.

---

## macapptree Clone — Immediate Build Target

The first thing to build is a lightweight macOS accessibility tree capture daemon, functionally equivalent to [macapptree by MacPaw](https://github.com/MacPaw/macapptree) but tailored for Orbit's event-driven, always-on use case.

### What macapptree does
Python package that queries the macOS accessibility tree for any running application and returns the full UI structure as JSON (element roles, labels, values, hierarchy). No screenshots.

### What the Orbit capture daemon needs to do differently
- **Always-on, event-driven** — not queried on demand, but triggered by OS events
- **Filtered output** — only capture semantically useful elements (text fields, document content, button labels, window titles); skip decorative/structural UI elements
- **Append-only context log** — each capture event writes a structured record to SQLite with timestamp, app bundle ID, window title, and extracted text atoms
- **No-capture zones** — skip capture entirely for excluded app bundle IDs
- **Low CPU footprint** — event-driven, not polling; sleep between events

### Recommended implementation approach

**Option A — Python + pyobjc (fastest to prototype)**
```
# Key libraries:
# - pyobjc-framework-Cocoa (NSWorkspace for app focus events)
# - pyobjc-framework-ApplicationServices (AXUIElement for accessibility tree)
# - sqlite3 (context log)
```
Listen for `NSWorkspaceDidActivateApplicationNotification`, then walk the AXUIElement tree of the newly focused app. Extract `AXValue`, `AXTitle`, `AXDescription` attributes from relevant element roles (`AXTextField`, `AXTextArea`, `AXStaticText`, `AXDocument`, `AXWebArea`). Write a JSON record to SQLite.

**Option B — Swift daemon (better for production)**
Use `NSWorkspace.shared.notificationCenter` + `AXObserver` + `AXUIElementCopyAttributeValue`. Compile as a lightweight background process. Expose a simple local HTTP or Unix socket API for the Python Orchestrator to query context.

For the POC, start with Option A (Python + pyobjc). It's faster to iterate and easier to wire to LangGraph or a simple Claude API call.

### SQLite schema for context log
```sql
CREATE TABLE context_events (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  timestamp TEXT NOT NULL,
  app_bundle_id TEXT,
  app_name TEXT,
  window_title TEXT,
  focused_element_role TEXT,
  focused_element_label TEXT,
  visible_text TEXT,
  raw_json TEXT
);
```

---

## Key Decisions Made

| Decision | Choice | Rationale |
|---|---|---|
| Capture method | Accessibility API, NOT screenshots | Lower storage, structured data, privacy-preserving, matches LittleBird.ai's proven approach |
| Screenpipe | Use open-source core (MIT, free on GitHub) OR build custom daemon | $400 is for their commercial app; core is free. Custom daemon preferred for Accessibility API approach |
| Initial platform | macOS only | Accessibility Tree API is macOS-native; Windows/Linux require different APIs (Phase 2+) |
| Context capture tier | Text-only (Accessibility API) by default; screenshot as opt-in "enhanced mode" | Lowest privacy risk at launch; richer context available later |
| LLM | Claude Sonnet 4 (cloud) for POC | Local Ollama fallback in later phases for privacy mode |
| MCP | Core execution bridge from Day 1 | Deterministic local commands, audit logging, permission enforcement at tool layer |
| Agent approval UX | CLI prompt for POC → Kanban board for MVP | Fastest to validate the approval model before investing in UI |

---

## Competitive Context

**LittleBird.ai** (main comparable): macOS-only, Accessibility Tree API, text-only (no screenshots), stores on AWS cloud. Raised seed March 2026. **No patents filed.** Orbit differentiates on local-first storage, richer context (audio + optional screenshots), and agent execution layer (LittleBird.ai captures context but does not act).

**Microsoft Recall**: Screenshot-based. Cloud-processed. Strong privacy concerns. Orbit's text-only default is a direct response to this approach.

**Rewind.ai**: Screenshot + audio, cloud storage. Screenpipe is the open-source alternative to Rewind.

---

## Development Roadmap (from source plan)

| Phase | Timeline | Deliverables |
|---|---|---|
| Phase 1 — Context Foundation | Months 1–3 | Accessibility API capture daemon, context atom store (LanceDB + SQLite), entity extraction, semantic search, daily summaries |
| Phase 2 — Kanban MVP | Months 3–5 | Orchestrator LLM + context retrieval, task detection, basic Kanban UI (React/Electron), manual task creation |
| Phase 3 — Agent Execution | Months 5–8 | MCP server integration, Writing + Research Agents, approval gate enforcement, audit log |
| Phase 4 — Full Agent Fleet | Months 8–12 | Code Agent (Docker sandbox), Data + Admin Agents, multi-agent coordination, local LLM privacy mode |
| Phase 5 — Polish & Scale | Months 12+ | Confidence calibration, mobile companion, team/shared context mode, plugin system |

---

## Useful References

- [macapptree (MacPaw)](https://github.com/MacPaw/macapptree) — Python accessibility tree extractor, closest existing open-source analogue
- [macOS-MCP (CursorTouch)](https://github.com/CursorTouch/MacOS-MCP) — MCP server using macOS Accessibility API; useful for agent execution layer
- [screenpipe (open source core)](https://github.com/screenpipe/screenpipe) — MIT-licensed, free; screenshot + OCR + audio; reference for event-driven capture architecture even if not used directly
- [Apple Accessibility API docs](https://developer.apple.com/library/archive/documentation/Accessibility/Conceptual/AccessibilityMacOSX/)
- [Fazm AI Mac Agent](https://fazm.ai/blog/fazm-ai-mac-agent) — open-source agent that reads accessibility tree instead of screenshotting; study their data model

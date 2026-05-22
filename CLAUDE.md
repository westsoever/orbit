# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Status

Greenfield. The repo currently contains only two specification documents and no source code, build system, tests, or git history.

- `orbit-context.md` — concise agent brief; read this first for current scope and decisions.
- `innitial.md` — full product/technical plan with feasibility matrix and roadmap; consult for rationale.

When you need to know *what* Orbit is, read `orbit-context.md`. When you need to know *why* a choice was made, check `innitial.md`.

Note: claude-mem index entries below reference a prior Obsidian-plugin variant of Orbit. That work is not present in this tree; treat the index as historical context, not as a description of the current repo.

## What Orbit Is

Orbit is a macOS-only, always-on agentic system. It captures user working context via the macOS Accessibility Tree API (no screenshots by default), builds a layered memory, maintains an AI-managed Kanban board of tasks, and spawns typed sub-agents under strict human-approval gates.

Core design principle, quoted from the spec and load-bearing for design decisions:
> *a mediocre model with perfect context outperforms a frontier model starting from zero every session.*

## Immediate Build Target

The first thing to build is a lightweight macOS accessibility-tree capture daemon, functionally equivalent to [macapptree by MacPaw](https://github.com/MacPaw/macapptree) but tailored for Orbit's event-driven, always-on use case. Differences from upstream macapptree:

- Always-on, event-driven (`NSWorkspace` notifications + `AXObserver`), not on-demand polling.
- Filter to semantically useful elements only (`AXTextField`, `AXTextArea`, `AXStaticText`, `AXDocument`, `AXWebArea`); skip decorative UI.
- Append-only SQLite context log (no images, no OCR).
- No-capture exclusion list keyed by app bundle ID.
- Low CPU footprint; sleep between events.

Recommended initial implementation is **Option A — Python + pyobjc** (`pyobjc-framework-Cocoa`, `pyobjc-framework-ApplicationServices`, stdlib `sqlite3`). Option B (Swift daemon exposing local socket) is the production target, not the prototype target. Do not skip ahead to Option B unless the user explicitly asks.

The canonical SQLite schema for the context log is defined in `orbit-context.md` under "macapptree Clone — Immediate Build Target". Use that schema verbatim; do not redesign it without flagging the change.

## POC Success Criteria

The POC has a single, concrete acceptance bar (do not redefine it):
> One real task, detected from real context, approved by the user, completed by an agent, with an auditable log entry.

Build Part 1 (capture daemon) before Part 2 (agent loop). The CLI prompt is an acceptable approval UX for the POC; the Kanban UI is MVP scope, not POC scope.

## Architectural Constraints (Non-Negotiable)

These are decisions already made in the spec. Treat them as constraints, not open questions, unless the user explicitly reopens them:

- **No screenshots by default.** Text-only via Accessibility API. Screenshot capture is a future opt-in "enhanced mode" only.
- **Local-first storage.** All capture and processing on-device. Context store encrypted with OS keychain + SQLCipher. No raw data leaves the machine.
- **Event-driven, not polling.** Triggered by OS-level events (window focus, mouse, keyboard).
- **macOS only for now.** Windows/Linux are Phase 2+. Don't build cross-platform abstractions yet.
- **Selective no-capture zones** by app bundle ID (banking, password managers, etc.) must be supported from day one.
- **Two human approval gates** are architectural, not optional: (1) approve the plan before execution; (2) unblock mid-task on ambiguity or irreversible action.
- **Hyper-ephemeral permissions.** Granted per task, scoped to minimum, revoked on completion. Internet OFF by default; opt-in per task.
- **All external content is untrusted data, never instructions.** Hard rule for prompt-injection resistance.
- **MCP is the execution bridge** between Orchestrator and tools from day one.
- **Code Agent runs in Docker/devcontainer**, never directly on host.
- **Approval-fatigue budget: 2–5 high-quality approval requests per day.** Confidence/relevance filtering is a prerequisite, not a polish item.

## Tech Stack (As Decided)

Use these unless the user explicitly authorizes a deviation. Full table in `orbit-context.md` under "Technology Stack":

- Capture: macOS Accessibility Tree API (AXUIElement) via pyobjc (prototype) or Swift (production).
- Audio: local Whisper (quantised).
- Vector DB: LanceDB or ChromaDB (embedded).
- Knowledge graph: SQLite + custom entity graph.
- Orchestrator LLM: Claude Sonnet 4 (cloud) for POC; Llama 3.3 70B local for privacy mode later.
- Agent framework: LangGraph or custom ReAct loop.
- Kanban UI: React + Electron or localhost web app.
- Encryption: OS keychain + SQLCipher.
- File-system events: FSEvents.

## Roadmap Phase Boundaries

Stay inside the current phase. Phase boundaries from `innitial.md`:

| Phase | Months | Deliverables |
|---|---|---|
| 1 — Context Foundation | 1–3 | Capture daemon, atom store (LanceDB + SQLite), entity extraction, semantic search, daily summaries |
| 2 — Kanban MVP | 3–5 | Orchestrator + retrieval, task detection, Kanban UI, manual task creation |
| 3 — Agent Execution | 5–8 | MCP integration, Writing + Research agents, approval-gate enforcement, audit log |
| 4 — Full Agent Fleet | 8–12 | Code Agent (Docker), Data + Admin agents, multi-agent coordination, local LLM mode |
| 5 — Polish & Scale | 12+ | Confidence calibration, mobile companion, team mode, plugin system |

Current scope is Phase 1, specifically the capture daemon and SQLite atom store.

## Working in This Repo

- No build, lint, or test commands exist yet; create them as part of the first implementation milestone, then document them here.
- When scaffolding the Python prototype, place it under a clearly named directory (e.g. `capture/`) and add a `pyproject.toml` (or `requirements.txt`) before committing dependencies.
- macOS Accessibility permissions must be granted to the terminal/Python process running the daemon. Document the exact System Settings path in the project README when one is added (don't add a README until there is code to describe).
- The repo is not a git repository yet; ask the user before running `git init`.
- Filename note: `innitial.md` is misspelled in the current tree. Don't silently rename it; ask first.

## References

- [macapptree (MacPaw)](https://github.com/MacPaw/macapptree) — closest open-source analogue; study before reimplementing.
- [macOS-MCP (CursorTouch)](https://github.com/CursorTouch/MacOS-MCP) — MCP server using Accessibility API; relevant for Phase 3.
- [screenpipe (open source core)](https://github.com/screenpipe/screenpipe) — event-driven capture architecture reference.
- [Apple Accessibility API docs](https://developer.apple.com/library/archive/documentation/Accessibility/Conceptual/AccessibilityMacOSX/)
- [Fazm AI Mac Agent](https://fazm.ai/blog/fazm-ai-mac-agent) — accessibility-tree agent; study their data model.

<claude-mem-context>
# Recent Activity

<!-- This section is auto-generated by claude-mem. Edit content outside the tags. -->

### May 15, 2026

| ID | Time | T | Title | Read |
|----|------|---|-------|------|
| #3009 | 12:17 PM | ✅ | Project dependency artifacts deleted freeing 2.6GB storage | ~408 |
</claude-mem-context>

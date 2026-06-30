---
name: memtrace-graph
description: "Always use for source-code architecture, important symbols, centrality, PageRank, bridge functions, communities, logical modules, chokepoints, service boundaries, or dependency path questions. Do not use Glob, find, tree, or directory browsing to infer architecture; Memtrace runs graph algorithms over the AST graph."
---


## Overview

Graph algorithms that reveal the structural architecture of a codebase — community detection (Louvain), centrality ranking (PageRank), bridge symbol identification (Tarjan articulation points), shortest-path discovery, and execution flow tracing.

All four algorithm tools (`find_central_symbols`, `find_bridge_symbols`, `find_dependency_path`, `list_communities`) run natively against the MemDB-backed knowledge graph — no Cypher required.

## Quick Reference

| Tool | Purpose |
|------|---------|
| `find_bridge_symbols` | Architectural chokepoints — symbols whose removal disconnects the graph (Tarjan articulation points) |
| `find_central_symbols` | Most important symbols by **PageRank** (default) or degree centrality |
| `find_dependency_path` | Shortest call/import path between two symbols (BFS over typed edges) |
| `list_communities` | Louvain-detected logical modules/services |
| `list_processes` | Execution flows: HTTP handlers, background jobs, CLI commands, event handlers |
| `get_process_flow` | Trace a single process step-by-step |

## Steps

### 1. Understand the architecture

Start with `list_communities` to see how the codebase is naturally partitioned into logical modules. Each community has a name, member count, and representative symbols.

### 2. Find critical infrastructure

Use `find_central_symbols` to identify the most important symbols:
- `method: "pagerank"` — importance by link structure (default; same algorithm Google uses)
- `method: "degree"` — importance by direct connection count
- `limit` — how many to return

The PageRank pass walks every CALLS / REFERENCES edge in the repo, distributes rank with the standard 0.85 damping factor, and converges on a stable ordering. The output is sorted by score descending, with each entry carrying `name`, `kind`, `file_path`, `score`, and the `in_degree`/`out_degree` it accumulated during the walk.

### 3. Find architectural chokepoints

Use `find_bridge_symbols` to find symbols that, if removed, would disconnect parts of the graph (Tarjan articulation points). These are:
- **Single points of failure** — if they break, cascading failures occur
- **Integration points** — good places for interfaces/contracts
- **Refactoring targets** — often too much responsibility concentrated in one place

### 4. Discover the path between two symbols

Use `find_dependency_path` to answer "how does symbol A reach symbol B?" — returns the shortest call/import chain via BFS over typed edges. Useful for:
- "Why does the auth handler depend on the database client?"
- "How does this CLI command reach the logging subsystem?"
- "Confirm symbol X actually transitively depends on Y."

### 5. Trace execution flows

Use `list_processes` to see all entry points (HTTP handlers, background jobs, CLI commands, event handlers).

Use `get_process_flow` with a process name to trace a specific flow step-by-step — shows the full call chain from entry point through business logic to data access, ordered by the indexed `step` property on each STEP_IN_PROCESS edge.

## Decision Points

| Question | Tool |
|----------|------|
| "What are the main modules?" | `list_communities` |
| "What are the most important functions?" | `find_central_symbols` with method=pagerank |
| "Where are the bottlenecks?" | `find_bridge_symbols` |
| "How does symbol A reach symbol B?" | `find_dependency_path` |
| "How does a request flow through the system?" | `list_processes` → `get_process_flow` |
| "What's the entry point for feature X?" | `list_processes`, then filter by name |

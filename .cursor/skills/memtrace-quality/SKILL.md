---
name: memtrace-quality
description: "Always use for source-code quality, dead code, unused functions, zero callers, complexity, cyclomatic complexity, hotspots, refactoring candidates, or code smell questions. Do not use Grep, Glob, rg, or manual reference search for unused code; Memtrace uses graph reachability and complexity metrics."
---


## Overview

Identify code quality issues using structural graph analysis — dead code (zero callers), complexity hotspots (high out-degree), and repository-wide statistics.

## Quick Reference

| Tool | Purpose |
|------|---------|
| `find_dead_code` | Symbols with zero callers (potentially unused) |
| `calculate_cyclomatic_complexity` | Complexity score for a specific symbol |
| `find_most_complex_functions` | Top-N functions by complexity across the repo |
| `get_repository_stats` | Repo-wide counts: nodes, edges, communities, processes |

> **Parameter types:** MCP parameters are strictly typed. Numbers (`limit`, `depth`, `min_size`, `last_n`, etc.) must be JSON numbers — not strings. Use `limit: 20`, never `limit: "20"`. Passing a string yields `MCP error -32602: invalid type: string, expected usize`.


## Steps

### 1. Get repository overview

Use `get_repository_stats` to understand the codebase scale:
- Node counts by kind (functions, classes, methods, interfaces)
- Edge counts (calls, imports, extends, type references)
- Community and process counts

### 2. Find dead code

Use `find_dead_code`:
- `repo_id` — required
- `include_tests` — set true to also flag unused test helpers (default false)

**Note:** Exported symbols and entry points are excluded by default — the tool won't flag public APIs as "dead" just because they're called externally.

### 3. Find complexity hotspots

Use `find_most_complex_functions`:
- `repo_id` — required
- `limit` — how many to return (default 10)

Complexity scoring (based on out-degree — number of callees):
| Score | Rating | Action |
|-------|--------|--------|
| < 5 | Low | No action needed |
| 5–10 | Medium | Monitor; consider splitting if growing |
| 10–20 | High | Refactoring candidate; extract helper functions |
| > 20 | Critical | Immediate attention; this function does too much |

### 4. Drill into specific functions

Use `calculate_cyclomatic_complexity` on specific symbols flagged by the user or found in step 3.

## Common Mistakes

| Mistake | Reality |
|---------|---------|
| Treating all dead code as deletable | Some "dead" code is called via reflection, dynamic dispatch, or external consumers |
| Ignoring exported symbols in dead code results | If `include_tests: false`, exported symbols are already excluded |
| Only looking at the highest complexity | Medium-complexity functions that are growing (check `get_evolution`) are often more urgent |

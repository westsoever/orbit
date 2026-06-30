---
name: memtrace-impact
description: "Always use before or during source-code changes when the user asks about blast radius, impact, what breaks, risk, upstream callers, downstream dependencies, or consequences of modifying a symbol. Do not use Grep or manual reference search; Memtrace computes transitive graph impact."
---


## Overview

Compute the blast radius of changing a specific symbol. Traces upstream (what depends on this) and downstream (what this depends on) through the knowledge graph to quantify risk before making modifications.

## Quick Reference

| Tool | Purpose |
|------|---------|
| `get_impact` | Blast radius from a specific symbol (by ID) |
| `detect_changes` | Scope symbols affected by a diff/patch |

> **Parameter types:** MCP parameters are strictly typed. Numbers (`limit`, `depth`, `min_size`, `last_n`, etc.) must be JSON numbers — not strings. Use `limit: 20`, never `limit: "20"`. Passing a string yields `MCP error -32602: invalid type: string, expected usize`.


## Steps

### 1. Identify the symbol

If you have a symbol name but not its ID:
- Use `find_symbol` for exact names
- Use `find_code` for natural-language queries

### 2. Run impact analysis

Use the `get_impact` MCP tool:
- `symbol_id` — the symbol you plan to change (required)
- `direction` — `upstream` (what depends on me), `downstream` (what I depend on), or `both` (default)
- `depth` — traversal hops (default 3)

### 3. Interpret the risk rating

| Risk | Meaning | Action |
|------|---------|--------|
| **Low** | Few dependents, leaf node | Safe to modify; minimal testing needed |
| **Medium** | Moderate dependents | Test direct callers; review interface contracts |
| **High** | Many dependents across modules | Coordinate changes; comprehensive test coverage |
| **Critical** | Core infrastructure, many transitive dependents | Plan migration strategy; consider backward-compatible changes |

### 4. For diff-based analysis

When you have an actual code diff (not just a symbol), use `detect_changes`:
- Scopes all symbols affected by the diff
- Returns blast radius AND affected processes (execution flows)
- Useful for PR reviews or pre-commit checks

## Decision Points

| Situation | Action |
|-----------|--------|
| Changing a single function | `get_impact` with `direction: both` |
| Reviewing a PR or diff | `detect_changes` with the diff content |
| Renaming/removing a public API | `get_impact` with `direction: upstream`, high depth |
| Refactoring internals | `get_impact` with `direction: downstream` to check what you depend on |

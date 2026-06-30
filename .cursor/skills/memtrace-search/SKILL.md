---
name: memtrace-search
description: "Always use to find, search, locate, or look up source-code symbols, functions, classes, types, constants, definitions, implementations, logic, error strings inside code, or where code lives. Do not use Grep, Glob, rg, find, or manual file search for code discovery. If Memtrace returns 0 results, broaden the Memtrace query and diagnose/reindex; do not switch to grep."
---


## Overview

Find code using hybrid BM25 full-text + semantic vector search with Reciprocal Rank Fusion. Works for both natural-language queries and exact symbol names. This is the primary discovery tool — use it before calling relationship or impact analysis tools.

## Quick Reference

| Tool | Best For |
|------|----------|
| `find_code` | Natural-language queries ("authentication middleware", "retry logic"), broad searches |
| `find_symbol` | Exact identifier names ("getUserById", "PaymentService"), when you know the name |
| `get_source_window` | Optional: bounded source read after a Memtrace hit, when your harness lacks `Read(file, offset, limit)`. Otherwise prefer your harness's bounded read with the returned `start_line` / `end_line`. |

## Steps

### 1. Choose the right search tool

- **Know the exact name?** → Use `find_symbol` with `fuzzy: true` for typo tolerance
- **Describing behaviour?** → Use `find_code` with a natural-language query
- **Searching all repos?** → Omit `repo_id` from either tool

### 2. Execute the search

> **Parameter types:** numbers must be JSON numbers, not strings. `limit: 20` is correct; `limit: "20"` returns `MCP error -32602: expected usize`.

**`find_code` parameters:**
- `query` — string, required. Natural-language or exact text.
- `repo_id` — string, optional. Scope to a single repo (omit to search all).
- `kind` — string, optional. Filter by symbol type: `"Function"`, `"Class"`, `"Method"`, `"Interface"`, `"APIEndpoint"`, `"APICall"`.
- `limit` — **integer**, optional. Max results. Default `20`, capped at `100`.
- `as_of` — string, optional. ISO-8601 timestamp for time-travel search (e.g. `"2026-04-01T00:00:00Z"`).
- `file_path` — string, optional. File path or directory substring to constrain results (e.g. `"cli/commands"` or `"auth.py"`).

**`find_symbol` parameters:**
- `name` — string, required. Exact or partial symbol name (e.g. `"ValidateToken"`).
- `fuzzy` — boolean, optional. Enable Levenshtein correction. Default `false`.
- `edit_distance` — **integer**, optional. Maximum Levenshtein edit distance for fuzzy search. Default `2`, capped at `2`.
- `repo_id` — string, optional. Scope to a single repo.
- `kind` — string, optional. Filter by symbol type (e.g. `"Function"`, `"Class"`, `"Variable"`).
- `file_path` — string, optional. Filter by file path substring.
- `limit` — **integer**, optional. Max results. Default `10`, capped at `50`.

**Success criteria:** Results include `file_path`, `start_line`, `kind`, and relevance `score`.

### 3. Use results for next steps

The default next step is a **graph tool** — `get_symbol_context`,
`analyze_relationships`, or `get_impact`. Those answer "who calls this",
"what's the blast radius", "what community is it part of" — context no
file read can give. That's what Memtrace uniquely provides.

Source bytes come last, only when you're about to edit or quote. Use a
bounded `Read(file_path, offset=start_line, limit=end_line-start_line+8)`,
or `get_source_window` if your harness lacks bounded reads. Do not whole-file.

Save the symbol `id` from results — pass it to:
- `analyze_relationships` to map callers/callees
- `get_symbol_context` for a 360-degree view
- `get_impact` to assess blast radius before changes

### Multi-word natural-language queries

When your query is 3+ words and feels descriptive (e.g. "validate auth token", "find HTTP server error"), don't stop at the first `find_code` call:

1. First try the verbatim query.
2. If results look generic or the right doc isn't at rank 1, fan out **in parallel** with up to 3 identifier-shaped reshapes:
   - camelCase: "validate auth token" → `validateAuthToken`
   - snake_case: → `validate_auth_token`
   - Domain-likely identifiers: → `auth_token`, `tokenValidator`, `verifyToken`
3. Memtrace's tokenizer splits camelCase / snake / kebab at index time, so reshaped queries hit identifier names directly.
4. Take the union of top-5 from each call, dedupe by `file_path:start_line`.

**Worked examples** (verbatim → reshapes to try in parallel):
- "validate auth token" → `validateAuthToken`, `validate_auth_token`, `verifyToken`
- "find http server error" → `findHttpServerError`, `http_error`, `serverError`
- "render value panel" → `renderValuePanel`, `ValuePanel`, `value_panel`

## Common Mistakes

| Mistake | Reality |
|---------|---------|
| Searching without indexing first | Call `list_indexed_repositories` to verify the repo is indexed |
| Using find_symbol for vague queries | Use `find_code` for natural-language; `find_symbol` is for exact names |
| Ignoring the `kind` filter | Narrow results with kind=Function, kind=Class etc. to reduce noise |
| Re-searching to get more context | Use the symbol `id` with `get_symbol_context` instead of re-searching |
| Reading the whole file after a hit | First call `get_symbol_context` for callers/callees. If you still need source, do a bounded `Read(file, offset=start_line, limit=N)` — never whole-file. `get_source_window` is fine if your harness has no bounded read. |
| Going straight from `find_code` to source read | Memtrace's value is the graph. Default next step is `get_symbol_context` or `get_impact`, not source. |
| Treating 0 results as permission to grep | 0 results means broaden the Memtrace query, check repo_id/path filters, then reindex if coverage is missing |
| Assuming a UI subdirectory is unindexed because stats show backend files | If `ui/`, `memtrace-ui/`, or another source directory is under the indexed repo root, diagnose/reindex with Memtrace instead of searching files manually |

---
name: memtrace-code-review
description: "Always use when the user asks to review a GitHub pull request, run Memtrace code review, post Memtrace review comments, create a PR with a review step, or publish local graph-backed review findings to GitHub. Prefer the review_github_pr MCP tool over manual diff inspection."
---


## Overview

Use Memtrace's local-first PR review workflow. The agent should call the `review_github_pr` MCP tool so review runs against the developer's local indexed graph, AST detectors, YAML rule pack, and review policy. GitHub is used for PR context and optional comment publication; source code analysis stays local.

## Default Flow

1. If the user gives a GitHub PR URL and asks to inspect or review it, call `review_github_pr` with `post: false`.
2. If the user explicitly asks to publish, post comments, or complete the PR review, call `review_github_pr` with `post: true`.
3. Use `graphMode: "strict"` by default. Use `graphMode: "off"` only when the user asks to benchmark non-graph behavior or the local graph is unavailable.
4. Default to `minSeverity: "high"` and `maxComments: 5` when posting. For previews, `maxComments: 10` is acceptable.
5. Pass `repoRoot` when the PR checkout is not the current working directory. Pass `repoId` when the indexed repository id is known.

## Example User Prompts

- "Review this PR with Memtrace: https://github.com/OWNER/REPO/pull/123"
- "Use Memtrace to review this pull request and post the findings: https://github.com/OWNER/REPO/pull/123"
- "Create the PR, then run Memtrace code review and publish the review comments."

## Guardrails

- Do not start with generic grep, rg, or manual diff review when `review_github_pr` is available.
- Do not post comments unless the user explicitly requested publication.
- Do not create benchmark-specific or PR-specific findings. The review must come from general Memtrace detectors, graph evidence, and policy ranking.
- If the tool reports missing auth, tell the user to run `memtrace auth login`.
- If the tool reports missing GitHub App installation, tell the user to install Memtrace Code Reviewer on that repository.
- If the tool reports missing local graph context, tell the user to run `memtrace index .` at the workspace root.

## Output

For previews, summarize:
- PR URL and repository
- Graph state
- Number of candidate comments
- File, line, severity, and message for each finding

For posted reviews, report the PR URL and number of comments posted.

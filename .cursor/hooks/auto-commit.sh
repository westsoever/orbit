#!/usr/bin/env bash
# Cursor `stop` hook: auto-commit all workspace changes after each agent run.
#
# Fails open by design — it never blocks the agent and never errors out the run.
# Secrets/venvs/db files are excluded via .gitignore (git add -A honors it).
# Registered in .cursor/hooks.json.
set -uo pipefail

# Consume the event JSON from stdin (we only use it for an optional id tag).
input=$(cat 2>/dev/null || true)

# Resolve the repo root; quietly do nothing if we're not in a git repo.
root=$(git rev-parse --show-toplevel 2>/dev/null) || exit 0
cd "$root" || exit 0

# Never interfere with an in-progress merge/rebase/cherry-pick.
gitdir=$(git rev-parse --git-dir 2>/dev/null) || exit 0
if [[ -e "$gitdir/MERGE_HEAD" || -d "$gitdir/rebase-merge" \
   || -d "$gitdir/rebase-apply" || -e "$gitdir/CHERRY_PICK_HEAD" ]]; then
  exit 0
fi

# Nothing changed → nothing to commit.
if [[ -z "$(git status --porcelain 2>/dev/null)" ]]; then
  exit 0
fi

# Best-effort: tag the commit with a short conversation id from the payload.
convo=""
if command -v jq >/dev/null 2>&1; then
  convo=$(printf '%s' "$input" \
    | jq -r '.conversation_id // .conversationId // .threadId // empty' 2>/dev/null \
    | tr -dc 'a-zA-Z0-9' | cut -c1-8)
fi

stamp=$(date "+%Y-%m-%d %H:%M:%S")
msg="chore: auto-commit after agent run ($stamp)"
[[ -n "$convo" ]] && msg="$msg [$convo]"

# Stage everything (gitignore-respecting) and commit. Swallow failures
# (e.g. a rejecting pre-commit hook) so the agent run is never blocked.
git add -A >/dev/null 2>&1 || exit 0
git commit -q -m "$msg" >/dev/null 2>&1 || exit 0

exit 0

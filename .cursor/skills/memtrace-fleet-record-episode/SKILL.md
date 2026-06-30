---
name: memtrace-fleet-record-episode
description: "Use AFTER an edit in a fleet to record it and get its conflict class (A/B/C) against agents on your branch. Triggered by: finishing an edit, 'I just changed X', completing a refactor step while other agents share your repo+branch. Returns conflict_class + replan_hint; a Class C returns an escalation_id and mediation_request that starts the decision loop. Do not finish a coordinated edit without recording it."
---


## Overview

`fleet_record_episode` is step 3 of the fleet protocol: record the edit you just
made and learn whether it collided with another agent on your branch.

## Call it

```jsonc
fleet_record_episode({
  repo_id: "myrepo",
  branch:  "session/auth-revamp",
  agent_id:"agent-a",
  touched: ["auth::verify_token"],
  intent:  {"refactor": {"pattern": "change_signature"}}
})
```

## The result: conflict_class

- **A → proceed.** Additive, order-independent.
- **B → re-read, then proceed.** Non-destructive overlap; re-read the shared
  symbols so you build on current state.
- **C → a decision is needed.** A destructive change overlaps another agent's
  work. The response includes:
  - `escalation_id` — the decision's id.
  - `mediation_request` — the judging task (every agent's `assignment` + the
    contested symbols). If you're asked to judge, call `fleet_submit_verdict`.
  - `next_action` — poll `fleet_get_escalation({escalation_id, agent_id})` until
    `your_directive` ≠ `wait`, then `proceed` / `defer` / `review`.

Class is computed **only against agents on your branch**. Agents on other branches
never make your edit a Class C.

## After recording

- Class A/B → continue.
- Class C → enter the decision loop (see `memtrace-fleet-coordination`). Don't keep
  editing the contested symbols until your directive is `proceed`.
- Review history with `fleet_query_episodes({repo_id, node?, conflict_class?})`.

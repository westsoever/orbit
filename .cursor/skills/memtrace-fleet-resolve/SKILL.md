---
name: memtrace-fleet-resolve
description: "Use to act on a Class C decision: submit your verdict as an agent judge (fleet_submit_verdict), poll your own directive (fleet_get_escalation), see the needs-human queue (fleet_list_escalations), or record a human decision (fleet_resolve_escalation). Triggered by: 'a decision is waiting', 'who should proceed', being handed a mediation_request, acting as a mediator between two agents, or a human choosing a winner in the dashboard."
---


## Overview

The tools that resolve a Class C conflict. The judging is done by the user's own
agents (no API keys): an agent reads the bundle and submits a verdict; the daemon
is the deterministic referee that decides the outcome and routes it back.

## Submit a verdict (you are the judge)

You were handed a `mediation_request` (from `fleet_record_episode`). Read **every
agent's `assignment`** in it and decide on merit — including against your own
change:

```jsonc
fleet_submit_verdict({
  escalation_id: "01J…",
  agent_id: "agent-a",
  verdict: { "kind": "recommend", "winner": "agent-b",
             "rationale": "wider contract; rebase the fix onto it", "confidence": 0.8 }
})
// kinds: reconcile {merge_plan} | recommend {winner, rationale, confidence} | defer_to_human {question}
```

The response tells you the `outcome` (`auto_apply` | `human_confirm` |
`human_required` | `pending`) and `your_directive`.

## Read your own directive (you are blocked)

```jsonc
fleet_get_escalation({ escalation_id: "01J…", agent_id: "agent-a" })
// → your_directive: wait | proceed | defer | review
```

Poll until it's not `wait`. `proceed` = continue; `defer` = stand down and rebase
onto the winner; `review` = read `resolution`.

## Human paths

- `fleet_list_escalations({repo_id})` — the per-repo "needs human" queue.
- `fleet_resolve_escalation({escalation_id, resolution, winner})` — record a human
  decision (pick which agent proceeds) and clear it. Prefer the agent-judge path;
  use this for genuine human/product calls.

## Safety the referee guarantees

- A destructive **removal** (delete/move) is **never** auto-applied — always a human.
- Auto-apply happens only for the clear-safe machine case or ≥2 agents agreeing on
  a non-destructive resolution.
- So a wrong verdict degrades to "a human reviews a suggestion," never a silent
  bad merge.

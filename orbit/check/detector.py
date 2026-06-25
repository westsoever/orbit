"""Detect actionable tasks from a context string via LLM."""
from __future__ import annotations
import json
from dataclasses import dataclass

from .llm import complete

_SYSTEM = """\
You are a task-detection assistant. Given a user's context file, identify 1–3 \
concrete, actionable tasks they should work on.

Return a JSON array of objects with exactly these fields:
- title: short task label (max 60 chars)
- description: what needs doing, 1–2 sentences
- suggested_prompt: a detailed, ready-to-use prompt that Claude Code can execute \
directly — include all relevant context so the agent can act without asking questions
- agent_type: one of writing | research | code | admin
- confidence: float 0.0–1.0 reflecting how clearly the context calls for this task

Only include tasks with confidence >= 0.7. Return [] if nothing is clear enough.
Return ONLY the JSON array, no other text or markdown fences.\
"""

_CONFIDENCE_THRESHOLD = 0.7


@dataclass
class Task:
    title: str
    description: str
    suggested_prompt: str
    agent_type: str
    confidence: float


def detect_tasks(context_text: str) -> list[Task]:
    raw = complete(_SYSTEM, context_text)
    text = raw.strip()
    if text.startswith("```"):
        text = text.split("\n", 1)[1].rsplit("```", 1)[0].strip()
    data = json.loads(text)
    tasks = [
        Task(
            title=item["title"],
            description=item["description"],
            suggested_prompt=item["suggested_prompt"],
            agent_type=item.get("agent_type", "admin"),
            confidence=float(item.get("confidence", 0.0)),
        )
        for item in data
    ]
    return [t for t in tasks if t.confidence >= _CONFIDENCE_THRESHOLD]

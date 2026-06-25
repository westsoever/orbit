"""Terminal approval loop — present detected tasks, collect approve/edit/skip."""
from __future__ import annotations

from .detector import Task

_WIDTH = 58


def _hr() -> None:
    print("═" * _WIDTH)


def _wrap(text: str, indent: int = 2) -> None:
    prefix = " " * indent
    words = text.split()
    line = prefix
    for word in words:
        if len(line) + len(word) + 1 > _WIDTH - 2:
            print(line)
            line = prefix + word
        else:
            line += (" " if line != prefix else "") + word
    if line.strip():
        print(line)


def _print_task(index: int, total: int, task: Task, prompt: str) -> None:
    _hr()
    print(f"  ORBIT  [{index}/{total}]  {task.agent_type.upper()}")
    _hr()
    _wrap(task.title)
    print()
    _wrap(task.description)
    print()
    print("  PROMPT:")
    _wrap(prompt)
    print()


def run_approval(tasks: list[Task]) -> tuple[Task, str] | None:
    """Present each task and collect user decision. Returns (task, prompt) or None."""
    total = len(tasks)
    for i, task in enumerate(tasks, 1):
        prompt = task.suggested_prompt
        while True:
            _print_task(i, total, task, prompt)
            print("  (a)pprove  (e)dit  (s)kip  (q)uit")
            _hr()
            try:
                choice = input("  > ").strip().lower()
            except (EOFError, KeyboardInterrupt):
                print()
                return None

            if choice in ("a", "approve", ""):
                return task, prompt
            elif choice in ("e", "edit"):
                try:
                    new = input("  New prompt: ").strip()
                except (EOFError, KeyboardInterrupt):
                    print()
                    return None
                if new:
                    prompt = new
            elif choice in ("s", "skip"):
                break
            elif choice in ("q", "quit"):
                return None
    return None

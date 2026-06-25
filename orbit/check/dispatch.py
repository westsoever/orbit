"""Dispatch an approved prompt to Claude Code CLI. Streams output live."""
from __future__ import annotations
import shutil
import subprocess


def dispatch(prompt: str) -> int:
    if shutil.which("claude") is None:
        print("\nClaude Code CLI not found on PATH.")
        print("Run this manually:\n")
        print(f'  claude --print "{prompt}"\n')
        return 1
    print("\nDispatching to Claude Code...\n" + "─" * 58)
    result = subprocess.run(["claude", "--print", prompt])
    print("─" * 58)
    return result.returncode

"""LLM abstraction — swap provider by changing this file only.

Current: OpenRouter (OpenAI-compatible API), key loaded from ~/.orbit/.env
Local model: set base_url to http://localhost:11434/v1 (Ollama) and api_key="ollama"
"""
from __future__ import annotations
import os
from pathlib import Path

_CONFIG = Path("~/.orbit/.env").expanduser()
_MODEL = "owl-alpha"
_BASE_URL = "https://openrouter.ai/api/v1"


def _load_api_key() -> str:
    key = os.environ.get("OPENROUTER_API_KEY")
    if key:
        return key
    if _CONFIG.exists():
        for line in _CONFIG.read_text().splitlines():
            if line.startswith("OPENROUTER_API_KEY="):
                return line.split("=", 1)[1].strip()
    raise RuntimeError(
        "OPENROUTER_API_KEY not set.\n"
        f"Add it to {_CONFIG} or export it as an environment variable."
    )


def complete(system: str, user: str) -> str:
    import openai
    client = openai.OpenAI(api_key=_load_api_key(), base_url=_BASE_URL)
    response = client.chat.completions.create(
        model=_MODEL,
        max_tokens=1024,
        messages=[
            {"role": "system", "content": system},
            {"role": "user", "content": user},
        ],
    )
    return response.choices[0].message.content

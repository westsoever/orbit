"""OpenRouter proxy — request shape copied from orbit/check/llm.py."""
from __future__ import annotations

import httpx

from orbit_relay.config import Settings


async def complete_chat(
    system: str,
    user: str,
    model: str,
    settings: Settings,
) -> str:
    """POST /chat/completions — mirrors orbit/check/llm.py complete()."""
    url = f"{settings.openrouter_base_url.rstrip('/')}/chat/completions"
    headers = {
        "Authorization": f"Bearer {settings.openrouter_api_key}",
        "Content-Type": "application/json",
    }
    payload = {
        "model": model,
        "max_tokens": 1024,
        "messages": [
            {"role": "system", "content": system},
            {"role": "user", "content": user},
        ],
    }
    async with httpx.AsyncClient(timeout=120.0) as client:
        response = await client.post(url, headers=headers, json=payload)
        response.raise_for_status()
        data = response.json()
    content = data["choices"][0]["message"]["content"]
    if content is None:
        return ""
    return str(content)

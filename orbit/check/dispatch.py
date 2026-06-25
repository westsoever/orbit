"""Dispatch an approved prompt — streams response from OpenRouter to terminal."""
from __future__ import annotations

_SYSTEM = (
    "You are an autonomous agent executing a task on behalf of the user. "
    "Complete the task fully and thoroughly. Provide the complete output — "
    "do not summarise or abbreviate. If the task produces a document, write "
    "the full document."
)


def dispatch(prompt: str) -> int:
    import openai
    from .llm import _load_api_key, _BASE_URL, _MODEL

    client = openai.OpenAI(api_key=_load_api_key(), base_url=_BASE_URL)
    print(f"\nRunning via {_MODEL} (OpenRouter)...\n" + "─" * 58)

    try:
        response = client.chat.completions.create(
            model=_MODEL,
            max_tokens=4096,
            stream=True,
            messages=[
                {"role": "system", "content": _SYSTEM},
                {"role": "user", "content": prompt},
            ],
        )
        for chunk in response:
            delta = chunk.choices[0].delta.content
            if delta:
                print(delta, end="", flush=True)
        print("\n" + "─" * 58)
        return 0
    except Exception as e:
        print(f"\nerror during dispatch: {e}")
        return 1

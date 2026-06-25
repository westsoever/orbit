"""Dispatch an approved prompt — streams response, saves output as .md file."""
from __future__ import annotations
import re
from datetime import datetime, timezone
from pathlib import Path

OUTPUT_DIR = Path("/Users/lyo/orbit/mvp-output")

_SYSTEM = (
    "You are an autonomous agent executing a task on behalf of the user. "
    "Complete the task fully and thoroughly. Provide the complete output — "
    "do not summarise or abbreviate. If the task produces a document, write "
    "the full document."
)


def _slugify(title: str) -> str:
    slug = title.lower().strip()
    slug = re.sub(r"[^\w\s-]", "", slug)
    slug = re.sub(r"[\s_]+", "-", slug)
    return slug[:60]


def dispatch(prompt: str, title: str = "task") -> int:
    import openai
    from .llm import _load_api_key, _BASE_URL, _MODEL

    client = openai.OpenAI(api_key=_load_api_key(), base_url=_BASE_URL)

    ts = datetime.now(timezone.utc).strftime("%Y-%m-%d-%H%M")
    filename = f"{ts}-{_slugify(title)}.md"
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    out_path = OUTPUT_DIR / filename

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
        chunks = []
        for chunk in response:
            delta = chunk.choices[0].delta.content
            if delta:
                print(delta, end="", flush=True)
                chunks.append(delta)

        print("\n" + "─" * 58)

        content = "".join(chunks)
        out_path.write_text(f"# {title}\n\n{content}\n", encoding="utf-8")
        print(f"\nSaved → {out_path}")
        return 0
    except Exception as e:
        print(f"\nerror during dispatch: {e}")
        return 1

"""LLM abstraction — swap provider by changing this file only.

Resolution order for ``complete()``:
1. BYOK — ``OPENROUTER_API_KEY`` in env or ``~/.orbit/.env``
2. Orbit Cloud relay — ``~/.orbit/cloud.json`` (device token + relay URL)
3. Raise with setup instructions

Local model: set base_url to http://localhost:11434/v1 (Ollama) and api_key="ollama"
"""
from __future__ import annotations

import os
from pathlib import Path

from orbit.check.cloud_config import CloudConfig, load_cloud_config

_CONFIG = Path("~/.orbit/.env").expanduser()
_MODEL = "owl-alpha"
_BASE_URL = "https://openrouter.ai/api/v1"


def _get_setting(name: str) -> str | None:
    """Read a setting from the environment, falling back to ``~/.orbit/.env``."""
    value = os.environ.get(name)
    if value:
        return value
    if _CONFIG.exists():
        prefix = f"{name}="
        for line in _CONFIG.read_text().splitlines():
            if line.startswith(prefix):
                parsed = line.split("=", 1)[1].strip()
                if parsed:
                    return parsed
    return None


def _try_load_api_key() -> str | None:
    return _get_setting("OPENROUTER_API_KEY")


def _resolve_provider() -> str:
    """Resolve the configured LLM provider: auto/local/cloud/byok (default auto)."""
    return (_get_setting("ORBIT_LLM_PROVIDER") or "auto").lower()


def _local_base_url() -> str:
    return _get_setting("ORBIT_LOCAL_LLM_BASE_URL") or "http://localhost:11434/v1"


def _local_model() -> str:
    return _get_setting("ORBIT_LOCAL_LLM_MODEL") or "llama3.1"


def _missing_key_message() -> str:
    return (
        "No AI credentials configured.\n"
        "Enable Orbit Cloud AI in Orbit Access, or add OPENROUTER_API_KEY to "
        f"{_CONFIG}, "
        "or run a local model with Ollama (set ORBIT_LLM_PROVIDER=local, run "
        "`ollama serve`, `ollama pull llama3.1`)."
    )


def _complete_openrouter(system: str, user: str, api_key: str) -> str:
    import openai

    client = openai.OpenAI(api_key=api_key, base_url=_BASE_URL)
    response = client.chat.completions.create(
        model=_MODEL,
        max_tokens=1024,
        messages=[
            {"role": "system", "content": system},
            {"role": "user", "content": user},
        ],
    )
    content = response.choices[0].message.content
    return content if content is not None else ""


def _local_available(base_url: str) -> bool:
    # Ollama exposes an OpenAI-compatible API at /v1 and a /api/tags health route.
    # See https://github.com/ollama/ollama/blob/main/docs/openai.md
    try:
        import httpx

        health_url = base_url.replace("/v1", "") + "/api/tags"
        response = httpx.get(health_url, timeout=1.5)
        return response.status_code == 200
    except Exception:
        return False


def _complete_local(system: str, user: str, base_url: str, model: str) -> str:
    import openai

    client = openai.OpenAI(api_key="ollama", base_url=base_url)
    response = client.chat.completions.create(
        model=model,
        max_tokens=1024,
        messages=[
            {"role": "system", "content": system},
            {"role": "user", "content": user},
        ],
    )
    content = response.choices[0].message.content
    return content if content is not None else ""


def complete_via_relay(system: str, user: str, cfg: CloudConfig) -> str:
    import httpx

    url = f"{cfg.relay_base_url.rstrip('/')}/v1/chat/completions"
    response = httpx.post(
        url,
        headers={"Authorization": f"Bearer {cfg.device_token}"},
        json={"system": system, "user": user, "model": _MODEL},
        timeout=120.0,
    )
    response.raise_for_status()
    data = response.json()
    content = data.get("content")
    return str(content) if content is not None else ""


def format_completion_error(exc: Exception) -> str:
    try:
        import httpx
    except ImportError:
        return str(exc)

    if isinstance(exc, httpx.HTTPStatusError):
        status = exc.response.status_code
        if status == 429:
            return (
                "Daily cloud AI limit reached. Try again tomorrow or add your own "
                f"API key in {_CONFIG}"
            )
        if status == 401:
            return "Cloud AI session expired. Re-enable Orbit Cloud AI in Orbit Access."
        if status == 503:
            try:
                body = exc.response.json()
                if isinstance(body, dict):
                    error = body.get("error")
                    nested = body.get("detail")
                    if not isinstance(error, str):
                        error = nested.get("error") if isinstance(nested, dict) else None
                    if error == "relay_disabled":
                        return "Cloud AI temporarily unavailable."
            except Exception:
                pass
        try:
            body = exc.response.json()
            if isinstance(body, dict):
                error = body.get("error")
                if not isinstance(error, str) or not error:
                    nested = body.get("detail")
                    error = nested.get("error") if isinstance(nested, dict) else None
                if isinstance(error, str) and error:
                    return error
        except Exception:
            pass
    return str(exc)


def complete(system: str, user: str) -> str:
    provider = _resolve_provider()
    if provider == "local" or (provider == "auto" and _local_available(_local_base_url())):
        return _complete_local(system, user, _local_base_url(), _local_model())
    if provider != "local":
        if key := _try_load_api_key():
            return _complete_openrouter(system, user, key)
        if cfg := load_cloud_config():
            return complete_via_relay(system, user, cfg)
    raise RuntimeError(_missing_key_message())


def _load_api_key() -> str:
    """Backward-compatible strict loader for dispatch and other callers."""
    key = _try_load_api_key()
    if key:
        return key
    raise RuntimeError(
        "OPENROUTER_API_KEY not set.\n"
        f"Add it to {_CONFIG} or export it as an environment variable."
    )

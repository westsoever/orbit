"""Tests for cloud config and LLM routing."""
from __future__ import annotations

import json
from pathlib import Path
from unittest.mock import MagicMock, patch

import pytest

from orbit.check.cloud_config import load_cloud_config


def test_load_cloud_config_missing(tmp_path, monkeypatch):
    path = tmp_path / "cloud.json"
    monkeypatch.setattr("orbit.check.cloud_config._CLOUD_JSON", path)
    assert load_cloud_config() is None


def test_load_cloud_config_valid(tmp_path, monkeypatch):
    path = tmp_path / "cloud.json"
    path.write_text(
        json.dumps(
            {
                "device_token": "tok-abc",
                "relay_base_url": "http://127.0.0.1:8080",
            }
        )
    )
    monkeypatch.setattr("orbit.check.cloud_config._CLOUD_JSON", path)
    cfg = load_cloud_config()
    assert cfg is not None
    assert cfg.device_token == "tok-abc"
    assert cfg.relay_base_url == "http://127.0.0.1:8080"


def test_complete_prefers_byok(monkeypatch):
    monkeypatch.setenv("OPENROUTER_API_KEY", "byok-key")
    from orbit.check import llm

    with patch.object(llm, "_complete_openrouter", return_value="byok-answer") as mock_openrouter:
        with patch.object(llm, "complete_via_relay") as mock_relay:
            assert llm.complete("s", "u") == "byok-answer"
            mock_openrouter.assert_called_once_with("s", "u", "byok-key")
            mock_relay.assert_not_called()


def test_complete_uses_relay_when_no_byok(monkeypatch, tmp_path):
    monkeypatch.delenv("OPENROUTER_API_KEY", raising=False)
    env_path = tmp_path / ".env"
    monkeypatch.setattr("orbit.check.llm._CONFIG", env_path)

    cloud_path = tmp_path / "cloud.json"
    cloud_path.write_text(
        json.dumps({"device_token": "t", "relay_base_url": "http://localhost:8080"})
    )
    monkeypatch.setattr("orbit.check.cloud_config._CLOUD_JSON", cloud_path)

    from orbit.check import llm
    from orbit.check.cloud_config import CloudConfig

    cfg = CloudConfig(device_token="t", relay_base_url="http://localhost:8080")
    with patch.object(llm, "complete_via_relay", return_value="relay-answer") as mock_relay:
        assert llm.complete("s", "u") == "relay-answer"
        mock_relay.assert_called_once_with("s", "u", cfg)


def test_format_completion_error_429():
    import httpx
    from orbit.check.llm import format_completion_error

    request = httpx.Request("POST", "http://example.com")
    response = httpx.Response(429, request=request)
    err = httpx.HTTPStatusError("limit", request=request, response=response)
    message = format_completion_error(err)
    assert "Daily cloud AI limit" in message


def test_complete_local_when_provider_local(monkeypatch):
    monkeypatch.setenv("ORBIT_LLM_PROVIDER", "local")
    monkeypatch.delenv("OPENROUTER_API_KEY", raising=False)
    monkeypatch.delenv("ORBIT_LOCAL_LLM_BASE_URL", raising=False)
    monkeypatch.delenv("ORBIT_LOCAL_LLM_MODEL", raising=False)
    from orbit.check import llm

    monkeypatch.setattr(llm, "_CONFIG", Path("/nonexistent/.env"))

    captured = {}

    message = MagicMock()
    message.content = "local-answer"
    choice = MagicMock()
    choice.message = message
    response = MagicMock()
    response.choices = [choice]

    client = MagicMock()
    client.chat.completions.create.return_value = response

    def fake_openai_ctor(*, api_key, base_url):
        captured["api_key"] = api_key
        captured["base_url"] = base_url
        return client

    fake_openai = MagicMock()
    fake_openai.OpenAI.side_effect = fake_openai_ctor

    with patch.dict("sys.modules", {"openai": fake_openai}):
        assert llm.complete("s", "u") == "local-answer"

    assert captured["api_key"] == "ollama"
    assert captured["base_url"] == "http://localhost:11434/v1"


def test_auto_falls_back_to_byok_when_local_unavailable(monkeypatch):
    monkeypatch.setenv("ORBIT_LLM_PROVIDER", "auto")
    monkeypatch.setenv("OPENROUTER_API_KEY", "byok-key")
    from orbit.check import llm

    monkeypatch.setattr(llm, "_local_available", lambda base_url: False)

    with patch.object(llm, "_complete_local") as mock_local:
        with patch.object(llm, "_complete_openrouter", return_value="byok-answer") as mock_openrouter:
            assert llm.complete("s", "u") == "byok-answer"
            mock_openrouter.assert_called_once_with("s", "u", "byok-key")
            mock_local.assert_not_called()


def test_format_error_relay_disabled_nested_detail():
    import httpx
    from orbit.check.llm import format_completion_error

    request = httpx.Request("POST", "http://example.com")
    response = httpx.Response(
        503,
        request=request,
        json={"detail": {"error": "relay_disabled"}},
    )
    err = httpx.HTTPStatusError("disabled", request=request, response=response)
    message = format_completion_error(err)
    assert message == "Cloud AI temporarily unavailable."

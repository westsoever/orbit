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

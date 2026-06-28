"""Pytest fixtures for orbit-relay."""
from __future__ import annotations

import pytest

from orbit_relay.config import get_settings


@pytest.fixture(autouse=True)
def relay_env(tmp_path, monkeypatch):
    monkeypatch.setenv("OPENROUTER_API_KEY", "test-openrouter-key")
    monkeypatch.setenv("ORBIT_RELAY_SECRET", "test-relay-secret")
    monkeypatch.setenv("RELAY_DATABASE_PATH", str(tmp_path / "relay.db"))
    monkeypatch.setenv("DAILY_REQUESTS_PER_DEVICE", "3")
    monkeypatch.setenv("DAILY_TOKENS_PER_DEVICE", "1000")
    monkeypatch.setenv("DAILY_REQUESTS_PER_IP", "10")
    monkeypatch.setenv("MAX_REGISTRATIONS_PER_IP_PER_DAY", "2")
    get_settings.cache_clear()
    yield
    get_settings.cache_clear()

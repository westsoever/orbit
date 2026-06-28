"""Unit tests for rate limit helpers."""
from __future__ import annotations

from orbit_relay.config import Settings
from orbit_relay.limits import (
    check_prompt_size,
    check_usage_after_increment,
    check_usage_before_request,
    estimate_tokens,
    seconds_until_utc_midnight,
)
from orbit_relay.store import RelayStore


def test_estimate_tokens():
    assert estimate_tokens("abc", "def") == 6


def test_prompt_too_large():
    settings = Settings(
        OPENROUTER_API_KEY="k",
        ORBIT_RELAY_SECRET="s",
        MAX_PROMPT_CHARS=10,
    )
    result = check_prompt_size("x" * 6, "y" * 6, settings)
    assert not result.allowed
    assert result.status_code == 413
    assert result.error == "prompt_too_large"


def test_device_request_limit(tmp_path):
    settings = Settings(
        OPENROUTER_API_KEY="k",
        ORBIT_RELAY_SECRET="secret",
        DAILY_REQUESTS_PER_DEVICE=2,
        DAILY_TOKENS_PER_DEVICE=10_000,
        DAILY_REQUESTS_PER_IP=100,
        RELAY_DATABASE_PATH=str(tmp_path / "limits.db"),
    )
    store = RelayStore(settings.database_path)
    token, _ = store.register_device(
        "install-limit-test",
        settings.orbit_relay_secret,
        settings.token_ttl_days,
        "127.0.0.1",
        settings.max_registrations_per_ip_per_day,
    )
    device = store.resolve_device(token, settings.orbit_relay_secret)
    assert device is not None

    day = store.day_utc()
    store.record_usage(device.device_id, "127.0.0.1", day, 10)
    store.record_usage(device.device_id, "127.0.0.1", day, 10)

    blocked = check_usage_before_request(
        store, device.device_id, "127.0.0.1", 5, settings
    )
    assert not blocked.allowed
    assert blocked.status_code == 429
    assert blocked.error == "rate_limit_exceeded"
    assert blocked.retry_after is not None
    assert blocked.retry_after > 0


def test_post_increment_cap():
    settings = Settings(
        OPENROUTER_API_KEY="k",
        ORBIT_RELAY_SECRET="s",
        DAILY_REQUESTS_PER_DEVICE=1,
    )
    result = check_usage_after_increment(2, 50, 1, settings)
    assert not result.allowed
    assert result.status_code == 429


def test_seconds_until_midnight_positive():
    assert seconds_until_utc_midnight() >= 1

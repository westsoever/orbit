"""Rate limit checks for relay requests."""
from __future__ import annotations

from dataclasses import dataclass

from orbit_relay.config import Settings
from orbit_relay.store import RelayStore


@dataclass(frozen=True)
class LimitCheckResult:
    allowed: bool
    error: str | None = None
    retry_after: int | None = None
    status_code: int = 200


def estimate_tokens(system: str, user: str) -> int:
    return len(system) + len(user)


def check_prompt_size(system: str, user: str, settings: Settings) -> LimitCheckResult:
    total = len(system) + len(user)
    if total > settings.max_prompt_chars:
        return LimitCheckResult(
            allowed=False,
            error="prompt_too_large",
            status_code=413,
        )
    return LimitCheckResult(allowed=True)


def check_usage_before_request(
    store: RelayStore,
    device_id: str,
    client_ip: str,
    tokens_est: int,
    settings: Settings,
) -> LimitCheckResult:
    day = store.day_utc()
    requests, tokens = store.get_usage(device_id, day)
    ip_requests = store.get_ip_requests(client_ip, day)

    if requests >= settings.daily_requests_per_device:
        return LimitCheckResult(
            allowed=False,
            error="rate_limit_exceeded",
            retry_after=seconds_until_utc_midnight(),
            status_code=429,
        )
    if tokens + tokens_est > settings.daily_tokens_per_device:
        return LimitCheckResult(
            allowed=False,
            error="rate_limit_exceeded",
            retry_after=seconds_until_utc_midnight(),
            status_code=429,
        )
    if ip_requests >= settings.daily_requests_per_ip:
        return LimitCheckResult(
            allowed=False,
            error="rate_limit_exceeded",
            retry_after=seconds_until_utc_midnight(),
            status_code=429,
        )
    return LimitCheckResult(allowed=True)


def check_usage_after_increment(
    device_requests: int,
    device_tokens: int,
    ip_requests: int,
    settings: Settings,
) -> LimitCheckResult:
    """Post-increment sanity check (race-tolerant soft cap)."""
    if device_requests > settings.daily_requests_per_device:
        return LimitCheckResult(
            allowed=False,
            error="rate_limit_exceeded",
            retry_after=seconds_until_utc_midnight(),
            status_code=429,
        )
    if device_tokens > settings.daily_tokens_per_device:
        return LimitCheckResult(
            allowed=False,
            error="rate_limit_exceeded",
            retry_after=seconds_until_utc_midnight(),
            status_code=429,
        )
    if ip_requests > settings.daily_requests_per_ip:
        return LimitCheckResult(
            allowed=False,
            error="rate_limit_exceeded",
            retry_after=seconds_until_utc_midnight(),
            status_code=429,
        )
    return LimitCheckResult(allowed=True)


def seconds_until_utc_midnight() -> int:
    from datetime import UTC, datetime, timedelta

    now = datetime.now(UTC)
    tomorrow = (now + timedelta(days=1)).replace(hour=0, minute=0, second=0, microsecond=0)
    return max(1, int((tomorrow - now).total_seconds()))

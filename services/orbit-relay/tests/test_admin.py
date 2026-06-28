"""Tests for relay admin CLI."""
from __future__ import annotations

from orbit_relay.admin import main
from orbit_relay.store import RelayStore


def test_revoke_install_id(tmp_path, monkeypatch):
    monkeypatch.setenv("OPENROUTER_API_KEY", "k")
    monkeypatch.setenv("ORBIT_RELAY_SECRET", "secret")
    db = tmp_path / "admin.db"
    monkeypatch.setenv("RELAY_DATABASE_PATH", str(db))

    from orbit_relay.config import get_settings

    get_settings.cache_clear()
    settings = get_settings()
    store = RelayStore(settings.database_path)
    token, _ = store.register_device(
        "revoke-me",
        settings.orbit_relay_secret,
        settings.token_ttl_days,
        "127.0.0.1",
        settings.max_registrations_per_ip_per_day,
    )
    assert store.resolve_device(token, settings.orbit_relay_secret) is not None

    assert main(["revoke", "--install-id", "revoke-me"]) == 0
    assert store.resolve_device(token, settings.orbit_relay_secret) is None
    get_settings.cache_clear()

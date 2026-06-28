"""HTTP API tests for orbit-relay (OpenRouter mocked)."""
from __future__ import annotations

from unittest.mock import AsyncMock, patch

import pytest
from fastapi.testclient import TestClient

from orbit_relay.config import get_settings
from orbit_relay.main import app


@pytest.fixture
def client():
    with TestClient(app) as test_client:
        yield test_client


def _register(client: TestClient, install_id: str) -> str:
    response = client.post(
        "/v1/devices/register",
        json={"install_id": install_id, "app_version": "0.1.0"},
    )
    assert response.status_code == 201, response.text
    return response.json()["device_token"]


def test_health(client):
    assert client.get("/health").json() == {"ok": True}


def test_register_and_duplicate(client):
    install_id = "550e8400-e29b-41d4-a716-446655440001"
    first = client.post(
        "/v1/devices/register",
        json={"install_id": install_id, "app_version": "0.1.0"},
    )
    assert first.status_code == 201
    body = first.json()
    assert "device_token" in body
    assert "expires_at" in body

    second = client.post(
        "/v1/devices/register",
        json={"install_id": install_id, "app_version": "0.1.0"},
    )
    assert second.status_code == 409
    assert second.json()["detail"]["error"] == "install_id_already_registered"


def test_chat_requires_auth(client):
    response = client.post(
        "/v1/chat/completions",
        json={"system": "s", "user": "hi", "model": "owl-alpha"},
    )
    assert response.status_code == 401


@patch("orbit_relay.main.complete_chat", new_callable=AsyncMock)
def test_chat_success(mock_complete, client):
    mock_complete.return_value = "Hello there."
    token = _register(client, "550e8400-e29b-41d4-a716-446655440002")

    response = client.post(
        "/v1/chat/completions",
        headers={"Authorization": f"Bearer {token}"},
        json={
            "system": "You are helpful.",
            "user": "Say hi.",
            "model": "owl-alpha",
        },
    )
    assert response.status_code == 200
    assert response.json()["content"] == "Hello there."
    mock_complete.assert_awaited_once()


@patch("orbit_relay.main.complete_chat", new_callable=AsyncMock)
def test_chat_rate_limit(mock_complete, client):
    mock_complete.return_value = "ok"
    token = _register(client, "550e8400-e29b-41d4-a716-446655440003")
    headers = {"Authorization": f"Bearer {token}"}
    payload = {"system": "s", "user": "u", "model": "owl-alpha"}

    for _ in range(3):
        assert client.post("/v1/chat/completions", headers=headers, json=payload).status_code == 200

    blocked = client.post("/v1/chat/completions", headers=headers, json=payload)
    assert blocked.status_code == 429
    assert blocked.json()["detail"]["error"] == "rate_limit_exceeded"
    assert blocked.json()["detail"]["retry_after"] > 0


def test_invite_code_required(client, monkeypatch):
    monkeypatch.setenv("INVITE_CODE", "beta-secret")
    get_settings.cache_clear()

    denied = client.post(
        "/v1/devices/register",
        json={"install_id": "550e8400-e29b-41d4-a716-446655440004", "app_version": "0.1"},
    )
    assert denied.status_code == 403

    allowed = client.post(
        "/v1/devices/register",
        headers={"X-Orbit-Invite": "beta-secret"},
        json={"install_id": "550e8400-e29b-41d4-a716-446655440004", "app_version": "0.1"},
    )
    assert allowed.status_code == 201

    get_settings.cache_clear()

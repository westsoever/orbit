"""Auth API tests for orbit-relay."""
from __future__ import annotations

import pytest
from fastapi.testclient import TestClient

from orbit_relay.main import app


@pytest.fixture
def client():
    with TestClient(app) as test_client:
        yield test_client


def test_signup_login_and_device_binding(client):
    signup = client.post(
        "/v1/auth/signup",
        json={
            "email": "user@example.com",
            "password": "secret-pass",
            "display_name": "Test User",
        },
    )
    assert signup.status_code == 201, signup.text
    body = signup.json()
    assert body["user_id"]
    assert body["session_token"]
    session_token = body["session_token"]

    duplicate = client.post(
        "/v1/auth/signup",
        json={
            "email": "user@example.com",
            "password": "secret-pass",
            "display_name": "Test User",
        },
    )
    assert duplicate.status_code == 409
    assert duplicate.json()["detail"]["error"] == "email_already_registered"

    login = client.post(
        "/v1/auth/login",
        json={"email": "user@example.com", "password": "secret-pass"},
    )
    assert login.status_code == 200
    assert login.json()["user_id"] == body["user_id"]

    register = client.post(
        "/v1/devices/register",
        headers={"Authorization": f"Bearer {session_token}"},
        json={"install_id": "550e8400-e29b-41d4-a716-446655440099", "app_version": "0.1.0"},
    )
    assert register.status_code == 201

    bad_login = client.post(
        "/v1/auth/login",
        json={"email": "user@example.com", "password": "wrong-password"},
    )
    assert bad_login.status_code == 401

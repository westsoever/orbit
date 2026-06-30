"""Active Orbit user session — reads/writes ~/.orbit/session.json."""
from __future__ import annotations

import json
import os
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path

LEGACY_USER_ID = "legacy-local"
_SESSION_JSON = Path("~/.orbit/session.json").expanduser()


class NoActiveUserError(RuntimeError):
    """Raised when capture or writes require a signed-in user."""


@dataclass(frozen=True)
class UserSession:
    user_id: str
    email: str
    signed_in_at: str


def _ensure_orbit_dir() -> None:
    _SESSION_JSON.parent.mkdir(parents=True, exist_ok=True)


def get_active_session() -> UserSession | None:
    if not _SESSION_JSON.exists():
        return None
    try:
        raw = json.loads(_SESSION_JSON.read_text(encoding="utf-8"))
    except (json.JSONDecodeError, OSError):
        return None
    if not isinstance(raw, dict):
        return None
    user_id = raw.get("user_id")
    if not user_id or not isinstance(user_id, str) or not user_id.strip():
        return None
    email = raw.get("email")
    signed_in_at = raw.get("signed_in_at")
    return UserSession(
        user_id=user_id.strip(),
        email=email.strip() if isinstance(email, str) else "",
        signed_in_at=signed_in_at if isinstance(signed_in_at, str) else "",
    )


def get_active_user_id() -> str | None:
    session = get_active_session()
    return session.user_id if session else None


def require_active_user_id() -> str:
    user_id = get_active_user_id()
    if not user_id:
        raise NoActiveUserError(
            "No active Orbit user session. Complete sign-up in Orbit Access App "
            "or run: orbit auth sign-in --user-id <id> --email <email>"
        )
    return user_id


def set_active_user(user_id: str, email: str = "") -> None:
    _ensure_orbit_dir()
    payload = {
        "user_id": user_id,
        "email": email,
        "signed_in_at": datetime.now(timezone.utc).isoformat(),
    }
    _SESSION_JSON.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")
    os.chmod(_SESSION_JSON, 0o600)


def clear_session() -> None:
    if _SESSION_JSON.exists():
        _SESSION_JSON.unlink()


def legacy_user_email() -> str:
    username = os.environ.get("USER") or os.environ.get("USERNAME") or "local"
    return f"{username}@orbit.local"

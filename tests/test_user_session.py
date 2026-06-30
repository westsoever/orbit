"""Tests for user session and user-scoped capture storage."""
from __future__ import annotations

import os
import tempfile
from datetime import datetime, timezone
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[1]
_WORKSPACE_TMP = ROOT / ".orbit-test-tmp"


def _temp_dir() -> str:
    _WORKSPACE_TMP.mkdir(exist_ok=True)
    return tempfile.mkdtemp(dir=str(_WORKSPACE_TMP))


@pytest.fixture
def session_path(tmp_path, monkeypatch):
    path = tmp_path / "session.json"
    monkeypatch.setattr("orbit.storage.session._SESSION_JSON", path)
    return path


def test_legacy_migration_backfills_user_id(session_path):
    from orbit.storage.db import open_db_plain
    from orbit.storage.session import LEGACY_USER_ID, set_active_user

    tmp = _temp_dir()
    try:
        db = os.path.join(tmp, "migrate.db")
        con, lock = open_db_plain(db)
        tables = {
            r[0]
            for r in con.execute(
                "SELECT name FROM sqlite_master WHERE type='table'"
            ).fetchall()
        }
        assert "users" in tables
        cols = {r[1] for r in con.execute("PRAGMA table_info(context_events)")}
        assert "user_id" in cols
        legacy = con.execute(
            "SELECT id FROM users WHERE id = ?", (LEGACY_USER_ID,)
        ).fetchone()
        assert legacy is not None

        set_active_user(LEGACY_USER_ID, email="legacy@orbit.local")
        from orbit.storage.writer import record_event

        event_id, _ = record_event(
            con,
            lock,
            {
                "timestamp": datetime.now(timezone.utc).isoformat(),
                "app_bundle_id": "com.test.app",
                "app_name": "Test",
                "window_title": "Window",
                "capture_method": "ax",
                "capture_tier": 1,
            },
            [{"role": "AXStaticText", "text": "hello", "element_path": "/0"}],
        )
        row = con.execute(
            "SELECT user_id FROM context_events WHERE id = ?", (event_id,)
        ).fetchone()
        assert row[0] == LEGACY_USER_ID
    finally:
        import shutil

        shutil.rmtree(tmp, ignore_errors=True)


def test_record_event_requires_session(session_path):
    from orbit.storage.db import open_db_plain
    from orbit.storage.session import NoActiveUserError
    from orbit.storage.writer import record_event

    tmp = _temp_dir()
    try:
        db = os.path.join(tmp, "nosession.db")
        con, lock = open_db_plain(db)
        with pytest.raises(NoActiveUserError):
            record_event(
                con,
                lock,
                {
                    "timestamp": datetime.now(timezone.utc).isoformat(),
                    "app_bundle_id": "com.test.app",
                    "app_name": "Test",
                    "window_title": "Window",
                    "capture_method": "ax",
                    "capture_tier": 1,
                },
                [],
            )
    finally:
        import shutil

        shutil.rmtree(tmp, ignore_errors=True)


def test_search_scoped_to_user(session_path):
    from orbit.storage.db import open_db_plain
    from orbit.storage.session import set_active_user
    from orbit.storage.writer import record_event
    from orbit.search.lexical import search_lexical

    tmp = _temp_dir()
    try:
        db = os.path.join(tmp, "scoped.db")
        con, lock = open_db_plain(db)

        now = datetime.now(timezone.utc).isoformat()
        con.execute(
            """
            INSERT INTO users (id, email, display_name, created_at, cloud_user_id)
            VALUES ('user-a', 'a@test.local', 'A', ?, NULL),
                   ('user-b', 'b@test.local', 'B', ?, NULL)
            """,
            (now, now),
        )

        set_active_user("user-a", email="a@test.local")
        record_event(
            con,
            lock,
            {
                "timestamp": now,
                "app_bundle_id": "com.test.app",
                "app_name": "Test",
                "window_title": "Alpha",
                "capture_method": "ax",
                "capture_tier": 1,
            },
            [{"role": "AXStaticText", "text": "alpha unique token", "element_path": "/0"}],
        )

        set_active_user("user-b", email="b@test.local")
        record_event(
            con,
            lock,
            {
                "timestamp": now,
                "app_bundle_id": "com.test.app",
                "app_name": "Test",
                "window_title": "Beta",
                "capture_method": "ax",
                "capture_tier": 1,
            },
            [{"role": "AXStaticText", "text": "beta unique token", "element_path": "/0"}],
        )

        hits_a = search_lexical(con, "alpha", user_id="user-a")
        assert len(hits_a) == 1
        assert hits_a[0].window_title == "Alpha"

        hits_b = search_lexical(con, "alpha", user_id="user-b")
        assert hits_b == []
    finally:
        import shutil

        shutil.rmtree(tmp, ignore_errors=True)

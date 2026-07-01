"""Tests for capture-based task context."""
from __future__ import annotations

import sqlite3
import tempfile
from pathlib import Path

import pytest

from orbit.check.capture_context import read_capture_context
from orbit.storage.db import open_db_plain


@pytest.fixture
def db_with_capture():
    with tempfile.TemporaryDirectory() as tmp:
        path = Path(tmp) / "orbit.db"
        con, _lock = open_db_plain(str(path))
        uid = "user-test-1"
        con.execute(
            "INSERT INTO users (id, email, display_name, created_at) VALUES (?, ?, ?, ?)",
            (uid, "test@example.com", "Test", "2026-01-01T00:00:00Z"),
        )
        con.execute(
            """INSERT INTO context_events
               (user_id, timestamp, app_bundle_id, app_name, window_title, capture_method, capture_tier)
               VALUES (?, ?, ?, ?, ?, ?, ?)""",
            (uid, "2026-06-30T12:00:00Z", "com.apple.Terminal", "Terminal", "bash", "ax", 1),
        )
        event_id = con.execute("SELECT last_insert_rowid()").fetchone()[0]
        con.execute(
            """INSERT INTO text_atoms (event_id, role, label, text, element_path)
               VALUES (?, ?, ?, ?, ?)""",
            (event_id, "AXStaticText", None, "Deploy the beta release today", "/0"),
        )
        con.commit()
        yield con, uid


def test_read_capture_context_returns_snippets(db_with_capture):
    con, uid = db_with_capture
    text, label = read_capture_context(con, user_id=uid, hours=24)
    assert "Deploy the beta release" in text
    assert "orbit.db" in label


def test_read_capture_context_empty_raises(db_with_capture):
    con, _uid = db_with_capture
    with pytest.raises(FileNotFoundError):
        read_capture_context(con, user_id="other-user", hours=1)

#!/usr/bin/env python3
"""Smoke test for FSEvents capture helpers and schema (no live stream required)."""
from __future__ import annotations

import os
import sqlite3
import sys
import tempfile
from datetime import datetime, timedelta, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

# Prefer repo-local temp when /tmp is full (common on dev machines).
_WORKSPACE_TMP = ROOT / ".orbit-test-tmp"


def _temp_dir() -> str:
    _WORKSPACE_TMP.mkdir(exist_ok=True)
    try:
        return tempfile.mkdtemp(dir=str(_WORKSPACE_TMP))
    except FileNotFoundError:
        return tempfile.mkdtemp(dir=str(ROOT))


def test_expand_watch_roots() -> None:
    from orbit.capture.fsevents_listener import coalesce_batch, event_type_from_flags, expand_watch_roots

    tmp = _temp_dir()
    try:
        roots = expand_watch_roots([tmp])
        assert roots == [str(Path(tmp).resolve())]
        assert expand_watch_roots(["/nonexistent/orbit-fsevents-test"]) == []
    finally:
        import shutil
        shutil.rmtree(tmp, ignore_errors=True)

    merged = coalesce_batch(["/a", "/a", "/b"], [1, 2, 4])
    assert merged["/a"] == 2
    assert merged["/b"] == 4
    assert event_type_from_flags(0) == "unknown"


def test_schema_and_linking() -> None:
    from orbit.capture.fs_worker import find_linked_event, record_fs_event
    from orbit.storage.db import open_db_plain
    from orbit.storage.writer import record_event

    tmp = _temp_dir()
    try:
        db = os.path.join(tmp, "test.db")
        con, lock = open_db_plain(db)
        from orbit.storage.session import LEGACY_USER_ID, set_active_user

        set_active_user(LEGACY_USER_ID, email="test@orbit.local")
        ts = datetime.now(timezone.utc).isoformat()
        event_id, _ = record_event(
            con,
            lock,
            {
                "timestamp": ts,
                "app_bundle_id": "com.example.app",
                "app_name": "Example",
                "window_title": "Test",
                "visible_text": "hello",
                "capture_method": "ax",
                "capture_tier": 1,
            },
            [],
        )
        assert event_id > 0

        audit = con.execute("SELECT COUNT(*) FROM capture_audit").fetchone()[0]
        assert audit == 1

        fs_id = record_fs_event(
            con,
            lock,
            {
                "timestamp": ts,
                "path": str(Path(tmp) / "file.txt"),
                "event_type": "modified",
            },
        )
        assert fs_id is not None
        row = con.execute(
            "SELECT linked_event_id FROM fs_events WHERE id = ?", (fs_id,)
        ).fetchone()
        assert row[0] == event_id

        far_ts = (datetime.now(timezone.utc) - timedelta(hours=1)).isoformat()
        assert find_linked_event(con, far_ts) is None
    finally:
        import shutil
        shutil.rmtree(tmp, ignore_errors=True)


def main() -> int:
    test_expand_watch_roots()
    test_schema_and_linking()
    print("test_fsevents: OK")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

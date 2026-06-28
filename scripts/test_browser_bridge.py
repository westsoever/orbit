#!/usr/bin/env python3
"""POST a sample browser capture event to the local Orbit bridge."""
from __future__ import annotations

import json
import sys
import urllib.request

URL = "http://127.0.0.1:8765/capture"
PAYLOAD = {
    "url": "https://example.com/test-orbit-bridge",
    "title": "Orbit bridge test",
    "tab_id": 1,
    "selection": "",
    "browser_name": "Test",
    "bundle_id": "browser.extension",
}


def main() -> int:
    data = json.dumps(PAYLOAD).encode("utf-8")
    req = urllib.request.Request(
        URL,
        data=data,
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    try:
        with urllib.request.urlopen(req, timeout=3) as resp:
            print("status:", resp.status)
            return 0 if resp.status == 204 else 1
    except Exception as e:
        print("error:", e, file=sys.stderr)
        print("Is orbit start running?", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())

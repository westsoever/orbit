#!/usr/bin/env python3
"""Smoke-test window OCR for a running app."""
from __future__ import annotations

import argparse
import sys

from AppKit import NSWorkspace

from orbit.capture.ocr import ocr_window_text


def main() -> int:
    parser = argparse.ArgumentParser(description="Test Orbit window OCR")
    parser.add_argument("--bundle", help="Bundle ID (default: frontmost app)")
    args = parser.parse_args()

    ws = NSWorkspace.sharedWorkspace()
    if args.bundle:
        app = next(
            (
                a
                for a in ws.runningApplications()
                if (a.bundleIdentifier() or "") == args.bundle
            ),
            None,
        )
    else:
        app = ws.frontmostApplication()

    if app is None:
        print("App not found", file=sys.stderr)
        return 1

    pid = int(app.processIdentifier())
    name = app.localizedName()
    lines = ocr_window_text(pid)
    print(f"{name} pid={pid} lines={len(lines)}")
    if not lines:
        print(
            "No OCR text. Grant Screen Recording to this terminal, then retry.",
            file=sys.stderr,
        )
        return 1
    for line in lines[:10]:
        print(f"  {line[:100]}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

"""Orbit CLI — entry point for the ``orbit`` command.

Commands:

- ``orbit start`` — run the capture daemon (default DB: ``~/.orbit/orbit.db``)
- ``orbit check`` — detect tasks from context and optionally dispatch one

On macOS, embeddings require a venv built with Homebrew Python (see README).
Use ``orbit start --no-embed`` when SQLite extensions are unavailable.
"""
from __future__ import annotations

import argparse
import sys


def main() -> None:
    parser = argparse.ArgumentParser(prog="orbit", description="Orbit context daemon")
    sub = parser.add_subparsers(dest="command", metavar="command")

    start_p = sub.add_parser("start", help="Start the capture daemon")
    start_p.add_argument("--db", default="~/.orbit/orbit.db", help="SQLite DB path (default: ~/.orbit/orbit.db)")
    start_p.add_argument("--no-embed", action="store_true", help="Skip embedding worker")
    start_p.add_argument(
        "--max-depth",
        type=int,
        default=None,
        help="Override AX tree depth (default: 12 native, 24 Electron, 20 Chromium)",
    )
    start_p.add_argument(
        "--browser-bridge-port",
        type=int,
        default=8765,
        help="Localhost port for browser companion extension (default: 8765)",
    )
    start_p.add_argument(
        "--no-browser-bridge",
        action="store_true",
        help="Disable browser extension HTTP ingest",
    )
    start_p.add_argument(
        "--ocr",
        action="store_true",
        help="Enable Tier 4 OCR fallback when AX capture fails",
    )
    start_p.add_argument(
        "--purge-retention",
        action="store_true",
        help="Delete capture events older than policy retention_days on startup",
    )
    start_p.add_argument(
        "--no-fsevents",
        action="store_true",
        help="Disable FSEvents workspace capture (even if tier_fsevents in policy)",
    )

    privacy_p = sub.add_parser("privacy", help="Export, delete, or configure capture privacy")
    privacy_sub = privacy_p.add_subparsers(dest="privacy_action", metavar="action")

    p_export = privacy_sub.add_parser("export", help="Export capture data to JSONL")
    p_export.add_argument("--db", default="~/.orbit/orbit.db")
    p_export.add_argument("--out", required=True)

    p_delete = privacy_sub.add_parser("delete", help="Delete all capture data")
    p_delete.add_argument("--db", default="~/.orbit/orbit.db")
    p_delete.add_argument("--yes", action="store_true")

    p_purge = privacy_sub.add_parser("purge", help="Delete events older than retention period")
    p_purge.add_argument("--db", default="~/.orbit/orbit.db")
    p_purge.add_argument("--days", type=int, default=None)

    p_policy = privacy_sub.add_parser("show-policy", help="Show ~/.orbit/policy.json")
    p_policy.add_argument("--policy", default="~/.orbit/policy.json")

    p_ocr = privacy_sub.add_parser("enable-ocr", help="Enable tier_ocr in policy.json")
    p_ocr.add_argument("--policy", default="~/.orbit/policy.json")

    p_fse = privacy_sub.add_parser(
        "enable-fsevents", help="Enable tier_fsevents in policy.json"
    )
    p_fse.add_argument("--policy", default="~/.orbit/policy.json")

    check_p = sub.add_parser("check", help="Detect tasks from context and dispatch to Claude")
    check_p.add_argument("action", nargs="?", choices=["skipped"], default=None,
                         help="'skipped' to review today's skipped tasks")
    check_p.add_argument("--context", default=None, help="Path to local context.md (fallback when --source local)")
    check_p.add_argument("--source", choices=["github", "local"], default="github",
                         help="Context source: github (default, westsoever/cos daily report) or local")
    check_p.add_argument("--date", default=None, help="Report date YYYY-MM-DD (default: today)")
    check_p.add_argument("--db", default="~/.orbit/orbit.db", help="SQLite DB path")
    check_p.add_argument("--dry-run", action="store_true", help="Detect and print tasks; skip notification and dispatch")
    check_p.add_argument("--no-notify", action="store_true", help="Skip macOS notification")
    check_p.add_argument("--refresh", action="store_true", help="Re-run LLM detection even if today's tasks are cached")

    args = parser.parse_args()

    if args.command == "start":
        import os

        from orbit.storage.db import sqlite_supports_extensions

        if not args.no_embed and not sqlite_supports_extensions():
            print(
                "WARNING: This Python build cannot load SQLite extensions; "
                "capture will run without embeddings.\n"
                f"  Interpreter: {sys.executable}\n"
                "  Fix: activate the project venv (source .venv/bin/activate) and use "
                "`python -c \"...\"` — not system `python3`.\n"
                "  Or recreate venv: /opt/homebrew/bin/python3 -m venv .venv && "
                "source .venv/bin/activate && pip install -e .\n"
                "  Capture-only: orbit start --no-embed\n",
                file=sys.stderr,
            )

        db_path = os.path.expanduser(args.db)
        os.makedirs(os.path.dirname(db_path), exist_ok=True)

        sys.argv = ["orbit-daemon", "--db", db_path]
        if args.no_embed:
            sys.argv.append("--no-embed")
        if args.max_depth is not None:
            sys.argv.extend(["--max-depth", str(args.max_depth)])
        if args.no_browser_bridge:
            sys.argv.append("--no-browser-bridge")
        if args.browser_bridge_port != 8765:
            sys.argv.extend(["--browser-bridge-port", str(args.browser_bridge_port)])
        if getattr(args, "ocr", False):
            sys.argv.append("--ocr")
        if getattr(args, "purge_retention", False):
            sys.argv.append("--purge-retention")
        if getattr(args, "no_fsevents", False):
            sys.argv.append("--no-fsevents")

        from orbit.capture.daemon import main as daemon_main
        daemon_main()

    elif args.command == "privacy":
        if not args.privacy_action:
            privacy_p.print_help()
            sys.exit(1)
        from orbit.privacy.store import run_privacy_command

        run_privacy_command(args)

    elif args.command == "check":
        argv = ["orbit-check"]
        if args.action:
            argv.append(args.action)
        argv += ["--source", args.source]
        if args.context:
            argv += ["--context", args.context]
        if args.date:
            argv += ["--date", args.date]
        if args.db:
            argv += ["--db", args.db]
        if args.dry_run:
            argv.append("--dry-run")
        if args.no_notify:
            argv.append("--no-notify")
        if args.refresh:
            argv.append("--refresh")
        sys.argv = argv

        from orbit.check.__main__ import main as check_main
        check_main()

    else:
        parser.print_help()

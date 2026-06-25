"""orbit CLI — entry point for the `orbit` command."""
from __future__ import annotations

import argparse
import sys


def main() -> None:
    parser = argparse.ArgumentParser(prog="orbit", description="Orbit context daemon")
    sub = parser.add_subparsers(dest="command", metavar="command")

    start_p = sub.add_parser("start", help="Start the capture daemon")
    start_p.add_argument("--db", default="~/.orbit/orbit.db", help="SQLite DB path (default: ~/.orbit/orbit.db)")
    start_p.add_argument("--no-embed", action="store_true", help="Skip embedding worker")

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
        db_path = os.path.expanduser(args.db)
        os.makedirs(os.path.dirname(db_path), exist_ok=True)

        sys.argv = ["orbit-daemon", "--db", db_path]
        if args.no_embed:
            sys.argv.append("--no-embed")

        from orbit.capture.daemon import main as daemon_main
        daemon_main()

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

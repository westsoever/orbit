"""Orbit CLI — entry point for the ``orbit`` command.

Commands:

- ``orbit start`` — run the capture daemon (default DB: ``~/.orbit/orbit.db``)
- ``orbit start --detach`` — run daemon in background (PID file + log)
- ``orbit stop`` — stop a detached daemon
- ``orbit check`` — detect tasks from context and optionally dispatch one

On macOS, embeddings require a venv built with Homebrew Python (see README).
Use ``orbit start --no-embed`` when SQLite extensions are unavailable.
"""
from __future__ import annotations

import argparse
import sys


def main() -> None:
    # Re-exec via .venv when python.org Python lacks SQLite extensions.
    from orbit.runtime import maybe_reexec_for_embeddings

    maybe_reexec_for_embeddings(sys.argv)

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
    start_p.add_argument(
        "--detach",
        action="store_true",
        help="Start daemon in background (logs to ~/.orbit/daemon.log)",
    )

    stop_p = sub.add_parser("stop", help="Stop a detached capture daemon")
    stop_p.add_argument(
        "--pid-file",
        default="~/.orbit/daemon.pid",
        help="PID file path (default: ~/.orbit/daemon.pid)",
    )
    stop_p.add_argument(
        "--timeout",
        type=float,
        default=10.0,
        help="Seconds to wait for graceful shutdown (default: 10)",
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

    doctor_p = sub.add_parser(
        "doctor",
        help="Diagnose Python/SQLite setup (embeddings require loadable extensions)",
    )

    args = parser.parse_args()

    if args.command == "doctor":
        from orbit.runtime import doctor_report, sqlite_supports_extensions

        print(doctor_report())
        sys.exit(0 if sqlite_supports_extensions() else 1)

    if args.command == "start":
        import os

        from orbit.runtime import sqlite_supports_extensions

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

        daemon_argv = sys.argv[1:]  # orbit-daemon flags without script name

        if args.detach:
            from orbit.daemon_ctl import build_daemon_argv, spawn_detached

            port = args.browser_bridge_port
            health_url = f"http://127.0.0.1:{port}/health"
            try:
                pid = spawn_detached(
                    build_daemon_argv(daemon_argv),
                    health_url=health_url,
                )
            except RuntimeError as exc:
                print(str(exc), file=sys.stderr)
                sys.exit(1)
            print(f"Orbit daemon started (pid {pid})")
            sys.exit(0)

        from orbit.capture.daemon import main as daemon_main
        daemon_main()

    elif args.command == "stop":
        import os

        from orbit.daemon_ctl import _health_ok, stop_daemon
        from orbit.daemon_pid import read_pid

        pid_file = os.path.expanduser(args.pid_file)
        if read_pid(pid_file) is None and not _health_ok():
            print("Orbit daemon is not running")
            sys.exit(0)
        if stop_daemon(pid_file=pid_file, timeout_s=args.timeout):
            print("Orbit daemon stopped")
            sys.exit(0)
        print("Orbit daemon did not stop in time", file=sys.stderr)
        sys.exit(1)

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

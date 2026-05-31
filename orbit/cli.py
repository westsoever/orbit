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
    else:
        parser.print_help()

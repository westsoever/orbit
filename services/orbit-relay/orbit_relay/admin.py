"""Admin CLI for the Orbit Cloud AI relay."""
from __future__ import annotations

import argparse
import sys

from orbit_relay.config import get_settings
from orbit_relay.store import RelayStore


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Orbit Cloud AI relay administration")
    sub = parser.add_subparsers(dest="command", required=True)

    revoke = sub.add_parser("revoke", help="Revoke a device by install_id")
    revoke.add_argument("--install-id", required=True, help="Client install UUID")

    args = parser.parse_args(argv)
    settings = get_settings()
    store = RelayStore(settings.database_path)

    if args.command == "revoke":
        if store.revoke_by_install_id(args.install_id):
            print(f"revoked install_id={args.install_id}")
            return 0
        print(f"install_id not found: {args.install_id}", file=sys.stderr)
        return 1

    return 1


if __name__ == "__main__":
    raise SystemExit(main())

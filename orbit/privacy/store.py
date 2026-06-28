"""CLI handlers for orbit privacy subcommands."""

from __future__ import annotations

import os
import sys
from pathlib import Path

from orbit.capture.policy import CapturePolicy, load_policy, save_policy
from orbit.privacy import export_capture_data, delete_all_capture_data, purge_older_than
from orbit.storage.db import open_db_plain


def run_privacy_command(args) -> None:
    action = getattr(args, "privacy_action", None) or getattr(args, "action", None)
    if action == "export":
        db_path = os.path.expanduser(args.db)
        out_path = Path(os.path.expanduser(args.out))
        con, _ = open_db_plain(db_path)
        n = export_capture_data(con, out_path)
        print(f"Exported {n} events to {out_path}")
        return

    if action == "delete":
        if not args.yes:
            print("Refusing to delete without --yes", file=sys.stderr)
            sys.exit(1)
        db_path = os.path.expanduser(args.db)
        con, _ = open_db_plain(db_path)
        delete_all_capture_data(con)
        print(f"Deleted all capture data in {db_path}")
        return

    if action == "purge":
        db_path = os.path.expanduser(args.db)
        policy = load_policy()
        days = args.days if args.days is not None else policy.retention_days
        con, _ = open_db_plain(db_path)
        n = purge_older_than(con, days)
        print(f"Purged {n} events older than {days} days")
        return

    if action == "show-policy":
        policy_path = Path(os.path.expanduser(args.policy))
        policy = load_policy(policy_path)
        print(f"Policy file: {policy_path}")
        for k, v in policy.__dict__.items():
            print(f"  {k}: {v}")
        return

    if action == "enable-ocr":
        policy_path = Path(os.path.expanduser(args.policy))
        policy = load_policy(policy_path)
        policy.tier_ocr = True
        save_policy(policy, policy_path)
        print(f"Enabled tier_ocr in {policy_path}")
        print("Also grant Screen Recording to Terminal/Python (see orbit/capture/PERMISSIONS.md)")
        return

    if action == "enable-fsevents":
        policy_path = Path(os.path.expanduser(args.policy))
        policy = load_policy(policy_path)
        policy.tier_fsevents = True
        save_policy(policy, policy_path)
        print(f"Enabled tier_fsevents in {policy_path}")
        print(f"Watching: {policy.watch_roots}")
        return

    raise SystemExit(f"Unknown action: {getattr(args, 'privacy_action', args.action)}")

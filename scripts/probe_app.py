#!/usr/bin/env python3
"""Probe AX capture for a running app (Phase 1 verification)."""
from __future__ import annotations

import argparse
import sys

from AppKit import NSWorkspace

from orbit.capture.ax_walker import count_tree_nodes, get_app_metadata, get_tree
from orbit.capture.extract import flatten_text_atoms
from orbit.capture.profiles import needs_ax_enablement, profile_depth_for


def _apps_by_bundle(bundle: str):
    return [
        a for a in NSWorkspace.sharedWorkspace().runningApplications()
        if a.activationPolicy() == 0 and (a.bundleIdentifier() or "") == bundle
    ]


def probe_pid(pid: int, bundle: str, depth: int | None) -> int:
    d = profile_depth_for(bundle, override=depth)
    enable = needs_ax_enablement(bundle)
    tree = get_tree(pid, max_depth=d, bundle_id=bundle)
    atoms = flatten_text_atoms(tree)
    meta = get_app_metadata(pid)
    print(f"bundle={bundle} pid={pid} depth={d} ax_enable={enable}")
    print(f"  nodes={count_tree_nodes(tree)} atoms={len(atoms)}")
    print(f"  window_title={meta.get('window_title')!r}")
    if atoms:
        print(f"  sample: {atoms[0]['role']}: {atoms[0]['text'][:80]!r}")
    return 0 if atoms else 1


def main() -> int:
    parser = argparse.ArgumentParser(description="Probe Orbit AX capture for an app")
    parser.add_argument("--bundle", help="App bundle ID (e.g. com.todesktop.230313mzl4w4u92)")
    parser.add_argument("--all-visible", action="store_true", help="Probe all regular apps")
    parser.add_argument("--max-depth", type=int, default=None)
    args = parser.parse_args()

    if args.all_visible:
        rc = 0
        for app in NSWorkspace.sharedWorkspace().runningApplications():
            if app.activationPolicy() != 0:
                continue
            bundle = app.bundleIdentifier() or ""
            name = app.localizedName() or bundle
            print(f"\n=== {name} ===")
            if probe_pid(int(app.processIdentifier()), bundle, args.max_depth):
                rc = 1
        return rc

    if not args.bundle:
        parser.error("Provide --bundle or --all-visible")
    apps = _apps_by_bundle(args.bundle)
    if not apps:
        print(f"No running app with bundle {args.bundle}", file=sys.stderr)
        return 1
    return probe_pid(int(apps[0].processIdentifier()), args.bundle, args.max_depth)


if __name__ == "__main__":
    raise SystemExit(main())

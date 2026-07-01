#!/usr/bin/env bash
# Create Orbit.dmg from a built Orbit.app (macOS only).
set -euo pipefail

APP="${1:-Orbit.app}"
OUT="${2:-Orbit.dmg}"

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "ERROR: DMG creation is macOS-only." >&2
  exit 1
fi

[[ -d "$APP" ]] || { echo "ERROR: $APP not found" >&2; exit 1; }

STAGING="$(mktemp -d)"
cleanup() { rm -rf "$STAGING"; }
trap cleanup EXIT

cp -R "$APP" "$STAGING/"
ln -s /Applications "$STAGING/Applications"

hdiutil create -volname "Orbit" -srcfolder "$STAGING" -ov -format UDZO "$OUT"
echo "Created $OUT"

#!/usr/bin/env bash
# Build and launch Orbit Access (SwiftUI macOS app).
set -euo pipefail

if [[ -d "/Applications/Orbit.app" && "${ORBIT_FORCE_DEV_BUILD:-}" != "1" ]]; then
  echo "Orbit is installed in /Applications."
  echo "Launch with: open -a Orbit"
  echo "Set ORBIT_FORCE_DEV_BUILD=1 to build from this repo instead."
  open -a Orbit 2>/dev/null || true
  exit 0
fi

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=orbit_access_bundle_resources.sh
source "$ROOT/scripts/orbit_access_bundle_resources.sh"
export ORBIT_ROOT="$ROOT"
APP_DIR="$ROOT/OrbitAccessApp"
BUNDLE="$ROOT/build/OrbitAccessApp.app"
BIN="$APP_DIR/.build/debug/OrbitAccessApp"
DAEMON_LOG="/tmp/orbit-daemon.log"

ensure_daemon() {
  if curl -sf http://127.0.0.1:8765/health >/dev/null; then
    echo "Orbit daemon already running."
    return 0
  fi
  echo "Orbit daemon not running; starting in background (log: $DAEMON_LOG)…"
  (
    cd "$ROOT"
    source .venv/bin/activate
    orbit start --detach --no-embed --no-statusbar --db ~/.orbit/orbit.db
  ) >>"$DAEMON_LOG" 2>&1
  local i
  for i in $(seq 1 10); do
    sleep 1
    if curl -sf http://127.0.0.1:8765/health >/dev/null; then
      echo "Daemon healthy after ${i}s."
      return 0
    fi
  done
  echo "Warning: daemon did not respond within 10s (see $DAEMON_LOG)" >&2
  return 1
}

ensure_daemon || true

cd "$APP_DIR"
echo "Building Orbit Access…"
swift build -c debug 2>&1

mkdir -p "$BUNDLE/Contents/MacOS" "$BUNDLE/Contents/Resources"
cp "$BIN" "$BUNDLE/Contents/MacOS/OrbitAccessApp"
cp Resources/Info.bundle.plist "$BUNDLE/Contents/Info.plist"
install_orbit_access_bundle_resources "$APP_DIR" "$BUNDLE" debug OrbitAccessApp
chmod +x "$BUNDLE/Contents/MacOS/OrbitAccessApp"

# Apply sandbox entitlements (direct ~/.orbit access, no Keychain bookmarks).
ENTITLEMENTS="$APP_DIR/OrbitAccessApp.entitlements"
if [[ -f "$ENTITLEMENTS" ]]; then
  codesign_orbit_access_bundle "$BUNDLE" OrbitAccessApp "$ENTITLEMENTS" \
    || echo "Warning: codesign failed; app icon and sandbox entitlements may be missing." >&2
fi

echo "Launching $BUNDLE"
open "$BUNDLE"

if [[ -d "$HOME/Applications/Orbit Access.app" ]]; then
  dev_bin="$BUNDLE/Contents/MacOS/OrbitAccessApp"
  old_bin="$HOME/Applications/Orbit Access.app/Contents/MacOS/OrbitAccessApp"
  if [[ -f "$dev_bin" && -f "$old_bin" && "$dev_bin" -nt "$old_bin" ]]; then
    echo ""
    echo "Note: open -a \"Orbit Access\" may launch an older copy at:"
    echo "  $HOME/Applications/Orbit Access.app"
    echo "For your latest changes, use this dev build or re-run this script."
    echo "To remove the stale copy: rm -rf \"$HOME/Applications/Orbit Access.app\""
    echo ""
  fi
fi

ORBIT_BIN="${ORBIT_ROOT}/.venv/bin/orbit"
if [[ -x "$ORBIT_BIN" ]]; then
  if ! curl -sf http://127.0.0.1:8765/health >/dev/null 2>&1; then
    echo "Starting Orbit daemon…"
    "$ORBIT_BIN" start --detach --no-embed --no-statusbar || true
    for _ in $(seq 1 40); do
      curl -sf http://127.0.0.1:8765/health >/dev/null 2>&1 && break
      sleep 0.25
    done
  fi
fi

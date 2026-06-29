#!/usr/bin/env bash
# Build Orbit Access from this repo and install to /Applications (dev workflow).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=orbit_access_bundle_resources.sh
source "$ROOT/scripts/orbit_access_bundle_resources.sh"
export ORBIT_ROOT="$ROOT"
APP_DIR="$ROOT/OrbitAccessApp"
BUNDLE="/Applications/Orbit Access.app"
BIN="$APP_DIR/.build/debug/OrbitAccessApp"
DAEMON_LOG="/tmp/orbit-daemon.log"
STALE_HOME_APP="$HOME/Applications/Orbit Access.app"
BROKEN_ORBIT_APP="/Applications/Orbit.app"

if [[ -d "$BROKEN_ORBIT_APP" ]]; then
  if [[ ! -x "$BROKEN_ORBIT_APP/Contents/MacOS/Orbit" && ! -x "$BROKEN_ORBIT_APP/Contents/MacOS/OrbitAccessApp" ]]; then
    echo "Removing incomplete $BROKEN_ORBIT_APP (cancelled bundle build)…"
    rm -rf "$BROKEN_ORBIT_APP"
  elif [[ "${ORBIT_REPLACE_PRODUCTION_APP:-}" == "1" ]]; then
    echo "Removing production $BROKEN_ORBIT_APP (ORBIT_REPLACE_PRODUCTION_APP=1)…"
    rm -rf "$BROKEN_ORBIT_APP"
  else
    echo "Note: $BROKEN_ORBIT_APP exists (production bundle). Dev installs to $BUNDLE instead."
    echo "Set ORBIT_REPLACE_PRODUCTION_APP=1 to remove it."
  fi
fi

if [[ -d "$STALE_HOME_APP" && "$STALE_HOME_APP" != "$BUNDLE" ]]; then
  echo "Removing stale copy at ${STALE_HOME_APP}…"
  rm -rf "$STALE_HOME_APP"
fi

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

rm -rf "$BUNDLE"
mkdir -p "$BUNDLE/Contents/MacOS" "$BUNDLE/Contents/Resources"
cp "$BIN" "$BUNDLE/Contents/MacOS/OrbitAccessApp"
cp Resources/Info.bundle.plist "$BUNDLE/Contents/Info.plist"
set_plist_lsenvironment "$BUNDLE/Contents/Info.plist" ORBIT_ROOT "$ROOT"
install_orbit_access_bundle_resources "$APP_DIR" "$BUNDLE" debug OrbitAccessApp
chmod +x "$BUNDLE/Contents/MacOS/OrbitAccessApp"

ENTITLEMENTS="$APP_DIR/OrbitAccessApp.entitlements"
if [[ -f "$ENTITLEMENTS" ]]; then
  codesign_orbit_access_bundle "$BUNDLE" OrbitAccessApp "$ENTITLEMENTS" \
    || echo "Warning: codesign failed; app icon and sandbox entitlements may be missing." >&2
fi

echo ""
echo "Installed dev build → $BUNDLE"
echo "  Swift UI: rebuilt from $APP_DIR"
echo "  Python daemon: $ROOT/.venv (run 'pip install -e .' after Python changes; restart daemon)"
echo "Launch: open -a \"Orbit Access\""
echo ""
open "$BUNDLE"

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

#!/usr/bin/env bash
# Build and launch Orbit Access (SwiftUI macOS app).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
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
    orbit start --no-embed --db ~/.orbit/orbit.db
  ) >>"$DAEMON_LOG" 2>&1 &
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
if [[ -d Resources/Assets.xcassets ]]; then
  cp -R Resources/Assets.xcassets "$BUNDLE/Contents/Resources/"
fi
chmod +x "$BUNDLE/Contents/MacOS/OrbitAccessApp"

echo "Launching $BUNDLE"
open "$BUNDLE"

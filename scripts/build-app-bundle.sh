#!/usr/bin/env bash
# Build a complete Orbit.app for /Applications (embedded Python venv + Swift UI).
# Pattern: scripts/run_orbit_access_app.sh bundle assembly; README.md Python venv setup.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=orbit_access_bundle_resources.sh
source "$ROOT/scripts/orbit_access_bundle_resources.sh"
SOURCE_ROOT="${ORBIT_SOURCE_ROOT:-$ROOT}"
APP_DIR="$SOURCE_ROOT/OrbitAccessApp"
ORBIT_OUTPUT="${ORBIT_OUTPUT:-}"
ORBIT_PYTHON="${ORBIT_PYTHON:-}"
ORBIT_SKIP_SWIFT="${ORBIT_SKIP_SWIFT:-0}"
SWIFT_CONFIG="release"

status() { echo ">>> $*" >&2; }
error() { echo "ERROR: $*" >&2; exit 1; }

usage() {
  cat >&2 <<'EOF'
Usage: scripts/build-app-bundle.sh --output /path/to/Orbit.app

Environment:
  ORBIT_SOURCE_ROOT   Repo root (default: parent of scripts/)
  ORBIT_PYTHON        Python 3.13 interpreter (auto-detected if unset)
  ORBIT_SKIP_SWIFT=1  Skip Swift build (Python-only bundle)
EOF
  exit 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --output)
      [[ $# -ge 2 ]] || usage
      ORBIT_OUTPUT="$2"
      shift 2
      ;;
    -h|--help) usage ;;
    *) error "Unknown argument: $1" ;;
  esac
done

[[ -n "$ORBIT_OUTPUT" ]] || usage

if [[ "$(uname -s)" != "Darwin" ]]; then
  error "Orbit.app builds are macOS-only."
fi

for tool in swift git; do
  command -v "$tool" >/dev/null 2>&1 || error "Required tool not found: $tool"
done

if [[ "$ORBIT_SKIP_SWIFT" != "1" ]]; then
  command -v swift >/dev/null 2>&1 || error "swift is required (set ORBIT_SKIP_SWIFT=1 to skip)"
fi

resolve_python() {
  if [[ -n "$ORBIT_PYTHON" ]]; then
    echo "$ORBIT_PYTHON"
    return
  fi
  for candidate in /opt/homebrew/bin/python3.13 /usr/local/bin/python3.13; do
    if [[ -x "$candidate" ]]; then
      echo "$candidate"
      return
    fi
  done
  error "Homebrew Python 3.13 not found. Install: brew install python@3.13"
}

probe_sqlite_extensions() {
  local py="$1"
  "$py" -c "import sqlite3; sqlite3.connect(':memory:').enable_load_extension(True)" 2>/dev/null
}

free_gb() {
  df -g "$(dirname "$ORBIT_OUTPUT")" 2>/dev/null | awk 'NR==2 {print $4}'
}

ORBIT_PYTHON="$(resolve_python)"
if ! probe_sqlite_extensions "$ORBIT_PYTHON"; then
  error "Python at $ORBIT_PYTHON lacks loadable SQLite extensions (use Homebrew python@3.13)."
fi

FREE_GB="$(free_gb || echo 0)"
if [[ "${FREE_GB:-0}" -lt 5 ]]; then
  status "WARNING: less than 5 GB free on target volume (have ${FREE_GB}G). Build may fail."
fi

[[ -f "$SOURCE_ROOT/pyproject.toml" ]] || error "Source root missing pyproject.toml: $SOURCE_ROOT"

RESOURCES="$ORBIT_OUTPUT/Contents/Resources"
MACOS="$ORBIT_OUTPUT/Contents/MacOS"
VENV="$RESOURCES/orbit-venv"
ORBIT_CORE="$RESOURCES/orbit-core"
CLI_WRAPPER="$RESOURCES/orbit"

status "Building Orbit.app at $ORBIT_OUTPUT"
rm -rf "$ORBIT_OUTPUT"
mkdir -p "$MACOS" "$RESOURCES" "$ORBIT_CORE/docs/gdpr"

status "Creating embedded Python venv…"
"$ORBIT_PYTHON" -m venv "$VENV"
# shellcheck disable=SC1091
source "$VENV/bin/activate"
pip install -q --upgrade pip
pip install -q "$SOURCE_ROOT"

status "Copying docs into orbit-core…"
cp -R "$SOURCE_ROOT/docs/gdpr/." "$ORBIT_CORE/docs/gdpr/"

status "Writing CLI wrapper…"
cat >"$CLI_WRAPPER" <<'WRAPPER'
#!/usr/bin/env bash
RESOURCES="$(cd "$(dirname "$0")" && pwd)"
export ORBIT_ROOT="$RESOURCES/orbit-core"
exec "$RESOURCES/orbit-venv/bin/python3.13" -m orbit "$@"
WRAPPER
chmod +x "$CLI_WRAPPER"

SWIFT_BIN=""
if [[ "$ORBIT_SKIP_SWIFT" != "1" ]]; then
  cd "$APP_DIR"
  if ! swift build -c release 2>&1; then
    status "Release build failed; falling back to debug…"
    SWIFT_CONFIG="debug"
    swift build -c debug 2>&1
  fi
  SWIFT_BIN="$APP_DIR/.build/$SWIFT_CONFIG/OrbitAccessApp"
  [[ -f "$SWIFT_BIN" ]] || error "Swift binary not found at $SWIFT_BIN"
  cp "$SWIFT_BIN" "$MACOS/Orbit"
  chmod +x "$MACOS/Orbit"

  if [[ -f "$APP_DIR/Resources/Info.bundle.plist" ]]; then
    cp "$APP_DIR/Resources/Info.bundle.plist" "$ORBIT_OUTPUT/Contents/Info.plist"
    /usr/libexec/PlistBuddy -c "Set :CFBundleExecutable Orbit" "$ORBIT_OUTPUT/Contents/Info.plist"
    /usr/libexec/PlistBuddy -c "Set :CFBundleName Orbit" "$ORBIT_OUTPUT/Contents/Info.plist"
  else
    error "Missing Info.bundle.plist"
  fi

  install_orbit_access_bundle_resources "$APP_DIR" "$ORBIT_OUTPUT" "$SWIFT_CONFIG"

  ENTITLEMENTS="$APP_DIR/OrbitAccessApp.entitlements"
  if [[ -f "$ENTITLEMENTS" ]]; then
    status "Codesigning (ad-hoc)…"
    codesign_orbit_access_bundle "$ORBIT_OUTPUT" Orbit "$ENTITLEMENTS" \
      || status "WARNING: codesign failed; app icon and sandbox entitlements may be missing."
  fi
else
  status "Skipping Swift build (ORBIT_SKIP_SWIFT=1)"
fi

status "Running orbit doctor…"
"$CLI_WRAPPER" doctor

status "Done: $ORBIT_OUTPUT"
if [[ -n "$SWIFT_BIN" ]]; then
  status "Launch with: open \"$ORBIT_OUTPUT\""
fi
status "CLI: \"$CLI_WRAPPER\""

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

FINAL_OUTPUT="$ORBIT_OUTPUT"
STAGING=""

status "Building Orbit.app at $FINAL_OUTPUT"
if [[ "$FINAL_OUTPUT" == /Applications/* ]]; then
  STAGING="$(mktemp -d)/Orbit.app"
  ORBIT_OUTPUT="$STAGING"
  status "Staging build in $STAGING (moves to $FINAL_OUTPUT when complete)…"
else
  ORBIT_OUTPUT="$FINAL_OUTPUT"
fi

RESOURCES="$ORBIT_OUTPUT/Contents/Resources"
MACOS="$ORBIT_OUTPUT/Contents/MacOS"
VENV="$RESOURCES/orbit-venv"
ORBIT_CORE="$RESOURCES/orbit-core"
CLI_WRAPPER="$RESOURCES/orbit"

cleanup_staging() {
  if [[ -n "${STAGING:-}" && -d "$STAGING" ]]; then
    rm -rf "$STAGING"
  fi
}
trap cleanup_staging EXIT

rm -rf "$ORBIT_OUTPUT"
mkdir -p "$MACOS" "$RESOURCES" "$ORBIT_CORE/docs/gdpr"

status "Creating embedded Python venv…"
"$ORBIT_PYTHON" -m venv "$VENV"
# shellcheck disable=SC1091
source "$VENV/bin/activate"
status "Upgrading pip…"
pip install --upgrade pip
status "Installing Orbit into venv (PyTorch + sentence-transformers; often 5–15 min, downloads ~1–2 GB)…"
pip install "$SOURCE_ROOT"

status "Verifying embedded package data…"
SCHEMA="$VENV/lib/python3.13/site-packages/orbit/storage/schema.sql"
if [[ ! -f "$SCHEMA" ]]; then
  echo "ERROR: schema.sql missing from embedded venv ($SCHEMA)." >&2
  echo "Ensure pyproject.toml [tool.setuptools.package-data] ships storage/schema.sql." >&2
  exit 1
fi

status "Smoke-testing DB open…"
"$VENV/bin/python3.13" -c "import tempfile, os; from orbit.storage.db import open_db_plain; open_db_plain(os.path.join(tempfile.mkdtemp(),'t.db')); print('db ok')"

status "Copying docs into orbit-core…"
cp -R "$SOURCE_ROOT/docs/gdpr/." "$ORBIT_CORE/docs/gdpr/"

status "Bundling browser extension…"
if [ -d "$SOURCE_ROOT/orbit/browser-extension" ]; then
  cp -R "$SOURCE_ROOT/orbit/browser-extension" "$RESOURCES/browser-extension"
fi

status "Writing .env.example scaffold…"
mkdir -p "$ORBIT_CORE"
cat >"$ORBIT_CORE/.env.example" <<'ENVEXAMPLE'
# Orbit AI configuration — copy lines to ~/.orbit/.env
# OPENROUTER_API_KEY=sk-or-v1-your-key-here
# ORBIT_LLM_PROVIDER=byok
# ORBIT_LLM_PROVIDER=local
# ORBIT_LOCAL_LLM_MODEL=llama3.1
ENVEXAMPLE

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
  SWIFT_FLAGS=(-Xswiftc -strict-concurrency=minimal)
  if ! swift build -c release "${SWIFT_FLAGS[@]}" 2>&1; then
    status "Release build failed; falling back to debug…"
    SWIFT_CONFIG="debug"
    swift build -c debug "${SWIFT_FLAGS[@]}" 2>&1
  fi
  SWIFT_BIN="$APP_DIR/.build/$SWIFT_CONFIG/OrbitAccessApp"
  [[ -f "$SWIFT_BIN" ]] || error "Swift binary not found at $SWIFT_BIN"
  cp "$SWIFT_BIN" "$MACOS/Orbit"
  chmod +x "$MACOS/Orbit"

  if [[ -f "$APP_DIR/Resources/Info.bundle.plist" ]]; then
    cp "$APP_DIR/Resources/Info.bundle.plist" "$ORBIT_OUTPUT/Contents/Info.plist"
    /usr/libexec/PlistBuddy -c "Set :CFBundleExecutable Orbit" "$ORBIT_OUTPUT/Contents/Info.plist"
    /usr/libexec/PlistBuddy -c "Set :CFBundleName Orbit" "$ORBIT_OUTPUT/Contents/Info.plist"
    if [[ -n "${ORBIT_RELAY_URL:-}" ]]; then
      status "Injecting ORBIT_RELAY_URL into LSEnvironment ($ORBIT_RELAY_URL)…"
      /usr/libexec/PlistBuddy -c "Add :LSEnvironment dict" "$ORBIT_OUTPUT/Contents/Info.plist" 2>/dev/null || true
      /usr/libexec/PlistBuddy -c "Add :LSEnvironment:ORBIT_RELAY_URL string $ORBIT_RELAY_URL" "$ORBIT_OUTPUT/Contents/Info.plist" 2>/dev/null \
        || /usr/libexec/PlistBuddy -c "Set :LSEnvironment:ORBIT_RELAY_URL $ORBIT_RELAY_URL" "$ORBIT_OUTPUT/Contents/Info.plist"
    fi
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

if [[ -n "$STAGING" ]]; then
  status "Installing to $FINAL_OUTPUT…"
  rm -rf "$FINAL_OUTPUT"
  mv "$STAGING" "$FINAL_OUTPUT"
  trap - EXIT
  STAGING=""
fi

status "Done: $FINAL_OUTPUT"
if [[ -n "$SWIFT_BIN" ]]; then
  status "Launch with: open \"$FINAL_OUTPUT\""
fi
status "CLI: \"$FINAL_OUTPUT/Contents/Resources/orbit\""

#!/usr/bin/env bash
# Install Orbit to /Applications (Ollama-style). macOS only.
# Pattern: ollama/ollama scripts/install.sh Darwin block; build-app-bundle.sh for v1 source builds.
main() {
  set -eu

  ORBIT_VERSION="${ORBIT_VERSION:-}"
  ORBIT_NO_START="${ORBIT_NO_START:-}"
  ORBIT_INSTALL_FROM_SOURCE="${ORBIT_INSTALL_FROM_SOURCE:-0}"
  ORBIT_REPO_URL="${ORBIT_REPO_URL:-https://github.com/westsoever/orbit.git}"
  ORBIT_BRANCH="${ORBIT_BRANCH:-main}"
  ORBIT_GITHUB_REPO="${ORBIT_GITHUB_REPO:-westsoever/orbit}"

  APP_PATH="/Applications/Orbit.app"
  ORBIT_CLI="$APP_PATH/Contents/Resources/orbit"

  status() { echo ">>> $*" >&2; }
  error() { echo "ERROR: $*" >&2; exit 1; }

  if [ "$(uname -s)" != "Darwin" ]; then
    error "This installer is macOS-only."
  fi

  NEEDS=""
  for tool in curl git unzip; do
    command -v "$tool" >/dev/null 2>&1 || NEEDS="$NEEDS $tool"
  done
  if [ -n "$NEEDS" ]; then
    error "Missing required tools:$NEEDS"
  fi

  TEMP_DIR="$(mktemp -d)"
  cleanup() { rm -rf "$TEMP_DIR"; }
  trap cleanup EXIT

  stop_running_orbit() {
    if curl -sf http://127.0.0.1:8765/health >/dev/null 2>&1; then
      status "Stopping running Orbit daemon…"
      if [ -x "$ORBIT_CLI" ]; then
        "$ORBIT_CLI" stop 2>/dev/null || true
      elif command -v orbit >/dev/null 2>&1; then
        orbit stop 2>/dev/null || true
      fi
      sleep 1
    fi
    if pgrep -x Orbit >/dev/null 2>&1; then
      status "Stopping Orbit app…"
      pkill -x Orbit 2>/dev/null || true
      sleep 1
    fi
  }

  resolve_latest_release_version() {
    curl -sf "https://api.github.com/repos/${ORBIT_GITHUB_REPO}/releases/latest" \
      | sed -n 's/.*"tag_name"[[:space:]]*:[[:space:]]*"v\([^"]*\)".*/\1/p' \
      | head -1
  }

  ensure_homebrew_python() {
    if [ -x /opt/homebrew/bin/python3.13 ]; then
      ORBIT_PYTHON=/opt/homebrew/bin/python3.13
    elif [ -x /usr/local/bin/python3.13 ]; then
      ORBIT_PYTHON=/usr/local/bin/python3.13
    else
      ORBIT_PYTHON=""
    fi

    if [ -n "$ORBIT_PYTHON" ] && "$ORBIT_PYTHON" -c "import sqlite3; sqlite3.connect(':memory:').enable_load_extension(True)" 2>/dev/null; then
      export ORBIT_PYTHON
      return 0
    fi

    if ! command -v brew >/dev/null 2>&1; then
      error "Homebrew is required. Install from https://brew.sh then re-run this script."
    fi

    status "Installing Homebrew Python 3.13 (required for Orbit)…"
    brew install python@3.13
    ORBIT_PYTHON=/opt/homebrew/bin/python3.13
    [ -x "$ORBIT_PYTHON" ] || ORBIT_PYTHON=/usr/local/bin/python3.13
    [ -x "$ORBIT_PYTHON" ] || error "python@3.13 not found after brew install"
    export ORBIT_PYTHON
  }

  install_from_release() {
    local ver="$1"
    local url="https://github.com/${ORBIT_GITHUB_REPO}/releases/download/v${ver}/Orbit-darwin.zip"
    status "Downloading Orbit v${ver}…"
    if ! curl --fail --show-error --location --progress-bar \
      -o "$TEMP_DIR/Orbit-darwin.zip" "$url"; then
      return 1
    fi
    status "Installing Orbit to /Applications…"
    unzip -q "$TEMP_DIR/Orbit-darwin.zip" -d "$TEMP_DIR"
    [ -d "$TEMP_DIR/Orbit.app" ] || error "Orbit.app not found in release zip"
    mv "$TEMP_DIR/Orbit.app" "/Applications/"
    return 0
  }

  install_from_source() {
    command -v swift >/dev/null 2>&1 || error "Swift toolchain required (xcode-select --install)"

    ensure_homebrew_python

    local src=""
    if [ -n "${ORBIT_LOCAL_SRC:-}" ] && [ -d "$ORBIT_LOCAL_SRC" ]; then
      src="$ORBIT_LOCAL_SRC"
      status "Using local source tree: $src"
    else
      status "Fetching Orbit source…"
      git clone --depth 1 --branch "$ORBIT_BRANCH" "$ORBIT_REPO_URL" "$TEMP_DIR/src"
      src="$TEMP_DIR/src"
    fi

    status "Building Orbit.app (this may take a few minutes)…"
    export ORBIT_SOURCE_ROOT="$src"
    bash "$src/scripts/build-app-bundle.sh" --output "$APP_PATH"
  }

  status "Installing Orbit…"
  stop_running_orbit

  if [ -d "$APP_PATH" ]; then
    status "Removing existing Orbit installation…"
    rm -rf "$APP_PATH"
  fi

  installed=0
  if [ "$ORBIT_INSTALL_FROM_SOURCE" != "1" ]; then
    if [ -z "$ORBIT_VERSION" ]; then
      ORBIT_VERSION="$(resolve_latest_release_version || true)"
      if [ -n "$ORBIT_VERSION" ]; then
        status "Using latest release v${ORBIT_VERSION}…"
      fi
    fi
    if [ -n "$ORBIT_VERSION" ]; then
      if install_from_release "$ORBIT_VERSION"; then
        installed=1
      else
        status "Pre-built release unavailable; falling back to source build…"
      fi
    fi
  fi

  if [ "$installed" -eq 0 ]; then
    install_from_source
  fi

  [ -x "$ORBIT_CLI" ] || error "Install failed: CLI wrapper missing at $ORBIT_CLI"

  status "Adding 'orbit' command to PATH (may require password)…"
  if mkdir -p /usr/local/bin 2>/dev/null && ln -sf "$ORBIT_CLI" /usr/local/bin/orbit 2>/dev/null; then
    :
  elif sudo -n ln -sf "$ORBIT_CLI" /usr/local/bin/orbit 2>/dev/null; then
    :
  elif sudo ln -sf "$ORBIT_CLI" /usr/local/bin/orbit; then
    :
  else
    status "Could not link /usr/local/bin/orbit. Run manually:"
    status "  sudo ln -sf \"$ORBIT_CLI\" /usr/local/bin/orbit"
    status "Or use: \"$ORBIT_CLI\""
  fi

  if [ -z "$ORBIT_NO_START" ]; then
    status "Opening Orbit…"
    open -a Orbit
  fi

  status "Install complete. Open Orbit from Applications or run 'orbit'."
  status "First launch: complete the setup wizard, sign in or create an account, then grant Accessibility."
  status "User data directory: ~/.orbit/"
  status "Friend beta guide: docs/FRIEND_BETA_GUIDE.md"
}

main "$@"

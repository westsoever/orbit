# Plan: One-Line Install → `/Applications/Orbit.app`

**Goal:** A new macOS user pastes one command (Ollama-style), gets **Orbit.app in `/Applications`**, can launch it from Spotlight/Dock, and can run `orbit` from any terminal. User data lives in `~/.orbit/` — not a second “project folder” in `$HOME`.

**Target repo:** `https://github.com/westsoever/orbit` (public)

**Reference:** [Ollama `scripts/install.sh`](https://github.com/ollama/ollama/blob/main/scripts/install.sh) + [Ollama README](https://github.com/ollama/ollama/blob/main/README.md) (`curl -fsSL https://ollama.com/install.sh | sh`)

**Execution model:** Run phases in order; each phase is self-contained for a fresh chat context.

---

## Phase 0: Documentation Discovery (completed)

### Ollama macOS install pattern (copy this UX)

**Source:** `https://raw.githubusercontent.com/ollama/ollama/main/scripts/install.sh` (Darwin block)

| Step | Ollama behavior | Orbit equivalent |
|------|-----------------|------------------|
| One-liner | `curl -fsSL https://ollama.com/install.sh \| sh` | `curl -fsSL https://raw.githubusercontent.com/westsoever/orbit/main/scripts/install.sh \| bash` |
| Install unit | `/Applications/Ollama.app` | `/Applications/Orbit.app` |
| CLI location | `/Applications/Ollama.app/Contents/Resources/ollama` | `/Applications/Orbit.app/Contents/Resources/orbit` (wrapper → embedded venv) |
| PATH | `ln -sf …/Ollama.app/Contents/Resources/ollama /usr/local/bin/ollama` (sudo fallback) | Same pattern for `orbit` |
| Upgrade | `rm -rf /Applications/Ollama.app` then reinstall | Same |
| First launch | `open -a Ollama --args hidden` (unless `OLLAMA_NO_START`) | `open -a Orbit` (unless `ORBIT_NO_START`) |
| User data | `~/.ollama/` (not inside app bundle) | `~/.orbit/orbit.db`, policy, logs (already canonical) |
| Artifact | Pre-built `Ollama-darwin.zip` from CDN | **v1:** build on install; **v2:** `Orbit-darwin.zip` from GitHub Releases |

**Ollama does NOT:** clone a dev repo to `~/ollama`, use `~/.local/bin`, or require `source .venv/bin/activate`.

### Allowed APIs & patterns (verified in Orbit repo)

| Capability | Source | Exact API / command |
|------------|--------|---------------------|
| Python package | `pyproject.toml:1-21` | `pip install` into bundle venv (not editable `-e` in production bundle) |
| Python version | `pyproject.toml:4`, `README.md:114` | Homebrew `python@3.13` for `enable_load_extension` |
| SQLite probe | `orbit/runtime.py:11-14` | Extension check before declaring install success |
| Doctor | `orbit/runtime.py:95-129` | `orbit doctor` |
| Daemon | `README.md:139`, `run_orbit_access_app.sh:20` | `orbit start --detach --no-embed --no-statusbar --db ~/.orbit/orbit.db` |
| Swift app bundle | `scripts/run_orbit_access_app.sh:36-56` | `swift build` + manual `.app` + ad-hoc `codesign` |
| Bundle metadata | `OrbitAccessApp/Resources/Info.bundle.plist` | `com.orbit.access`, macOS 14+ |
| Data paths | `OrbitAccessApp/Extensions/OrbitPaths.swift:4-10` | `~/.orbit/orbit.db` (already app-sandbox friendly) |
| Permissions | `orbit/capture/PERMISSIONS.md` | Accessibility for capture (human step post-install) |

### Anti-patterns (do NOT use)

| Anti-pattern | Why |
|--------------|-----|
| Install clone to `~/orbit` as the product | Feels like a dev checkout, not an app (user requirement) |
| `~/.local/bin/orbit` only | Ollama uses `/usr/local/bin`; app bundle should be source of truth |
| `pip install -e .` in `/Applications` | Editable install ties bundle to a git working tree; use normal install into bundle venv |
| python.org macOS installer | No SQLite extensions (`orbit/storage/db.py:7-36`) |
| Assume `~/gitall/orbit` | `DaemonManager.swift:47` — replace with `/Applications/Orbit.app/…` |
| Skip `/Applications` move | User explicitly wants Applications-folder install |
| Auto-grant Accessibility | Not scriptable on macOS |

### Known gaps

- No `install.sh` or `build-app-bundle.sh` yet
- No GitHub Release zip (Ollama downloads pre-built artifact; Orbit must build v1 on install or add CI)
- Bundle currently named `OrbitAccessApp.app` in `build/` — rebrand to `Orbit.app` for `/Applications`
- `ORBIT_ROOT` today points at git repo; installed app needs `ORBIT_ROOT` = `Contents/Resources/orbit-core` (or similar) inside bundle
- First install needs Xcode CLT + Swift + Homebrew Python (~5GB SPM cache per `ISSUE_REPORT.md`)

### Confidence

**High** on target UX (Ollama parity). **Medium** on v1 “build during install” duration (acceptable if progress messages like Ollama’s `>>> status`).

---

## Product decisions (locked for this plan)

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Install location | `/Applications/Orbit.app` | User request + Ollama pattern |
| User data | `~/.orbit/` only | Local-first; survives app upgrades |
| CLI on PATH | `/usr/local/bin/orbit` → bundle wrapper | Ollama `install.sh` lines 99–103 |
| One-liner | `curl -fsSL …/install.sh \| bash` | Ollama README pattern |
| Default post-install | `open -a Orbit` | Ollama `open -a Ollama` |
| Dev clones | Unchanged (`git clone` anywhere) | `run_orbit_access_app.sh` stays for contributors |
| Release artifact | Phase 4 (GitHub zip) | True Ollama parity; Phase 1–3 work without it |

---

## Target bundle layout (Ollama-shaped)

Copy structure from Ollama (`Contents/Resources/<cli>`) and existing `run_orbit_access_app.sh:40-46`:

```
/Applications/Orbit.app/
  Contents/
    MacOS/
      Orbit                    # SwiftUI binary (menu bar + main window)
    Resources/
      orbit                      # #!/bin/sh wrapper → orbit-venv/bin/orbit "$@"
      orbit-venv/                # Python 3.13 venv with `pip install .` (non-editable)
      orbit-core/                # Installed package tree + docs/gdpr for OrbitPaths
        docs/gdpr/PRIVACY_POLICY.md
      Assets.xcassets/           # if present
    Info.plist                   # CFBundleName: Orbit; CFBundleExecutable: Orbit
```

**`ORBIT_ROOT` for installed app:** set in wrapper and Swift launch env to  
`/Applications/Orbit.app/Contents/Resources/orbit-core`.

**Wrapper (`Contents/Resources/orbit`)** — copy Ollama’s symlink target pattern:

```bash
#!/usr/bin/env bash
ORBIT_ROOT="/Applications/Orbit.app/Contents/Resources/orbit-core"
export ORBIT_ROOT
exec "/Applications/Orbit.app/Contents/Resources/orbit-venv/bin/orbit" "$@"
```

Use `@executable_path/../Resources/…` if implementing a relocatable wrapper (preferred over hardcoded `/Applications` inside the binary).

---

## Phase 1: `scripts/build-app-bundle.sh`

### What to implement

New script that **outputs a complete `Orbit.app`** ready for `/Applications`. Copy assembly logic from `scripts/run_orbit_access_app.sh:36-56`; extend with Python embedding.

**Documentation references:**
- `scripts/run_orbit_access_app.sh` — Swift build + bundle dirs + codesign
- `README.md:113-122` — Homebrew Python + venv + pip
- `OrbitAccessApp/Resources/Info.bundle.plist` — plist fields to update (`CFBundleName` → `Orbit`, `CFBundleExecutable` → `Orbit`)

### Script contract

```bash
# Usage: scripts/build-app-bundle.sh [--output /path/to/Orbit.app]
ORBIT_BUILD_ROOT="${ORBIT_BUILD_ROOT:-$(mktemp -d)}"   # clone/build staging
ORBIT_OUTPUT="${ORBIT_OUTPUT:-$ORBIT_BUILD_ROOT/Orbit.app}"
ORBIT_PYTHON="${ORBIT_PYTHON:-/opt/homebrew/bin/python3.13}"
ORBIT_SKIP_SWIFT=0    # for CI split builds
```

### Steps

1. **Guards:** Darwin; `swift`, `curl`, `git` available; warn if disk < 5GB free
2. **Stage source:** shallow clone to `$ORBIT_BUILD_ROOT/src` (or use `$(dirname $0)/..` when run from repo)
3. **Python venv inside bundle:**  
   `"$ORBIT_PYTHON" -m venv "$ORBIT_OUTPUT/Contents/Resources/orbit-venv"`  
   `"$ORBIT_OUTPUT/.../pip" install "$ORBIT_BUILD_ROOT/src"` ( **`pip install .`**, not `-e` )
4. **Copy `docs/gdpr/`** into `Contents/Resources/orbit-core/docs/gdpr/`
5. **Write `Contents/Resources/orbit` wrapper** (executable)
6. **Swift build** (from `OrbitAccessApp/`): release if `swift build -c release` works, else debug
7. **Copy binary** to `Contents/MacOS/Orbit` (rename from `OrbitAccessApp`)
8. **Info.plist** — `CFBundleExecutable=Orbit`, `CFBundleName=Orbit`, keep `com.orbit.access`
9. **codesign** ad-hoc with `OrbitAccessApp.entitlements` (same as run script)
10. **Probe:** `"$ORBIT_OUTPUT/Contents/Resources/orbit" doctor`

### Verification checklist

```bash
scripts/build-app-bundle.sh --output /tmp/Orbit.app
/tmp/Orbit.app/Contents/Resources/orbit doctor
open /tmp/Orbit.app   # GUI launches
/tmp/Orbit.app/Contents/Resources/orbit start --detach --no-embed
curl -s http://127.0.0.1:8765/health
```

### Anti-pattern guards

- Do not leave output in repo `build/` as the install artifact — script accepts `--output`
- Do not use editable install inside `/Applications`
- Do not store `~/.orbit` data inside the bundle

---

## Phase 2: `scripts/install.sh` (Ollama-style one-liner)

### What to implement

Create `scripts/install.sh` by **copying Ollama’s macOS block structure** (`main()`, `status()`, `error()`, `TEMP_DIR`, Darwin guard, remove old app, install to `/Applications`, symlink CLI, `open -a`).

**Copy patterns from:**
- Ollama `scripts/install.sh` Darwin section (lines ~40–108): zip download → `/Applications` → `/usr/local/bin` symlink → `open -a`
- Phase 1 `build-app-bundle.sh` when no release zip exists

### Script contract

```bash
ORBIT_VERSION="${ORBIT_VERSION:-}"           # optional ?version= for release URL
ORBIT_NO_START="${ORBIT_NO_START:-}"         # skip open -a Orbit
ORBIT_INSTALL_FROM_SOURCE="${ORBIT_INSTALL_FROM_SOURCE:-1}"  # 1 until release zip exists
ORBIT_REPO_URL="${ORBIT_REPO_URL:-https://github.com/westsoever/orbit.git}"
ORBIT_BRANCH="${ORBIT_BRANCH:-main}"
```

### Steps (macOS)

1. `status "Installing Orbit…"` / `set -eu` / `mktemp -d` + trap cleanup
2. **Stop running instance:** `pkill -x Orbit` or check bridge shutdown (gentler than Ollama if needed)
3. **Remove prior install:** `rm -rf /Applications/Orbit.app`
4. **Install artifact (two modes):**
   - **v2 (preferred when available):** `curl` `Orbit-darwin.zip` from GitHub Release → `unzip` → `mv Orbit.app /Applications/` (mirror Ollama zip path)
   - **v1 (default until Phase 4):** shallow `git clone` to `$TEMP_DIR/src` → `bash scripts/build-app-bundle.sh --output $TEMP_DIR/Orbit.app` → `mv $TEMP_DIR/Orbit.app /Applications/`
5. **Homebrew Python:** if building from source, ensure `brew install python@3.13` (Ollama doesn’t need this; Orbit does — print clear `>>> Installing dependencies…`)
6. **CLI symlink** (copy Ollama exactly):

   ```bash
   ORBIT_CLI="/Applications/Orbit.app/Contents/Resources/orbit"
   mkdir -p /usr/local/bin 2>/dev/null || sudo mkdir -p /usr/local/bin
   ln -sf "$ORBIT_CLI" /usr/local/bin/orbit 2>/dev/null || \
     sudo ln -sf "$ORBIT_CLI" /usr/local/bin/orbit
   ```

7. **Start app** unless `ORBIT_NO_START`: `open -a Orbit`
8. **Success:** `status "Install complete. Open Orbit from Applications or run 'orbit'."`
9. **Permissions reminder:** print link to `orbit/capture/PERMISSIONS.md` — enable **Orbit** (and Terminal for CLI) under Accessibility

### Verification checklist

```bash
curl -fsSL https://raw.githubusercontent.com/westsoever/orbit/main/scripts/install.sh | bash
test -d /Applications/Orbit.app
readlink /usr/local/bin/orbit   # → …/Orbit.app/Contents/Resources/orbit
orbit doctor
ls /Applications/Orbit.app   # visible in Finder → Applications
```

### Anti-pattern guards

- Do not install to `~/orbit` or `~/.local/bin` as primary path
- Do not require `source .venv` in user docs
- Wrap script in `main()` so truncated curl download doesn’t execute half a script (Ollama pattern)

---

## Phase 3: App resolves installed bundle paths

### What to implement

**`OrbitAccessApp/Services/DaemonManager.swift`** — replace dev-only candidates with Applications-first (lines 43–56):

```swift
candidates.append(URL(fileURLWithPath: "/Applications/Orbit.app/Contents/Resources/orbit"))
// keep: ORBIT_ROOT/.venv/bin/orbit (dev), which("orbit") (symlink)
// remove: home.appendingPathComponent("gitall/orbit/…")
```

**`OrbitAccessApp/Extensions/OrbitPaths.swift`** — add bundle-relative privacy policy:

```swift
// /Applications/Orbit.app/Contents/Resources/orbit-core/docs/gdpr/PRIVACY_POLICY.md
Bundle.main.bundleURL
  .appendingPathComponent("Contents/Resources/orbit-core/docs/gdpr/PRIVACY_POLICY.md")
```

Set `ORBIT_ROOT` in app launch (`AppDelegate` or `DaemonManager`) when unset:

```swift
ProcessInfo.processInfo.environment["ORBIT_ROOT"]
  ?? Bundle.main.bundleURL.appendingPathComponent("Contents/Resources/orbit-core").path
```

**`scripts/run_orbit_access_app.sh`** — keep for dev; optionally detect `/Applications/Orbit.app` and suggest `open -a Orbit` instead.

### Verification checklist

- Install via `install.sh` → launch from Applications (not run script)
- Sidebar **Start/Stop** daemon works without dev `ORBIT_ROOT`
- Privacy policy opens in installed app

### Anti-pattern guards

- Do not hardcode `~/gitall/orbit` or `~/orbit`

---

## Phase 4: GitHub Release zip (Ollama production parity)

### What to implement

When ready, add CI workflow that runs `build-app-bundle.sh`, zips `Orbit.app` → `Orbit-darwin.zip`, attaches to GitHub Release.

**Copy Ollama download pattern** in `install.sh`:

```bash
DOWNLOAD_URL="https://github.com/westsoever/orbit/releases/download/v${VERSION}/Orbit-darwin.zip"
curl … -o "$TEMP_DIR/Orbit-darwin.zip" "$DOWNLOAD_URL"
unzip -q "$TEMP_DIR/Orbit-darwin.zip" -d "$TEMP_DIR"
mv "$TEMP_DIR/Orbit.app" "/Applications/"
```

Set `ORBIT_INSTALL_FROM_SOURCE=0` by default once releases are stable.

### Verification checklist

- Install on machine **without** git/Xcode: download-only path works
- Upgrade: reinstall replaces `/Applications/Orbit.app`; `~/.orbit/` preserved

---

## Phase 5: README.md install hero (Ollama-shaped)

### What to implement

Add **Install** section at top (mirror Ollama README “Download → macOS”):

```markdown
## Install

**macOS 14+**

```bash
curl -fsSL https://raw.githubusercontent.com/westsoever/orbit/main/scripts/install.sh | bash
```

Orbit installs to **Applications**. User data is stored in `~/.orbit/`.

After install, grant **Accessibility** to Orbit ([guide](orbit/capture/PERMISSIONS.md)) so capture works.

```bash
orbit start --detach --no-embed   # optional: daemon from Terminal
orbit doctor
```

**Uninstall:** `rm -rf /Applications/Orbit.app /usr/local/bin/orbit` (add `~/.orbit` if deleting data).
```

Remove `~/orbit` / `~/.local/bin` references from install docs. Keep developer setup in a separate **Development** section (`git clone`, `run_orbit_access_app.sh`, `pip install -e .`).

### Verification checklist

- [ ] README matches Ollama-style brevity for install
- [ ] No conflicting paths (`~/orbit` gone from install hero)
- [ ] curl URL matches `main` branch

---

## Final Phase: Verification

### Manual (public-user simulation)

1. Clean Mac or VM without existing Orbit
2. `curl -fsSL …/install.sh | bash`
3. Confirm **Finder → Applications → Orbit**
4. Launch Orbit; grant Accessibility to **Orbit.app**
5. Start capture from UI; `curl :8765/health` OK
6. New terminal: `orbit doctor`, `orbit stop` (CLI via `/usr/local/bin`)
7. Re-run install → upgrade replaces app; `~/.orbit/orbit.db` intact

### Automated (maintainer / CI)

```bash
bash scripts/build-app-bundle.sh --output /tmp/Orbit.app
/tmp/Orbit.app/Contents/Resources/orbit doctor
# Full verify.sh still runs from dev clone with pip install -e .
```

### Anti-pattern grep

```bash
rg 'gitall/orbit|~/orbit|\.local/bin/orbit' --glob '!plans/**'   # zero in install path code after Phase 3
```

---

## Suggested README hero (final copy target)

```markdown
## Install

### macOS

```shell
curl -fsSL https://raw.githubusercontent.com/westsoever/orbit/main/scripts/install.sh | bash
```

Installs **Orbit** to `/Applications`. Run `orbit` from the terminal or open the app from Spotlight.

Grant **Accessibility** to Orbit before capture ([permissions guide](orbit/capture/PERMISSIONS.md)).

Data directory: `~/.orbit/`
```

---

## Phase → chat prompt cheatsheet

| Phase | Paste into new chat |
|-------|---------------------|
| 1 | "Implement `scripts/build-app-bundle.sh` per `plans/10-one-line-install.md` Phase 1. Output `/Applications`-ready `Orbit.app` with embedded venv at `Contents/Resources/orbit-venv` and CLI wrapper at `Contents/Resources/orbit`. Copy bundle assembly from `run_orbit_access_app.sh`." |
| 2 | "Implement Ollama-style `scripts/install.sh` per Phase 2 of `plans/10-one-line-install.md`. Install to `/Applications/Orbit.app`, symlink `/usr/local/bin/orbit`, `open -a Orbit`." |
| 3 | "Update DaemonManager.swift and OrbitPaths.swift per Phase 3 — resolve CLI and docs from `/Applications/Orbit.app`." |
| 4 | "Add GitHub Release workflow for `Orbit-darwin.zip` per Phase 4." |
| 5 | "Update README Install section per Phase 5 (Ollama-style one-liner, Applications folder)." |
| Final | "Run Final Phase verification from `plans/10-one-line-install.md`." |

---

## Ollama vs Orbit install comparison

| | Ollama | Orbit (this plan) |
|---|--------|-------------------|
| One-liner | `curl -fsSL https://ollama.com/install.sh \| sh` | `curl -fsSL …/orbit/main/scripts/install.sh \| bash` |
| App path | `/Applications/Ollama.app` | `/Applications/Orbit.app` |
| CLI | `/usr/local/bin/ollama` → bundle Resources | `/usr/local/bin/orbit` → bundle Resources |
| User data | `~/.ollama/` | `~/.orbit/` |
| Artifact | Pre-built zip | v1: build on install; v2: release zip |
| Extra deps | None (bundled Go binary) | Homebrew Python 3.13 for v1 source build |

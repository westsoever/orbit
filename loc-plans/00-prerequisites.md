# Plan 00: Local prerequisites

Run this once before any other `loc-plans/` file.

## Requirements

| Item | Check |
|------|-------|
| macOS 14+ (Sonoma or later) | `sw_vers` |
| Apple Silicon or Intel | `uname -m` |
| Xcode Command Line Tools | `xcode-select -p` |
| Homebrew | `brew --version` |
| Homebrew Python 3.13 | `/opt/homebrew/bin/python3.13 --version` or `/usr/local/bin/python3.13 --version` |
| ≥ 10 GB free disk | `df -h ~` |
| Git repo at latest `main` | `git pull origin main` |

## Dev environment (contributors)

```bash
cd ~/path/to/orbit
brew install python@3.13
/opt/homebrew/bin/python3.13 -m venv .venv
source .venv/bin/activate
pip install -e ".[dev]"
```

Confirm SQLite extensions load (required for embeddings and some tests):

```bash
python -c "import sqlite3; sqlite3.connect(':memory:').enable_load_extension(True); print('ok')"
```

If that fails, you are not on Homebrew Python — reinstall the venv with `/opt/homebrew/bin/python3.13`.

## macOS permissions

Grant **Accessibility** to whichever process runs capture:

- **Orbit.app** when using the installed app or dev bundle
- **Terminal** (or your IDE) when running `orbit start` from the CLI

Guide: [`orbit/capture/PERMISSIONS.md`](../orbit/capture/PERMISSIONS.md)

Optional later (not needed for first pass):

- **Screen Recording** — only if testing OCR tiers
- **Notifications** — for daemon start/stop banners (`03-daemon-lifecycle.md`)

## Optional services

| Service | Needed for |
|---------|------------|
| [Ollama](https://ollama.com) | Local AI chat (`05-chat-ai-routes.md`) |
| `services/orbit-relay` on `:8080` | Cloud AI enablement without BYOK (`05-chat-ai-routes.md`) |
| OpenRouter API key in `~/.orbit/.env` | BYOK chat path |

## Pass criteria

- [ ] Venv activates and `orbit doctor` prints Python 3.13 + extension status
- [ ] Accessibility enabled for Orbit or Terminal
- [ ] At least 5 GB free on the volume holding `~/.orbit/` and `.build/`

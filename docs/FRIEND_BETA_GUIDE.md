# Orbit — Friend Beta Guide

Quick reference for testers. Orbit is **macOS 14+ only**.

## What works in this beta

- **Capture** — Orbit reads text from your active windows (Accessibility API). Data stays in `~/.orbit/` on your Mac.
- **History & search** — Browse captured snippets; search by keyword (or semantic search when embeddings are on).
- **Task board** — Click **Scan capture** in the right sidebar to detect tasks from your recent activity.
- **AI chat** — Works after you configure one AI route (see below).
- **Privacy** — Export or delete your data: `orbit privacy export` / `orbit privacy delete`.

## What is not in this beta yet

- Full autonomous agents with tools (MCP) — approved tasks run as a single LLM completion saved to `~/.orbit/output/`.
- Calendar, email, and audio capture.
- Encrypted database (plain SQLite for now).
- Windows / Linux.

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/westsoever/orbit/main/scripts/install.sh | bash
```

The installer prefers a **pre-built release** when one is published on GitHub. If none exists, it builds from source (15–30 minutes, needs Homebrew + Xcode CLT).

### First launch

1. If macOS blocks the app: right-click **Orbit** in Applications → **Open** (once), or run `xattr -cr /Applications/Orbit.app`.
2. Complete the **setup wizard** (Gatekeeper hint → Accessibility).
3. **Sign in** if you already created an account on this Mac, or **Create account**.
4. Grant **Accessibility** to Orbit in System Settings when prompted.
5. Capture starts automatically; confirm the green status dot in the sidebar.

## Configure AI (required for chat)

Open **Settings** (gear in sidebar) → **AI answers**. Pick one:

| Option | What you need |
|--------|----------------|
| **Your API key** | Free/paid key from [openrouter.ai](https://openrouter.ai) — easiest for most testers |
| **Local model (Ollama)** | Install [Ollama](https://ollama.com), run `ollama pull llama3.1`, then save in Settings |
| **Cloud AI** | Requires a hosted Orbit relay (may be pre-configured in release builds) |

## Browser capture (Chrome, Arc, Brave)

1. Settings → **Browser capture** → **Reveal extension folder**
2. Open `chrome://extensions/` → Developer mode → **Load unpacked** → select that folder
3. If captures are empty, visit `chrome://accessibility/` and enable accessibility for tabs

## Tester checklist

| Step | Action | Expected |
|------|--------|----------|
| 1 | `orbit doctor` | Python 3.13 + SQLite extensions OK |
| 2 | Sign in / sign up → capture running | Green “Capturing” status |
| 3 | Switch between Terminal, Safari, Notes | History updates within ~2 s |
| 4 | Sidebar search | Results for visible text |
| 5 | Configure AI → Chat → send message | Assistant reply |
| 6 | Task board → **Scan capture** | Tasks appear after a few minutes of activity |
| 7 | Stop capture | Daemon stops |

## Report problems

Open a [GitHub issue](https://github.com/westsoever/orbit/issues) with:

- macOS version and chip (Intel / Apple Silicon)
- Install path (one-line script vs release zip)
- Relevant lines from `~/.orbit/daemon.log`

## Uninstall

```bash
orbit stop 2>/dev/null || true
rm -rf /Applications/Orbit.app /usr/local/bin/orbit
# Optional — delete all data:
# rm -rf ~/.orbit
```

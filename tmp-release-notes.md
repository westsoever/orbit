## Orbit 0.0.1 — Friend Beta

First pre-built macOS release for external testers.

### Install

```bash
ORBIT_INSTALL_FROM_SOURCE=0 curl -fsSL https://raw.githubusercontent.com/westsoever/orbit/main/scripts/install.sh | bash
```

Or download **Orbit-darwin.zip** or **Orbit.dmg** below and drag **Orbit.app** to Applications.

### Requirements

- macOS 14+ (Sonoma or later)
- Grant **Accessibility** to Orbit on first launch
- For AI chat: configure an OpenRouter API key or Ollama in Settings

### What's included

- Always-on context capture (Accessibility API)
- Orbit Access app: history, search, chat, task board
- **Scan capture** task detection from recent activity
- Bundled browser extension for Chrome/Arc/Brave

### Docs

- [Friend beta guide](https://github.com/westsoever/orbit/blob/cursor/friend-beta-b3e0/docs/FRIEND_BETA_GUIDE.md)

### Notes

- Unsigned/ad-hoc build: if Gatekeeper blocks launch, right-click Orbit → Open once, or run `xattr -cr /Applications/Orbit.app`
- Cloud AI requires a hosted relay (`ORBIT_RELAY_URL`); BYOK or Ollama work without it

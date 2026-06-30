# Local execution plans (`loc-plans/`)

Cloud agents merged code that **cannot be built, run, or verified in the Linux CI environment**. These plans are the local Mac checklist: run them on your machine when you pull `main`.

## Before you start

1. Read [`00-prerequisites.md`](00-prerequisites.md) once.
2. Run [`01-smoke-tests.md`](01-smoke-tests.md) to confirm the dev environment.
3. Work through the feature plans below in any order; each is self-contained.

## Plans

| Plan | What it validates | Related commits / source plans |
|------|-------------------|--------------------------------|
| [00-prerequisites.md](00-prerequisites.md) | macOS, Homebrew Python, Accessibility, disk space | `README.md`, `orbit/capture/PERMISSIONS.md` |
| [01-smoke-tests.md](01-smoke-tests.md) | `verify.sh`, pytest, Swift compile, antipattern grep | All merged work |
| [02-install-and-app-bundle.md](02-install-and-app-bundle.md) | One-line install, `/Applications/Orbit.app`, embedded venv | `aafd682`, `plans/10-one-line-install.md`, `plans/14-chat-enablement.md` Phase 1 |
| [03-daemon-lifecycle.md](03-daemon-lifecycle.md) | Auto-start, stop/restart, system notifications | `dfaa495`, `1e24f82`, `plans/12-daemon-restart-notifications.md` |
| [04-user-signup-and-scoping.md](04-user-signup-and-scoping.md) | Onboarding, user-scoped DB, daemon gating | `5126edf` (#3), `tests/test_user_session.py` |
| [05-chat-ai-routes.md](05-chat-ai-routes.md) | Ollama local mode, Cloud AI relay, BYOK, chat errors | `cdb59cd`, `5d4d06d`, `bd05365`, `plans/11-cloud-ai-relay.md`, `plans/14-chat-enablement.md` |
| [06-orbit-access-ui.md](06-orbit-access-ui.md) | Recent UI: notes sidebar, chat layout, dropdowns, notifications | `aa18df1`, `872b64f`, `7939cd7`, `ef4c912`, `f7c849c`, `plans/06`–`08`, `plans/11-mistral-calm-ui-revamp.md` |
| [07-capture-and-compatibility.md](07-capture-and-compatibility.md) | Real AX capture, probes, browser ext, FSEvents | `plans/03-universal-capture.md`, `docs/capture-compatibility.md` |
| [08-beta-tester-e2e.md](08-beta-tester-e2e.md) | Full README tester checklist on a clean install path | `8bed29a`, `README.md` |

## Suggested order (first session on Mac)

```
00 → 01 → 02 → 03 → 04 → 05 → 08
```

Then `06` (visual pass) and `07` (capture matrix) when you have 30+ minutes of normal app use.

## Reporting failures

For each failed step, note:

- Plan file + step number
- macOS version and chip (Intel / Apple Silicon)
- Installed via dev clone vs `install.sh` vs release zip
- Relevant logs: `~/.orbit/daemon.log`, Console.app filter `Orbit`

Open a [GitHub issue](https://github.com/westsoever/orbit/issues) with that bundle.

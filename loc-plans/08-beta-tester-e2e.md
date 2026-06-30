# Plan 08: Beta tester end-to-end

Runs the public **Tester checklist** from `README.md` on a realistic install path — the acceptance bar for shipping to external testers.

**Commit:** `8bed29a` (documented checklist)  
**Depends on:** Plans 02–05 for full AI coverage

## Choose install path (pick one)

| Path | Command |
|------|---------|
| **A — One-line (recommended)** | `curl -fsSL …/scripts/install.sh \| bash` |
| **B — Release zip** | `ORBIT_VERSION=x.y.z ORBIT_INSTALL_FROM_SOURCE=0 … \| bash` |
| **C — Dev clone** | `pip install -e .` + `ORBIT_FORCE_DEV_BUILD=1 bash scripts/run_orbit_access_app.sh` |

Document which path you used in your test report.

## Checklist (from README)

| Step | Action | Expected | ✓ |
|------|--------|----------|---|
| 1 | `orbit doctor` | Python 3.13 + SQLite extensions OK | |
| 2 | Open Orbit → complete sign-up → capture starts | Green status; “Capturing” pulse | |
| 3 | Switch 2–3 apps (Terminal, Safari, Notes) | History / recent notes within ~2 s | |
| 4 | Sidebar search for visible text | Lexical or hybrid results | |
| 5 | Chat → send message | AI response (Cloud, Ollama, or BYOK — configure one in Plan 05) | |
| 6 | `orbit stop` or sidebar **Stop** | Daemon stops; `curl :8765/health` fails | |

## Extended checks (recommended before beta invite)

| Check | Expected |
|-------|----------|
| Re-open app after stop | Auto-start brings daemon back (`03`) |
| Stop → Start ×3 | No timeout errors |
| Uninstall/reinstall | `~/.orbit/orbit.db` preserved (`02` Part C) |
| Gatekeeper first open | Right-click Open or `xattr -cr` works |
| Low-CPU mode | `orbit start --detach --no-embed` usable all day |

## Low-CPU verification (contributors)

```bash
bash scripts/verify.sh --no-embed
```

**Pass:** green without loading embedding model.

## Sign-off template

Copy into your issue or release notes:

```
Install path: A / B / C
macOS: __version__ (__arch__)
Date: ____

Steps 1–6: PASS / FAIL (notes)
AI route tested: Ollama / BYOK / Cloud relay
Blockers for beta: none / list
```

## Pass criteria

- [ ] All six README steps pass on chosen install path
- [ ] At least one AI route verified (Plan 05)
- [ ] No P0 blockers (daemon won’t start, sign-up broken, data loss on upgrade)

When this plan passes, Orbit meets the documented tester bar on your machine.

# Orbit documentation

| Document | Audience | Description |
|----------|----------|-------------|
| [architecture-context-routing.md](architecture-context-routing.md) | Mentors / stakeholders | Context flow diagram (capture vs check) |
| [diagrams/context-routing.mmd](diagrams/context-routing.mmd) | Diagram tools | Standalone Mermaid source |
| [../README.md](../README.md) | All users | Install, CLI, architecture, troubleshooting |
| [capture-compatibility.md](capture-compatibility.md) | Developers | App-by-app capture tier matrix |
| [gdpr/PRIVACY_POLICY.md](gdpr/PRIVACY_POLICY.md) | End users / B2C | What Orbit captures and stores |
| [gdpr/DPIA_TEMPLATE.md](gdpr/DPIA_TEMPLATE.md) | B2B buyers | Data Protection Impact Assessment template |
| [gdpr/LIA_TEMPLATE.md](gdpr/LIA_TEMPLATE.md) | B2B buyers | Legitimate Interest Assessment template |
| [../orbit/capture/PERMISSIONS.md](../orbit/capture/PERMISSIONS.md) | macOS users | Accessibility, Screen Recording, browser setup |
| [../plans/03-universal-capture.md](../plans/03-universal-capture.md) | Implementers | Universal capture plan (Phases 1–6) |
| [../orbit/browser-extension/README.md](../orbit/browser-extension/README.md) | Browser users | Tier 2 companion extension install |

## Verification scripts

```bash
bash scripts/verify.sh --no-embed
bash scripts/grep_antipatterns.sh
python scripts/probe_app.py --all-visible
python scripts/test_fsevents.py
```

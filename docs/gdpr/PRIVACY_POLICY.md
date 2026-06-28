# Orbit Privacy Policy (Product Draft)

> **Not legal advice.** Have counsel review before publication, especially for B2B employee-monitoring deployments.

## Overview

Orbit is a **local-first** macOS context capture system. By default it stores structured text and metadata on your device only. This policy describes what each capture tier collects, how long data is kept, and your controls.

## Capture tiers

| Tier | Name | Default | Data collected |
|------|------|---------|----------------|
| 0 | Metadata only | Fallback | App name, bundle ID, window title, timestamp |
| 1 | Accessibility text | **On** | Structured text atoms from macOS Accessibility API |
| 2 | Browser companion | Opt-in | URL, page title, selected text via local browser extension |
| 3 | File workspace | Opt-in | File paths, event type, mtime via FSEvents — **not file contents** |
| 4 | OCR | Opt-in | On-device text recognition from focused window; raster discarded |
| 5 | Sampled screenshot | Opt-in | Interval-capped capture; prefer OCR derivative only |

Orbit does **not** log keystrokes globally, continuous webcam, or always-on full-screen video by default.

## Local storage

- Capture data is stored in SQLite at `~/.orbit/orbit.db` (configurable).
- Policy settings live at `~/.orbit/policy.json`.
- Embeddings (when enabled) are stored locally via sqlite-vec.
- No raw capture payload is sent to Orbit cloud services by the capture daemon.

## Retention

- Default retention: **90 days** (`retention_days` in policy).
- Run `orbit privacy purge` or start with `--purge-retention` to enforce.
- You may export or delete all data at any time (see Data subject rights).

## Third-party LLM dispatch (`orbit check`)

The optional `orbit check` command may send **derived task prompts** to a configured LLM provider (e.g. Claude) for task detection. This is separate from the always-on capture store:

- Capture daemon: local-only by default.
- `orbit check`: explicit user invocation; review `--dry-run` before enabling automation.

Document which provider, model, and data fields leave the device in your deployment runbook.

## Exclusions

Apps on the no-capture list (banking, password managers, etc.) are never captured. Users can add bundle IDs via policy.

## Data subject rights

Use the Orbit privacy CLI (GDPR Arts. 15–17):

```bash
orbit privacy export --out ~/orbit-export.jsonl   # Access / portability
orbit privacy delete --yes                        # Erasure
orbit privacy purge --days 90                     # Storage limitation
orbit privacy show-policy                         # Transparency
orbit privacy enable-ocr                          # Granular consent (Tier 4)
orbit privacy enable-fsevents                     # Granular consent (Tier 3)
```

## Contact

Replace with your data controller / DPO contact before shipping.

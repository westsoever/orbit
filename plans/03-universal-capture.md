# Plan 03 — Universal Application Capture (AX + GDPR-Compliant Fallbacks)

**Goal:** Capture useful context from **all application types** on macOS — native, Electron, Chromium browsers, and AX-blind apps — while staying **local-first** and **EU/GDPR-viable** for B2C (user is data subject) and B2B (employer monitoring) deployments.

**Prerequisite plans:** `plans/02-fix-orbit-start.md` (daemon boots), `plans/01-content-collection.md` (SQLite + vec store).

**Non-negotiable constraints (from spec):**
- Default: **text-only, no screenshots** (`orbit-context.md` L22, L152–155; `innitial.md` L207)
- **Local-first** processing and storage (`orbit-context.md` L28; `innitial.md` L154)
- **No-capture zones** by bundle ID from day one (`orbit/capture/exclusions.py`)
- Enhanced modes (OCR, screenshots) are **opt-in tiers**, never default

---

## Phase 0 — Documentation Discovery (Consolidated)

### 0.A Why capture fails today (evidence-cited)

| App class | Example | Symptom | Root cause in Orbit | Source |
|-----------|---------|---------|---------------------|--------|
| Native shallow | Terminal | Works | `AXTextArea` within depth 12 | Session probe + `worker.py:40` |
| Electron deep | Cursor | 0 atoms saved | `max_depth=12` truncates before `AXStaticText` | `ax_walker.py:88`, probe: 0@12 / 192@30 |
| Chromium gated | Dia, Chrome, Arc | Empty `AXWindows` | Renderer AX off until enabled | Chromium a11y docs; Dia err `-25212` |
| Excluded | Dock, 1Password | Never queued | `exclusions.py` | By design |
| Silent drop | All failures above | No DB row | `worker.py:47–53` — no INFO log | Code |

**Pipeline filters (stacked):** exclusion → `get_tree(max_depth=12)` → `CAPTURE_ROLES` → atoms > 0 → SQLite.

### 0.B Allowed APIs — macOS Accessibility (Apple + Chromium)

| API | Signature / usage | Source |
|-----|-------------------|--------|
| `AXUIElementCreateApplication(pid)` | Create app element | `ax_walker.py:97` |
| `AXUIElementCopyAttributeValue(elem, attr, None)` | Read AX attrs | `ax_walker.py:37–44` |
| `AXUIElementSetAttributeValue(elem, attr, value)` | **Set** attrs on target app | [Electron accessibility tutorial](https://electronjs.org/docs/latest/tutorial/accessibility) |
| `AXManualAccessibility` | Electron opt-in full tree | Electron docs; issue #10305 |
| `AXEnhancedUserInterface` | Legacy Chromium flag (VoiceOver) | [Chromium a11y design doc](https://www.chromium.org/developers/design-documents/accessibility/); side-effect risk per Electron #7206 |
| `--force-renderer-accessibility` | Chromium launch flag | Chromium docs; user must relaunch |
| `chrome://accessibility/` | Manual per-profile enable | Chromium; user action |
| `NSWorkspaceDidActivateApplicationNotification` | App-focus trigger | `listener.py:46–50` |

**Anti-patterns:**
- Do **not** assume `AXManualAccessibility` always succeeds — [Electron #37465](https://github.com/electron/electron/issues/37465) reports `kAXErrorAttributeUnsupported` on some builds; fallback chain required.
- Do **not** set `AXEnhancedUserInterface` globally without user awareness — known window-manager side effects (Electron #7206).
- Do **not** invent AX attribute names — verify with `AXUIElementCopyAttributeNames` when debugging.

### 0.C Allowed APIs — Capture code (current repo)

| Symbol | Location | Default |
|--------|----------|---------|
| `get_tree(pid, max_depth=12)` | `orbit/capture/ax_walker.py:88` | depth 12, cap 5000 nodes |
| `CAPTURE_ROLES` | `orbit/capture/extract.py:3` | 5 roles |
| `run_capture_worker(..., max_depth=12)` | `orbit/capture/worker.py:16–21` | not overridable from CLI |
| `EXCLUDED_BUNDLES` | `orbit/capture/exclusions.py` | static set |
| Browser extension | **Not implemented** | Spec only: `orbit-context.md` L25 |

### 0.D GDPR / EU legal frame (for product design — not legal advice)

| Topic | B2C (user owns device) | B2B (employer deploys) | Source |
|-------|------------------------|------------------------|--------|
| Lawful basis | **Art. 6(1)(a) consent** per feature tier; granular opt-in | **Art. 6(1)(f) legitimate interest** + balancing test; **not** employee consent (power imbalance) | [WP29 Opinion 2/2017](https://collab.dpa.gr/wp-content/uploads/2023/07/WP29_Opinion-2-2017-on-data-processing-at-work.pdf) §8–9 |
| DPIA | Recommended for systematic capture | **Mandatory** for systematic employee monitoring (Art. 35) | [EDPB Guidelines](https://www.insightful.io/blog/what-your-dpia-must-include) |
| Proportionality | User chooses tiers; default minimal | Keystroke/full-screen recording **disproportionate**; text AX event-driven OK if documented | WP29 §7; CNIL/Italian Garante practice |
| Transparency | In-app privacy center + per-tier explanation | Written policy **before** monitoring; works council where required (DE/NL/FR) | WP29 §9 |
| Data minimisation | No screenshots default; exclusion list | Same + work-hours scope option | GDPR Art. 5(1)(c) |
| Local-first | Strong differentiator; reduces transfer issues | Still personal data; DPIA required | `innitial.md` L154 |
| EU AI Act | Transparency if AI **profiles** behaviour from capture | Aug 2026 obligations for AI-driven monitoring | Regulation 2024/1689 |

**GDPR-compliant capture tier ranking (low → high intrusion):**

1. **Tier 0 — Metadata only:** app name, bundle ID, window title, timestamp (always-on fallback)
2. **Tier 1 — AX text (default):** structured text atoms via Accessibility API (current Orbit)
3. **Tier 2 — Browser companion:** URL, page title, selected text via signed browser extension (Manifest V3)
4. **Tier 3 — File context:** FSEvents on user-configured workspace paths (paths + mtimes, not contents)
5. **Tier 4 — Opt-in OCR:** Apple Vision on **focused window**, event-triggered, local, deleted after embed
6. **Tier 5 — Opt-in screenshot sample:** ScreenCaptureKit, interval-capped, blur exclusion zones
7. **❌ Out of scope / non-compliant default:** keystroke logging, continuous webcam, always-on full-screen video

### 0.E Confidence + gaps

| Item | Confidence |
|------|------------|
| Cursor depth issue | **High** (reproduced) |
| Dia empty AXWindows | **High** (session probe) |
| AXManualAccessibility on Cursor build | **Medium** (Electron version-dependent) |
| Browser extension Manifest V3 feasibility | **Medium** (needs spike) |
| OCR latency on M-series | **Low** (not benchmarked) |
| Per-country B2B works-council rules | **Low** (legal counsel required) |

---

## Architecture — Tiered Capture Router

```
App focus event (NSWorkspace)
        │
        ▼
┌───────────────────┐
│ CaptureRouter     │  bundle profile lookup
└─────────┬─────────┘
          │
    ┌─────┼─────┬─────────────┬──────────────┐
    ▼     ▼     ▼             ▼              ▼
 Tier0  Tier1  Tier1+       Tier2          Tier4/5
 meta   AX     AX enhanced  browser ext    opt-in OCR/screen
        │      (depth+      (URL/title)    (user consent)
        │       enable)
        └──────────┬──────────────────────────┘
                   ▼
            context_events + text_atoms (+ capture_tier, capture_method)
                   ▼
              embed_queue (if enabled)
```

**New schema fields (Phase 1):** `capture_method` (`ax` | `ax_enhanced` | `metadata_only` | `browser_ext` | `ocr`), `capture_tier` (0–5), `skip_reason` nullable on failed attempts (observability table or log).

---

## Phase 1 — Fix AX Capture for Native + Electron (no new tiers)

**Status:** Implemented 2026-06-28. Cursor: 33 atoms @ depth 24 (was 0 @ 12). `scripts/probe_app.py` added.

**Objective:** Cursor, VS Code, Slack, etc. produce atoms; failures are visible in logs.

### Tasks

1. **Observability — copy pattern from `worker.py:82` success log**
   - After `worker.py:47–53`, add `INFO` when skipping:
     ```python
     logger.info("Skip %s (%s): %s", bundle, app_name, reason)
     ```
   - Reasons: `empty_tree`, `zero_atoms`, `excluded`
   - Include `node_count`, `max_depth`, `pid` in log extra

2. **Adaptive depth — copy from session probe thresholds**
   - Add `CAPTURE_PROFILES: dict[str, int]` in new `orbit/capture/profiles.py`:
     ```python
     DEFAULT_DEPTH = 12
     ELECTRON_DEPTH = 24  # verified: Cursor 20 atoms @24, 192 @30
     ELECTRON_BUNDLE_PREFIXES = ("com.todesktop.", "com.microsoft.VSCode", "com.hnc.Discord", "com.slack.")
     ```
   - In `worker.py`, resolve depth before `get_tree()`:
     ```python
     depth = profile_depth_for(bundle)
     tree = get_tree(pid, max_depth=depth)
     ```
   - Reference: probe table in Phase 0.A

3. **Chromium/Electron enablement — copy from [Electron docs](https://electronjs.org/docs/latest/tutorial/accessibility)**
   - New `orbit/capture/ax_enable.py`:
     ```python
     def enable_renderer_accessibility(pid: int) -> bool:
         app = AXUIElementCreateApplication(pid)
         err = AXUIElementSetAttributeValue(app, "AXManualAccessibility", True)
         if err == kAXErrorSuccess:
             return True
         err = AXUIElementSetAttributeValue(app, "AXEnhancedUserInterface", True)
         return err == kAXErrorSuccess
     ```
   - Call from `get_tree()` **once per pid** (module-level cache `set[int]`)
   - After enable: `time.sleep(0.3)` + pump run loop once (`AppHelper.runConsoleEventLoop` too heavy — use `CFRunLoopRunInMode` for 0.3s)
   - Log enable success/failure at DEBUG

4. **CLI `--max-depth` override**
   - `daemon.py` + `cli.py start`: `--max-depth N` passed to worker
   - Reference: `plans/02-fix-orbit-start.md` daemon wiring

5. **Metadata-only fallback (Tier 0)**
   - When `tree` empty or `atoms` empty after AX path: still write `context_events` row with window title from `AXTitle` / `NSRunningApplication` if obtainable; `capture_method=metadata_only`
   - New writer helper in `orbit/storage/writer.py` — partial event insert

### Verification checklist

```bash
# 1. Focus Cursor → log shows atoms > 0 OR explicit skip reason
orbit start
# switch Cursor ↔ Terminal; expect "Captured event N for com.todesktop..." 

# 2. Depth override
orbit start --max-depth 30

# 3. DB check
sqlite3 ~/.orbit/orbit.db "SELECT app_bundle_id, capture_method, length(visible_text) FROM context_events ORDER BY id DESC LIMIT 10;"

# 4. Unit-style probe script (add scripts/probe_app.py)
.venv/bin/python scripts/probe_app.py --bundle com.todesktop.230313mzl4w4u92
# expect: nodes>0, atoms>0
```

### Anti-pattern guards

- Do not raise `_MAX_NODES` above 10000 without benchmarking CPU on focus storm.
- Do not call `enable_renderer_accessibility` on every focus — cache by PID.
- Do not drop Tier 0 metadata when AX text fails — user asked for "all apps".

---

## Phase 2 — Chromium Browser Capture (Tier 1+ / Tier 2)

**Status:** Implemented 2026-06-28. Browser bridge on :8765, MV3 extension in `orbit/browser-extension/`.

**Objective:** Dia, Chrome, Arc, Safari produce useful context.

### 2A — AX path for Chromium (same machine)

1. **Detect Chromium bundles** — prefix list in `profiles.py`:
   - `com.google.Chrome`, `company.thebrowser.dia`, `company.thebrowser.Browser`, `com.brave.Browser`, `com.apple.Safari`
2. **Pre-enable + deeper depth** — depth 20, enablement + 500ms settle
3. **User onboarding card** when browser returns empty tree:
   - Option A: "Relaunch browser with accessibility" → show copy-paste flag instructions
   - Option B: "Install Orbit browser companion" → Phase 2B

**Chromium user instructions (document in `PERMISSIONS.md`):**
```bash
# Chrome/Arc — visit while browser running:
chrome://accessibility/  → enable for active tabs

# Or relaunch once:
open -a "Google Chrome" --args --force-renderer-accessibility
```

### 2B — Browser extension (Tier 2, spec-aligned)

**What to implement:** MV3 extension per `orbit-context.md` L25.

| Component | Responsibility |
|-----------|----------------|
| `orbit/browser-extension/` | MV3: content script extracts `document.title`, `location.href`, selection text |
| Native messaging host | `orbit/browser-bridge/` — local Unix socket or HTTP on `127.0.0.1` |
| Daemon ingest | New `BrowserEventListener` merges extension events into same SQLite schema |

**Captured fields (GDPR-minimal):**
- URL, title, timestamp, selected text (if user highlights), active tab ID
- **Not** full DOM, not cookies, not form values unless focused field AX available

**Lawful basis:**
- B2C: extension install = explicit consent for browser tier
- B2B: disclose in monitoring policy; URL capture still personal data if logged

**Copy-ready:** Study [screenpipe browser approach](https://github.com/screenpipe/screenpipe) for local bridge pattern (architecture only — Orbit stays text-first).

### Verification checklist

```bash
# AX path
scripts/probe_app.py --bundle company.thebrowser.dia  # after chrome://accessibility enable

# Extension path
# Load unpacked extension → visit page → check:
sqlite3 ~/.orbit/orbit.db "SELECT * FROM context_events WHERE capture_method='browser_ext' LIMIT 5;"
```

### Anti-pattern guards

- Do not exfiltrate browser data to cloud from extension.
- Do not request `<all_urls>` without narrow optional_host_permissions pattern.
- Do not store full page HTML.

---

## Phase 3 — Opt-In Enhanced Capture (Tier 4–5, GDPR-controlled)

**Status:** Implemented 2026-06-28. Tier 4 OCR via Vision; policy at `~/.orbit/policy.json`; `orbit privacy` CLI.

**Objective:** AX-blind apps (custom native, some games, remote desktop viewers) have a **consent-gated** fallback.

### Tier 4 — Event-triggered OCR (local)

**Trigger:** App focus where Tier 0–2 all failed AND user enabled "Enhanced context (OCR)" in settings.

**Implementation sketch:**
- `ScreenCaptureKit` or `CGWindowListCreateImage` on **frontmost window rect only** (not full display)
- Apple Vision `VNRecognizeTextRequest` — on-device, no network
- Store: OCR text atoms only; **delete raster immediately** after extraction (or never write image to disk)
- Tag: `capture_method=ocr`, `capture_tier=4`

**GDPR controls (product requirements):**
- Off by default
- Per-app allow/deny list (extends `exclusions.py` pattern)
- Retention TTL on OCR-derived atoms (e.g. 30 days, configurable)
- Export + delete all capture data (Art. 15/17)

### Tier 5 — Sampled screenshot (last resort)

- Interval floor: ≥60s, only when focused app on user allowlist
- Blur regions matching banking/password bundle IDs
- Store thumbnail encrypted or not at all — prefer OCR-only derivative

**Spec alignment:** `orbit-context.md` L155 "enhanced mode"; `innitial.md` L207 tiered launch.

### Anti-pattern guards

- Never enable Tier 4/5 in B2B deployment without DPIA sign-off workflow in admin UI.
- No keystroke hooks (WP29 explicitly disproportionate).

---

## Phase 4 — Complementary Local Sources (non-AX)

**Status:** Phase 4A implemented 2026-06-28. FSEvents opt-in (`tier_fsevents`); `fs_events` table; `orbit privacy enable-fsevents`.

**Objective:** Richer context without screen pixels.

| Source | API | GDPR notes | Phase |
|--------|-----|------------|-------|
| File workspace | FSEvents | Paths only; user picks folders | 4A |
| Audio/meetings | Local Whisper | Explicit mic consent; no ambient default | 4B (future) |
| Calendar | EventKit local | OAuth/user auth | 4C (future) |
| Email | Local IMAP | User credentials | 4C (future) |

**Phase 4A — FSEvents (copy from spec `orbit-context.md` L24):**
- Watch `~/Projects`, user-configured roots
- Atom: `{path, event_type, mtime}` linked to nearest focus event within ±30s

---

## Phase 5 — EU / GDPR Product Layer

**Status:** Phase 5A/5C/5D implemented 2026-06-28. Policy model, privacy CLI, GDPR templates in `docs/gdpr/`, `capture_audit` table.

**Objective:** Ship capture tiers with compliance artifacts for B2C and B2B.

### 5A — Privacy settings model

```python
@dataclass
class CapturePolicy:
    tier_ax_text: bool = True          # Tier 1 default ON
    tier_browser_ext: bool = False     # Tier 2 opt-in
    tier_ocr: bool = False             # Tier 4 opt-in
    tier_screenshot: bool = False      # Tier 5 opt-in
    excluded_bundles: set[str]         # merges exclusions.py + user adds
    retention_days: int = 90
    work_hours_only: bool = False      # B2B option
```

Persist to `~/.orbit/policy.json` (encrypted later via SQLCipher per spec).

### 5B — B2C vs B2B deployment modes

| Mode | Install | Consent UX | Lawful basis documentation |
|------|---------|------------|----------------------------|
| **B2C** | User installs Orbit | Setup wizard: tier toggles + privacy policy | Consent records per tier |
| **B2B** | MDM / employer | Employer policy URL + employee notice | Legitimate interest assessment template + DPIA PDF export |

### 5C — Required artifacts (not code — deliverables)

1. **Privacy Policy** — lists tiers, retention, local storage, third-party LLM dispatch (orbit check)
2. **DPIA template** for B2B buyers (Art. 35)
3. **Legitimate Interest Assessment** template (3-part test per WP29)
4. **Data Subject Rights** — CLI or UI: `orbit privacy export`, `orbit privacy delete`

### 5D — Technical measures map

| GDPR principle | Orbit implementation |
|----------------|---------------------|
| Data minimisation | Tier 0–1 default; role filter; exclusion list |
| Purpose limitation | Capture store separate from task dispatch logs |
| Storage limitation | `retention_days` sweeper job |
| Integrity/confidentiality | SQLCipher (future); keychain key |
| Accountability | `capture_audit` table: method, tier, atom count, timestamp |

**Legal review gate:** Before B2B GA in DE/FR/IT/NL, counsel review of national employee-monitoring law.

---

## Phase 6 — Verification & Compatibility Matrix

**Status:** Implemented 2026-06-28. `docs/capture-compatibility.md`; `scripts/verify.sh` runs antipatterns + compileall + schema smoke.

### Automated

```bash
scripts/probe_app.py --all-visible     # every regular app → report tier used
scripts/verify.sh                      # existing + probe gate
bash scripts/grep_antipatterns.sh      # no cloud exfil, no keystroke hooks
```

### Manual compatibility matrix (maintain `docs/capture-compatibility.md`)

| App | Bundle | Tier expected | Atoms | Notes |
|-----|--------|---------------|-------|-------|
| Terminal | com.apple.Terminal | 1 | ✓ | baseline |
| Cursor | com.todesktop.* | 1+ | ✓ after Phase 1 | depth 24 |
| Dia | company.thebrowser.dia | 2 | ✓ after extension | AX empty default |
| Chrome | com.google.Chrome | 1+ or 2 | TBD | chrome://accessibility |
| 1Password | com.1password.* | excluded | — | privacy |

### Success criteria

- **≥90%** of user's daily apps (by focus time) produce at least Tier 0 metadata
- **≥70%** produce Tier 1+ text atoms without enhanced modes
- Zero silent skips without INFO log
- B2C: user can disable any tier and delete all data in one command

---

## Implementation Order (recommended)

| Sprint | Phases | Outcome |
|--------|--------|---------|
| 1 | Phase 1 | Cursor/Electron work; metadata fallback; skip logging |
| 2 | Phase 2A + docs | Chromium AX enable + user instructions |
| 3 | Phase 2B | Browser extension + local bridge |
| 4 | Phase 5A + 5C | Policy model + privacy CLI + templates |
| 5 | Phase 4A | FSEvents workspace linking |
| 6 | Phase 3 | OCR opt-in (only if AX+extension insufficient) |

---

## Session handoff

- **Immediate win:** Phase 1 alone fixes Cursor (confirmed depth issue).
- **Browser gap:** Dia/Chrome need enablement **or** extension — AX alone insufficient today.
- **GDPR strategy:** Stay Tier 0–1 default; extension and OCR are opt-in; B2B needs DPIA bundle, not just code.
- **Do not skip Phase 1 observability** — silent drops caused this debugging session.

## References

- Orbit spec: `orbit-context.md`, `innitial.md` §competitive / tiered capture
- Prior fix plan: `plans/02-fix-orbit-start.md`
- Electron AX: https://electronjs.org/docs/latest/tutorial/accessibility
- Chromium AX: https://www.chromium.org/developers/design-documents/accessibility/
- WP29 employment: https://collab.dpa.gr/wp-content/uploads/2023/07/WP29_Opinion-2-2017-on-data-processing-at-work.pdf
- Subagent capture audit: [explore agent 5e34e23c](5e34e23c-3cea-4591-9fe8-17e03d1995e0)

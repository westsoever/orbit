# Plan: Make the Chat Window Work (packaging, local LLM, Cloud AI)

> The Orbit Access chat window cannot produce AI answers today. "Enable Cloud AI" fails, and there is no local-LLM path. This plan makes all three routes to a working chat reachable: (1) the bundled daemon actually starts, (2) a real **local LLM** option (Ollama) exists, and (3) **Enable Cloud AI** succeeds against a reachable relay. BYOK already works once a key is present.

**Scope:** Python LLM routing (`orbit/check/llm.py`), app packaging/build (`scripts/build-app-bundle.sh`, `pyproject.toml`), the relay run/deploy surface (`services/orbit-relay/`), and minimal Orbit Access UX (`OrbitAccessApp/`). The bridge `/api/chat` contract is unchanged.

**Root-cause summary (verified on-device 2026-06-29):**
- **Enable Cloud AI fails** — the relay (`services/orbit-relay`) is not running; the app POSTs `register` to `http://127.0.0.1:8080` (default in `CloudAIService.defaultRelayURL`) → connection refused. No hosted `ORBIT_RELAY_URL` is configured.
- **No local AI** — `orbit/check/llm.py` only routes to OpenRouter (BYOK) or the relay. Ollama is a **comment only** (`llm.py:8`); there is no local-model code path.
- **Installed app daemon is broken** — `/Applications/Orbit.app`'s embedded venv is missing `orbit/storage/schema.sql` (daemon log: `FileNotFoundError …/orbit/storage/schema.sql`). `package-data` for `schema.sql` was only added in commit `aafd6827`; the installed build predates it. The build's post-step (`orbit doctor`) does not detect this.
- **Live confirmation** — `POST /api/chat` → `503 {"error":"No AI credentials configured…"}`; daemon bridge up on `:8765`; relay `:8080` not listening; no `~/.orbit/cloud.json`, no `~/.orbit/.env`.

**Out of scope (defer):**
- Real token streaming from the model through the bridge (keep today's single `delta` SSE in `_stream_chat_sse`).
- Local model for task `dispatch()` / `detector` (chat only here).
- Relay production hosting/IaC (Dockerfile/fly.toml) beyond a documented run recipe.
- Account/login, billing.

**References (read before editing):**
- `orbit/check/llm.py:1-125` — `complete()` resolution order, `_complete_openrouter`, `complete_via_relay`, `format_completion_error`.
- `orbit/check/cloud_config.py:8-34` — `~/.orbit/cloud.json` parsing.
- `orbit/browser_bridge/server.py:249-281` — `/api/chat` → `search_bridge` → `complete()` → SSE.
- `orbit/storage/db.py:21,90-91` — `_SCHEMA = Path(__file__).parent / "schema.sql"`.
- `pyproject.toml:17-22` — `[tool.setuptools.package-data] orbit = ["storage/schema.sql"]`.
- `scripts/build-app-bundle.sh:100-117,154-155` — venv `pip install .`, CLI wrapper, `orbit doctor` smoke.
- `services/orbit-relay/README.md:46-53,102-105` — local run + tests.
- `services/orbit-relay/orbit_relay/config.py:10-28` — env vars.
- `services/orbit-relay/orbit_relay/main.py:31-48,84-91,126-143,200-203` — models, endpoints, port.
- `OrbitAccessApp/Services/CloudAIService.swift:51-113` — `defaultRelayURL`, `register()`, `hasBYOK()`.
- `OrbitAccessApp/Services/DaemonManager.swift:40-59,141-161` — binary resolution, `orbit start --detach`.
- `OrbitAccessApp/Stores/ChatStore.swift:33-96` — AI vs offline routing.
- `OrbitAccessApp/App/AppViewModel.swift:21-29` — capability flags.

---

## Phase 0: Documentation Discovery (COMPLETE)

### Sources consulted

| Source | What it established |
|--------|---------------------|
| `orbit/check/llm.py` | `complete()` tries BYOK env/`.env` → `cloud.json` relay → raise. Model `owl-alpha`, base `https://openrouter.ai/api/v1`. No local branch. |
| `orbit/storage/db.py` | Schema resolved as `__file__`-relative `schema.sql`; `open_db_plain` calls `_apply_schema(skip_vec=True)`. |
| `pyproject.toml` | setuptools; `package-data` ships `storage/schema.sql` (added `aafd6827`). No `MANIFEST.in`/`setup.py`. |
| `scripts/build-app-bundle.sh` | Sole bundler: `python3.13 -m venv` + `pip install "$SOURCE_ROOT"` (non-editable) into `orbit-venv`; `orbit-core` gets **docs only**; smoke = `orbit doctor` (does NOT verify schema). |
| `services/orbit-relay/*` | FastAPI; `orbit-relay` runs uvicorn on hardcoded **:8080**. Requires `OPENROUTER_API_KEY` + `ORBIT_RELAY_SECRET`. Register → 201 `{device_token,expires_at}`; chat → 200 `{content}`. Auth `Authorization: Bearer <token>`. Tests patch `orbit_relay.main.complete_chat`. |
| `CloudAIService.swift` | `defaultRelayURL` = `ORBIT_RELAY_URL` env or `http://127.0.0.1:8080`. `register()` POSTs `{install_id, app_version}`, expects 201, persists `cloud.json` + Keychain. `hasBYOK()` reads `~/.orbit/.env`. |

### Allowed APIs (use exactly these; do not invent)

- **Daemon LLM:** add a local branch inside `orbit/check/llm.py` using the existing `openai` client with `base_url`/`api_key` overrides (same `client.chat.completions.create(...)` shape already in `_complete_openrouter`). Reuse `_MODEL` override via env. Do **not** add new SDKs.
- **Local config:** read env vars (`ORBIT_LLM_PROVIDER`, `ORBIT_LOCAL_LLM_BASE_URL`, `ORBIT_LOCAL_LLM_MODEL`) and/or `~/.orbit/.env` lines via the existing `_try_load_api_key()`-style parser. Do **not** add a YAML/TOML config loader.
- **Relay:** run via existing entry point `orbit-relay` (`orbit_relay.main:run`) or `uvicorn orbit_relay.main:app --port 8080`. Env via `.env` (`pydantic-settings`). Do **not** change the request/response models or port wiring beyond what's listed.
- **Build:** keep `pip install "$SOURCE_ROOT"` (non-editable). Do **not** switch to `pip install -e`, PyInstaller, or copying source trees.
- **Swift relay URL:** keep env-driven `defaultRelayURL`; inject via the CLI wrapper / `LSEnvironment`, not a hardcoded production URL in source.

### Anti-patterns to avoid (these do NOT exist / are wrong here)

- ❌ Calling OpenRouter or any LLM directly from Swift (relay/daemon only).
- ❌ Assuming `orbit-core/` contains the Python package — it holds **docs only**; the package lives in `orbit-venv/.../site-packages/orbit/`.
- ❌ Adding `model="ollama"` style guesses — Ollama's OpenAI-compatible endpoint is `http://localhost:11434/v1`, `api_key="ollama"`, model is a real tag (e.g. `llama3.1`).
- ❌ Relying on `ORBIT_ROOT` to fix the schema path — schema is `__file__`-relative inside the installed package, unaffected by `ORBIT_ROOT`.
- ❌ Editing `OrbitAccessApp/Views/ui/**` shadcn-style primitives (N/A here; this is SwiftUI) — do not restyle unrelated chat components.

---

## Phase 1: Make the bundled daemon start (packaging fix + build guard)

**Why first:** in the installed app, nothing works until the daemon starts. The crash is a missing data file in the embedded venv.

### What to implement

1. **Confirm `package-data` is present** (it is, on current `main`):
   - Verify `pyproject.toml:17-22` contains:
     ```toml
     [tool.setuptools.package-data]
     orbit = ["storage/schema.sql"]
     ```
   - If any other non-`.py` data files are loaded `__file__`-relative at runtime, add them here too. Grep first: `rg -n "Path\\(__file__\\).*\\.(sql|json|txt|md)" orbit/`.
2. **Add a hard build-time guard** in `scripts/build-app-bundle.sh`, immediately after the `pip install "$SOURCE_ROOT"` block (around line 105) and before/with the `orbit doctor` smoke (lines 154-155). Copy the existing `status "…"` style. The guard must fail the build if the schema is not in the venv:
   ```bash
   status "Verifying embedded package data…"
   SCHEMA="$VENV/lib/python3.13/site-packages/orbit/storage/schema.sql"
   if [[ ! -f "$SCHEMA" ]]; then
     echo "ERROR: schema.sql missing from embedded venv ($SCHEMA)." >&2
     echo "Ensure pyproject.toml [tool.setuptools.package-data] ships storage/schema.sql." >&2
     exit 1
   fi
   ```
3. **Strengthen the smoke test** so it exercises DB open (not just `doctor`). After the guard, add:
   ```bash
   status "Smoke-testing DB open…"
   "$RESOURCES/orbit-venv/bin/python3.13" -c "import tempfile, os; from orbit.storage.db import open_db_plain; p=os.path.join(tempfile.mkdtemp(),'t.db'); open_db_plain(p); print('db ok')"
   ```
   (Verify the real `open_db_plain` signature in `orbit/storage/db.py` before wiring; it returns `(con, lock)` — discard is fine.)

### Documentation references
- `scripts/build-app-bundle.sh:100-117` (install + wrapper), `:154-155` (doctor smoke).
- `orbit/storage/db.py:21,84-110` (`_SCHEMA`, `open_db_plain`, `_apply_schema`).
- `pyproject.toml:17-22`.

### Verification checklist
- [ ] `rg -n "package-data" -A2 pyproject.toml` shows `storage/schema.sql`.
- [ ] Build a fresh bundle to a temp path: `bash scripts/build-app-bundle.sh --output /tmp/Orbit.app` completes with exit 0 and prints `db ok`.
- [ ] `ls /tmp/Orbit.app/Contents/Resources/orbit-venv/lib/python3.13/site-packages/orbit/storage/schema.sql` exists.
- [ ] `/tmp/Orbit.app/Contents/Resources/orbit start --no-embed --no-statusbar` then `curl -s 127.0.0.1:8765/api/status` → `{"ok": true,…}`; `orbit stop`.
- [ ] Reinstall over the broken app: `bash scripts/install.sh` (or move `/tmp/Orbit.app` to `/Applications`), confirm in-app "Start" brings the daemon online.

### Anti-pattern guards
- Do NOT "fix" by copying `schema.sql` into `orbit-core/` — runtime never reads it from there.
- Do NOT switch the install to `-e`; that would re-break released zips (path points back at a source tree that isn't shipped).
- Do NOT remove the existing `orbit doctor` step; add alongside it.

---

## Phase 2: Real local LLM path (Ollama) — make "local usage" work

**Goal:** a user with [Ollama](https://ollama.com) running gets AI chat answers with **no cloud, no key**. This is the "local usage" the chat window implies.

### What to implement (all in `orbit/check/llm.py`)

1. **Add a provider resolver** near the top (after `_BASE_URL`, line 19). Copy the env-reading style of `_try_load_api_key()` (`llm.py:22-32`) — read env first, then `~/.orbit/.env` lines:
   - `ORBIT_LLM_PROVIDER` ∈ {`auto`, `local`, `cloud`, `byok`} (default `auto`).
   - `ORBIT_LOCAL_LLM_BASE_URL` (default `http://localhost:11434/v1`).
   - `ORBIT_LOCAL_LLM_MODEL` (default `llama3.1`).
2. **Add `_complete_local(system, user, base_url, model)`** that mirrors `_complete_openrouter` exactly (`llm.py:43-56`) but with `api_key="ollama"` and the local `base_url`/`model`. Reuse the `import openai` client and `client.chat.completions.create(...)` shape. Do **not** introduce a new dependency — Ollama is OpenAI-compatible.
3. **Add `_local_available(base_url) -> bool`** — a fast `httpx.get(base_url.replace('/v1','') + '/api/tags', timeout=1.5)` health check so `auto` mode only picks local when a server is actually up. Reuse `import httpx` (already used by `complete_via_relay`).
4. **Rewrite `complete()`** (`llm.py:108-113`) to honor the provider:
   ```python
   def complete(system: str, user: str) -> str:
       provider = _resolve_provider()  # reads ORBIT_LLM_PROVIDER
       if provider == "local" or (provider == "auto" and _local_available(_local_base_url())):
           return _complete_local(system, user, _local_base_url(), _local_model())
       if key := _try_load_api_key():
           return _complete_openrouter(system, user, key)
       if cfg := load_cloud_config():
           return complete_via_relay(system, user, cfg)
       raise RuntimeError(_missing_key_message())
   ```
   Keep BYOK precedence for `auto`/`byok` as today; `local` forces local; `cloud` skips local.
5. **Extend `_missing_key_message()`** (`llm.py:35-40`) to also mention starting Ollama (`ORBIT_LLM_PROVIDER=local`, `ollama serve`, `ollama pull llama3.1`).
6. **Surface local mode in the app (minimal):** in `CloudAISettingsView.swift` add an informational line "Using local model (Ollama)" when applicable. Detection: add an app-side helper analogous to `hasBYOK()` that checks `~/.orbit/.env` for `ORBIT_LLM_PROVIDER=local`, and treat it like BYOK in `AppViewModel.canUseAIChat` (`AppViewModel.swift:27-29`) so the chat routes to the bridge instead of offline. Do NOT have Swift talk to Ollama directly.

### Documentation references
- `orbit/check/llm.py:22-56,108-124` — patterns to copy (`_try_load_api_key`, `_complete_openrouter`, `complete()`).
- [Ollama OpenAI compatibility](https://github.com/ollama/ollama/blob/main/docs/openai.md) — `/v1`, `api_key="ollama"`, real model tags; `/api/tags` for health.
- `OrbitAccessApp/Services/CloudAIService.swift:75-83` (`hasBYOK()` pattern), `AppViewModel.swift:26-29` (gating).
- `tests/test_cloud_llm.py` — extend with local-provider routing tests.

### Verification checklist
- [ ] Unit: with `ORBIT_LLM_PROVIDER=local` and a mocked `openai` client, `complete()` calls `_complete_local` with `base_url=http://localhost:11434/v1`, `api_key="ollama"` (add to `tests/test_cloud_llm.py`, mirror existing monkeypatch style).
- [ ] Unit: `auto` with `_local_available` returning False and a BYOK key set → still uses OpenRouter (no regression).
- [ ] Manual (if Ollama installed): `ollama serve` + `ollama pull llama3.1`, set `ORBIT_LLM_PROVIDER=local` in `~/.orbit/.env`, then `curl -s -X POST 127.0.0.1:8765/api/chat -d '{"query":"what did I do in Terminal"}'` returns a `delta` with model text (not a 503).
- [ ] `rg -n "11434" orbit/` shows only `llm.py` (no Swift networking to Ollama).
- [ ] `bash scripts/verify.sh --no-embed` passes.

### Anti-pattern guards
- Do NOT hardcode a model that may not be pulled; default `llama3.1` but allow override and fail with a clear message if the model 404s.
- Do NOT block startup on the `/api/tags` probe — 1.5s timeout, swallow errors → treat as unavailable.
- Do NOT add `ollama`/`langchain` packages; use the existing `openai` + `httpx`.

---

## Phase 3: Make "Enable Cloud AI" succeed (relay reachable + UX correctness)

**Goal:** the "Enable Cloud AI" button registers a device and chat answers come back through the relay.

### What to implement

1. **Document + script a runnable relay** (no code change to models). Add `services/orbit-relay/run-local.sh` (copy commands from `README.md:46-53`):
   ```bash
   #!/usr/bin/env bash
   set -euo pipefail
   cd "$(dirname "$0")"
   [[ -d .venv ]] || python -m venv .venv
   source .venv/bin/activate
   pip install -q -e ".[dev]"
   [[ -f .env ]] || cp .env.example .env
   echo "Edit .env (OPENROUTER_API_KEY, ORBIT_RELAY_SECRET) then re-run." 
   grep -q '^OPENROUTER_API_KEY=.\+' .env && grep -q '^ORBIT_RELAY_SECRET=.\+' .env || exit 1
   exec orbit-relay   # uvicorn on :8080
   ```
2. **Document `OPENROUTER_BASE_URL`** in `.env.example` and `README.md` (it exists in `config.py:26` but is undocumented).
3. **Fix the kill-switch error envelope mismatch** in `orbit/check/llm.py:90-96`: FastAPI returns `{"detail": {"error": "relay_disabled"}}`, but `format_completion_error` reads top-level `detail.get("error")`. Update it to also check `exc.response.json().get("detail", {}).get("error")`. Add a unit test in `tests/test_cloud_llm.py`.
4. **Relay URL injection for the shipped app** (so production isn't localhost): in `scripts/build-app-bundle.sh` CLI/launch path, support an `ORBIT_RELAY_URL` build arg that is written into the app's launch environment. Lowest-risk option: add `LSEnvironment` to the bundle `Info.plist` when `ORBIT_RELAY_URL` is set at build time (the Swift app already reads `ProcessInfo…["ORBIT_RELAY_URL"]`). Keep `127.0.0.1:8080` as the dev default in `CloudAIService.swift` (unchanged).
5. **Optional invite support** (only if the relay will set `INVITE_CODE`): `CloudAIService.register()` does not send `X-Orbit-Invite`. If invites are used, add the header from a build/env value. Otherwise leave `INVITE_CODE` unset on the relay. Flag this; default = no invite.
6. **Improve register error UX** in `CloudAIEnableCard.swift`/`CloudAISettingsView.swift`: map connection-refused to a clear "Cloud AI service is unreachable. Is the relay running / ORBIT_RELAY_URL set?" message instead of the raw `NSURLError` string. Keep using `CloudAIService.register()`.

### Documentation references
- `services/orbit-relay/README.md:46-53,102-113`, `.env.example:1-15`, `config.py:10-28`, `main.py:84-143,200-203`.
- `orbit/check/llm.py:59-72,90-106` (relay call + error mapping).
- `OrbitAccessApp/Services/CloudAIService.swift:51-113`.
- Daemon↔relay shape match already verified: `{system,user,model}` ↔ `ChatRequest`; response `{content}`.

### Verification checklist
- [ ] `bash services/orbit-relay/run-local.sh` (after filling `.env`) → `curl -s 127.0.0.1:8080/health` = `{"ok":true}`.
- [ ] `cd services/orbit-relay && pytest` is green.
- [ ] With relay up, in the app click **Enable Cloud AI** → no error; `~/.orbit/cloud.json` is written with `relay_base_url`/`device_token`.
- [ ] `curl -s -X POST 127.0.0.1:8765/api/chat -d '{"query":"hello"}'` returns a `delta` (relay → OpenRouter), not 503.
- [ ] Kill switch: set `RELAY_DISABLED=1`, restart relay, send chat → app shows "Cloud AI temporarily unavailable" (proves Phase 3.3 fix).
- [ ] `unzip -l` of a build made with `ORBIT_RELAY_URL=https://…` shows `LSEnvironment` in `Info.plist` (if 3.4 implemented).

### Anti-pattern guards
- Do NOT commit any real `OPENROUTER_API_KEY` / `ORBIT_RELAY_SECRET` (`.env` is git-ignored; `.env.example` stays blank).
- Do NOT change relay port wiring or request models.
- Do NOT bake a production relay URL into source — inject via env/Info.plist.

---

## Phase 4: Chat UX correctness (routing + messaging)

**Goal:** the window behaves correctly in every state (daemon off, DB-only/offline, local, cloud, BYOK) with accurate copy.

### What to implement
1. **Fix the misleading no-DB error** in `ChatStore.send` (`ChatStore.swift:42-44`): when neither AI nor local search is available, message should reflect the real cause (e.g. "Start Orbit to enable chat — no daemon and no local database yet.") rather than implying only the daemon matters.
2. **Reflect local mode in capability flags**: ensure `AppViewModel.canUseAIChat` (`AppViewModel.swift:27-29`) is true when local LLM is configured (Phase 2.6), so input routes to the bridge.
3. **Placeholder/badge copy** in `ChatInputBar.swift:91-102` and `MainChatView.swift:77-82`: add a "Local model" state distinct from "Offline mode — keyword search".
4. **No behavior change to SSE** — keep `_stream_chat_sse` single-`delta` shape (`server.py:283-297`).

### Documentation references
- `OrbitAccessApp/Stores/ChatStore.swift:33-96`, `OrbitAccessApp/App/AppViewModel.swift:18-29`, `OrbitAccessApp/Views/Chat/ChatInputBar.swift:87-123`, `OrbitAccessApp/Views/Chat/MainChatView.swift:38-82`.

### Verification checklist
- [ ] Daemon off + no DB → input disabled or shows the corrected message; no crash.
- [ ] Daemon off + DB present → offline keyword search returns snippets (already works; confirm copy says "Offline mode").
- [ ] Local LLM configured → placeholder shows "Ask Orbit anything…" and answers stream via bridge.
- [ ] Cloud enabled → same; offline badge hidden.

### Anti-pattern guards
- Do NOT remove the offline keyword-search path; it is the graceful fallback when no LLM is reachable.
- Do NOT restyle unrelated chat components; copy/flag changes only.

---

## Phase 5: Final Verification

1. **Docs match code**
   - [ ] `rg -n "11434|ORBIT_LLM_PROVIDER" orbit/ docs/ README.md` — local mode documented in `README.md` and `orbit-context.md`/`docs/` where AI setup is described.
   - [ ] `services/orbit-relay/README.md` documents `OPENROUTER_BASE_URL` and `run-local.sh`.
2. **Anti-pattern grep**
   - [ ] `bash scripts/grep_antipatterns.sh` clean.
   - [ ] `rg -n "openrouter\\.ai|11434" OrbitAccessApp/` returns nothing (Swift never calls LLMs directly).
   - [ ] `rg -n "pip install -e" scripts/build-app-bundle.sh` returns nothing (still non-editable).
3. **Tests**
   - [ ] `bash scripts/verify.sh --no-embed` passes.
   - [ ] `cd services/orbit-relay && pytest` passes.
   - [ ] `pytest tests/test_cloud_llm.py` passes (incl. new local-provider + kill-switch tests).
4. **End-to-end smoke (each route gives a real answer or correct fallback)**
   - [ ] **Packaging:** fresh `/tmp/Orbit.app` daemon starts; `schema.sql` present.
   - [ ] **Local:** `ORBIT_LLM_PROVIDER=local` + Ollama → `/api/chat` answers.
   - [ ] **BYOK:** `OPENROUTER_API_KEY` in `~/.orbit/.env` → `/api/chat` answers.
   - [ ] **Cloud:** relay up + Enable Cloud AI → `/api/chat` answers; kill switch shows friendly message.
   - [ ] **Offline:** no LLM, DB present → keyword snippets returned.

---

## Execution order & phase independence

| Phase | Depends on | Can ship alone? | Primary files |
|-------|-----------|-----------------|---------------|
| 1 — Packaging | none | yes (unblocks everything in installed app) | `pyproject.toml`, `scripts/build-app-bundle.sh` |
| 2 — Local LLM | none (daemon source) | yes (BYOK-free local answers) | `orbit/check/llm.py`, `tests/`, minimal Swift |
| 3 — Cloud relay | none | yes (cloud answers) | `services/orbit-relay/*`, `orbit/check/llm.py`, `scripts/build-app-bundle.sh`, Swift |
| 4 — Chat UX | 2 (for local flag) | mostly | `OrbitAccessApp/**` |
| 5 — Verify | 1–4 | n/a | scripts/tests |

Recommended sequence: **1 → 2 → 3 → 4 → 5**. Phase 1 is the single highest-impact fix for the installed app; Phase 2 gives a zero-config local route; Phase 3 restores the one-tap cloud experience.

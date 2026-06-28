# Plan: Orbit Cloud AI Relay (shared subscription, abuse-safe)

> Let Orbit Access users get cloud AI answers **without configuring their own OpenRouter key**, by routing LLM calls through a **host-controlled relay** that holds your subscription key server-side. Protect against abuse with device registration, rate limits, and spending caps — never embed the key in the app or daemon binary.

**Scope:** New deployable relay service (`services/orbit-relay/`), Python daemon LLM routing (`orbit/check/llm.py`), minimal Orbit Access onboarding UI (`OrbitAccessApp/`). Bridge `/api/chat` contract unchanged.

**Motivation:** Chat today fails without `OPENROUTER_API_KEY` in `~/.orbit/.env`. Downloaders cannot use AI out of the box. Hardcoding a key in the repo/app is extractable and billable by anyone. A relay keeps the key on your server while giving a one-tap “Enable Cloud AI” experience.

**References:**
- `orbit/check/llm.py:10-40` — current key load + `complete(system, user) -> str`
- `orbit/browser_bridge/server.py:249-279` — `/api/chat` calls `complete()` after local `search_bridge`
- `OrbitAccessApp/Stores/ChatStore.swift:33-75` — online/offline chat routing
- `plans/09-offline-orbit-access.md` — capability flags; anti-pattern: don’t call OpenRouter from Swift
- `plans/orbitaccessappdesign.md:144-152` — offline vs live services
- `docs/gdpr/PRIVACY_POLICY.md` — update when cloud path ships

**Out of scope (defer):**
- User accounts / email login (device token only for v1)
- Billing / Stripe metering
- True token streaming from OpenRouter through relay (v1 can mirror today’s single `delta` SSE)
- Task `dispatch()` streaming through relay (chat only in v1; dispatch stays BYOK or follow-up)
- Multi-tenant relay for third-party operators

---

## Phase 0: Documentation Discovery (COMPLETE)

### Sources consulted

| Source | What was read |
|--------|---------------|
| `orbit/check/llm.py` | `_load_api_key()`, `complete()`, OpenRouter config |
| `orbit/check/dispatch.py` | Reuses `_load_api_key` for task dispatch (out of v1 scope) |
| `orbit/browser_bridge/server.py` | `_handle_chat`, `_CHAT_SYSTEM`, SSE shape |
| `orbit/search/hybrid.py` | `search_bridge()` — context stays local |
| `OrbitAccessApp/IPC/OrbitBridgeClient.swift` | `chatStream`, SSE decode |
| `OrbitAccessApp/App/AppViewModel.swift` | `canUseAIChat`, daemon polling |
| `OrbitAccessApp/OrbitAccessApp.entitlements` | `network.client` already present |
| `OrbitAccessApp/ISSUE_REPORT.md` | Keychain removed for DB bookmarks; Keychain OK for secrets |
| `plans/09-offline-orbit-access.md` | Bridge-only LLM; capability model |
| `plans/10-one-line-install.md` | Only doc mentioning `OPENROUTER_API_KEY` |
| `scripts/grep_antipatterns.sh` | Cloud exfil guard patterns |

### Allowed APIs (verified — copy, do not invent)

**Python LLM (extend, don’t replace):**

```python
# orbit/check/llm.py — existing
def complete(system: str, user: str) -> str: ...

# orbit/browser_bridge/server.py — existing chat handler pattern
answer = complete(_CHAT_SYSTEM, user_msg)
self._stream_chat_sse(answer or "", hits)
```

**Bridge chat request/response (unchanged wire contract):**

```
POST /api/chat  {"query": "<string>"}
→ SSE: event delta {text}, event sources {hits}, event done
```

**Swift bridge (unchanged for chat body):**

```swift
// OrbitBridgeClient.swift — existing
func chatStream(_ query: String) -> AsyncThrowingStream<ChatChunk, Error>
```

**New relay HTTP API (to implement — v1 contract):**

```
POST /v1/devices/register
  Body: {"install_id": "<uuid>", "app_version": "<string>"}
  Headers: optional X-Orbit-Invite: <code>  (if INVITE_REQUIRED)
  → 201 {"device_token": "<opaque>", "expires_at": "<iso8601>"}

POST /v1/chat/completions
  Headers: Authorization: Bearer <device_token>
  Body: {"system": "<string>", "user": "<string>", "model": "owl-alpha"}
  → 200 {"content": "<string>"}
  → 429 {"error": "rate_limit_exceeded", "retry_after": 3600}
  → 401 {"error": "invalid_token"}
```

**Config files on device (extend `~/.orbit/`):**

```
~/.orbit/cloud.json   # written by app: {"device_token": "...", "relay_base_url": "..."}
~/.orbit/.env         # optional BYOK override: OPENROUTER_API_KEY=... (wins over cloud)
```

### Anti-patterns to avoid

- Do **not** put `OPENROUTER_API_KEY` in Swift, daemon source, git, or the `.app` bundle.
- Do **not** call OpenRouter from Swift (`plans/09-offline-orbit-access.md:117`).
- Do **not** send raw `orbit.db` or full capture logs to the relay — only the assembled `system` + `user` strings already built in `_handle_chat`.
- Do **not** log request `user`/`system` bodies on the relay in production (metadata only: device id hash, token count, status).
- Do **not** skip explicit user opt-in before first cloud request (GDPR/consent).
- Do **not** remove BYOK path — `OPENROUTER_API_KEY` in `~/.orbit/.env` should override cloud for developers.

### Capability matrix (after implementation)

| Setup | Context search | AI answer |
|-------|----------------|-----------|
| Daemon off, DB ✓ | Lexical (offline) | Snippet list only |
| Daemon on, no cloud/BYOK | `search_bridge` local | Error with enable prompt |
| Daemon on, cloud enabled | Local | Relay → OpenRouter |
| Daemon on, BYOK in `.env` | Local | Direct OpenRouter |

---

## Phase 1: Relay service skeleton

**What to implement:** A small standalone FastAPI service under `services/orbit-relay/` that registers devices and proxies chat completions to OpenRouter. Key lives only in relay env vars.

### Tasks

1. **Create `services/orbit-relay/`** — copy structure from minimal FastAPI layout:

   ```
   services/orbit-relay/
   ├── pyproject.toml          # fastapi, uvicorn, httpx, pydantic
   ├── README.md               # deploy + env vars (not user-facing product doc)
   ├── orbit_relay/
   │   ├── __init__.py
   │   ├── main.py             # FastAPI app, routes
   │   ├── auth.py             # Bearer device_token validation
   │   ├── limits.py           # per-device + per-IP counters
   │   ├── openrouter.py       # forward to OpenRouter (copy pattern from llm.py)
   │   ├── store.py            # SQLite: devices, usage_daily
   │   └── config.py           # pydantic-settings from env
   └── tests/
       └── test_limits.py
   ```

2. **`config.py`** — env vars (document in relay README):

   | Variable | Purpose | Suggested default |
   |----------|---------|-------------------|
   | `OPENROUTER_API_KEY` | Your subscription key | **required** |
   | `ORBIT_RELAY_SECRET` | HMAC secret for token signing | **required** |
   | `DAILY_REQUESTS_PER_DEVICE` | Chat calls / device / UTC day | `40` |
   | `DAILY_TOKENS_PER_DEVICE` | Est. tokens / device / day | `80000` |
   | `DAILY_REQUESTS_PER_IP` | Anti-bot ceiling | `200` |
   | `MAX_PROMPT_CHARS` | Reject oversized prompts | `32000` |
   | `INVITE_CODE` | If set, registration requires matching header | optional |
   | `RELAY_DISABLED` | Kill switch (`1` = all 503) | `0` |

3. **`POST /v1/devices/register`** — copy logic sketch:

   ```python
   # store.py — SQLite schema
   # devices(id TEXT PRIMARY KEY, install_id TEXT UNIQUE, created_at, revoked INTEGER)
   # usage_daily(device_id, day_utc, requests, tokens_est)

   def register_device(install_id: str) -> str:
       token = secrets.token_urlsafe(32)
       token_hash = hmac_hash(token, ORBIT_RELAY_SECRET)
       # persist token_hash, return raw token once
       return token
   ```

4. **`POST /v1/chat/completions`** — copy OpenRouter call from `orbit/check/llm.py:29-40` but use `httpx` async client server-side; estimate tokens as `len(system)+len(user)` for limit accounting until tokenizer added.

5. **Rate limit checks in `limits.py`** — before OpenRouter call:
   - Increment `usage_daily` for device + IP
   - Return `429` with `retry_after` if over cap
   - Return `413` if `len(system)+len(user) > MAX_PROMPT_CHARS`

6. **`GET /health`** — `{"ok": true}` for deploy probes.

### Documentation references

- `orbit/check/llm.py:29-40` — OpenRouter request shape to copy
- OpenRouter API docs — `POST /api/v1/chat/completions` (same as OpenAI client)

### Verification checklist

```bash
cd services/orbit-relay && pip install -e ".[dev]" && pytest
# Manual with relay running locally:
curl -s -X POST localhost:8080/v1/devices/register \
  -H 'Content-Type: application/json' \
  -d '{"install_id":"test-install-1","app_version":"0.1"}'
# → device_token

curl -s -X POST localhost:8080/v1/chat/completions \
  -H "Authorization: Bearer <token>" \
  -H 'Content-Type: application/json' \
  -d '{"system":"You are helpful.","user":"Say hi in 3 words.","model":"owl-alpha"}'
# → {"content":"..."}
```

### Anti-pattern guards

- Do not commit `.env` with real keys; use `.env.example` only.
- Do not store raw `device_token` in SQLite — store HMAC hash only.

---

## Phase 2: Daemon LLM routing (cloud vs BYOK)

**What to implement:** Extend `orbit/check/llm.py` so `complete()` tries BYOK first, then cloud relay if `~/.orbit/cloud.json` exists. No bridge changes required.

### Tasks

1. **Add `orbit/check/cloud_config.py`** — load `~/.orbit/cloud.json`:

   ```python
   @dataclass
   class CloudConfig:
       device_token: str
       relay_base_url: str  # e.g. https://ai.orbit.example

   def load_cloud_config() -> CloudConfig | None: ...
   ```

2. **Add `complete_via_relay(system, user, cfg) -> str`** in `llm.py`:

   ```python
   def complete_via_relay(system: str, user: str, cfg: CloudConfig) -> str:
       import httpx
       r = httpx.post(
           f"{cfg.relay_base_url.rstrip('/')}/v1/chat/completions",
           headers={"Authorization": f"Bearer {cfg.device_token}"},
           json={"system": system, "user": user, "model": _MODEL},
           timeout=120.0,
       )
       r.raise_for_status()
       return r.json()["content"]
   ```

3. **Change `complete()` resolution order** (copy pattern, extend `llm.py`):

   ```python
   def complete(system: str, user: str) -> str:
       # 1. BYOK — env or ~/.orbit/.env OPENROUTER_API_KEY
       if key := _try_load_api_key():
           return _complete_openrouter(system, user, key)
       # 2. Cloud relay
       if cfg := load_cloud_config():
           return complete_via_relay(system, user, cfg)
       raise RuntimeError(_missing_key_message())
   ```

   Refactor existing body into `_complete_openrouter()` without behavior change for BYOK users.

4. **Map relay errors to bridge-friendly messages** — in `server.py` `_handle_chat`, existing `except` already returns 503 JSON `{"error": str(exc)}`; ensure `httpx.HTTPStatusError` for 429 becomes user-readable: *"Daily cloud AI limit reached. Try again tomorrow or add your own API key."*

5. **Add `httpx` to root `pyproject.toml`** if not present (relay uses it too).

### Documentation references

- `orbit/check/llm.py:15-40` — current implementation to refactor
- `orbit/browser_bridge/server.py:271-277` — exception → 503 path

### Verification checklist

```bash
# BYOK still works
echo 'OPENROUTER_API_KEY=sk-...' >> ~/.orbit/.env
python -c "from orbit.check.llm import complete; print(complete('s','hi')[:20])"

# Cloud path (relay running)
cat > ~/.orbit/cloud.json <<EOF
{"device_token":"<token>","relay_base_url":"http://127.0.0.1:8080"}
EOF
unset OPENROUTER_API_KEY
python -c "from orbit.check.llm import complete; print(complete('s','hi'))"

curl -s -X POST http://127.0.0.1:8765/api/chat \
  -H 'Content-Type: application/json' -d '{"query":"test"}'
# Expect SSE 200 when daemon running
```

### Anti-pattern guards

- Do not add relay URL or token to environment variables logged by daemon startup.
- Do not change `/api/chat` request/response shape.

---

## Phase 3: Orbit Access — sleek enablement UX

**What to implement:** One-time opt-in flow that registers the device with your relay and stores the token securely. Chat works without manual `.env` editing.

### Tasks

1. **Add `OrbitAccessApp/Services/CloudAIService.swift`**:

   ```swift
   struct CloudAIConfig: Codable {
       let deviceToken: String
       let relayBaseURL: String
       enum CodingKeys: String, CodingKey {
           case deviceToken = "device_token"
           case relayBaseURL = "relay_base_url"
       }
   }

   final class CloudAIService {
       static let defaultRelayURL = URL(string: "https://ai.YOUR_DOMAIN")!  // replace at build
       func isEnabled() -> Bool { ... }  // cloud.json exists + token in Keychain
       func register(installID: UUID) async throws -> CloudAIConfig
       func persist(_ config: CloudAIConfig) throws  // Keychain + write ~/.orbit/cloud.json
       func disable() throws
   }
   ```

   - **Keychain** stores `device_token` (service: `com.orbit.access.cloud`, account: install UUID).
   - **`~/.orbit/cloud.json`** written for Python daemon (token duplicated is acceptable v1; file mode `0600`).

2. **Add `OrbitAccessApp/Views/Settings/CloudAISettingsView.swift`** (or sheet):
   - Toggle: **Orbit Cloud AI**
   - Privacy line: *"Context snippets from your question are sent to Orbit's AI service to generate answers. Nothing else leaves your Mac."*
   - Link: *"Use your own API key instead"* → opens `~/.orbit` in Finder + short instructions
   - Status: *"40 messages/day"* (static copy matching relay default)

3. **Chat empty-state / first-send prompt** — copy pattern from `MainChatView.swift` offline badge:

   When `canUseAIChat && !cloudAI.isEnabled && !hasBYOK`:
   - Inline card above input: **"Enable Cloud AI"** button → calls `register()` → success toast
   - Do not block offline snippet search when daemon off

4. **Detect BYOK** — `CloudAIService.hasBYOK()` reads `~/.orbit/.env` for `OPENROUTER_API_KEY=` line (read-only); hide cloud promo if BYOK present.

5. **Wire `AppViewModel`**:

   ```swift
   var canUseAIChat: Bool { canUseLiveServices && (cloudAI.isEnabled || cloudAI.hasBYOK) }
   ```

   Adjust from current `canUseAIChat == canUseLiveServices` so chat button shows enable flow instead of immediate 503.

6. **Error surfacing** — `ChatStore` already sets `errorMessage` from bridge; map 429 relay errors to friendly copy in `OrbitBridgeError.serverMessage`.

### Documentation references

- `OrbitAccessApp/Views/Chat/MainChatView.swift:67-71` — offline badge pattern
- `OrbitAccessApp/Stores/ChatStore.swift:33-44` — send routing
- `OrbitAccessApp/Extensions/OrbitPaths.swift` — `~/.orbit/` paths
- `plans/09-offline-orbit-access.md:131-144` — capability flags

### Verification checklist

```bash
cd OrbitAccessApp && swift build
rg 'CloudAIService|cloud\.json' OrbitAccessApp/
```

Manual:

| # | Setup | Action | Pass |
|---|-------|--------|------|
| 1 | Fresh install, daemon on, relay up | Tap Enable Cloud AI | `~/.orbit/cloud.json` created; chat returns answer |
| 2 | Cloud enabled | Send 41st message same UTC day | Friendly rate-limit message |
| 3 | BYOK in `.env` | Open app | No cloud promo; direct OpenRouter |
| 4 | Cloud off, daemon on | Send | Prompt to enable, not raw 503 |
| 5 | Daemon off, DB ✓ | Send | Offline snippet mode unchanged |

### Anti-pattern guards

- Do not call OpenRouter from Swift.
- Do not put relay admin secret or OpenRouter key in the app.
- Do not enable cloud AI silently — require explicit button tap.

---

## Phase 4: Abuse hardening & operations

**What to implement:** Production safeguards so a leaked invite link or viral download cannot drain your subscription.

### Tasks

1. **OpenRouter dashboard** (manual, document in `services/orbit-relay/README.md`):
   - Set **monthly spending limit** (hard cap)
   - Enable usage alerts at 50% / 80%

2. **Relay kill switch** — `RELAY_DISABLED=1` returns 503 for all completions; app shows *"Cloud AI temporarily unavailable."*

3. **Device revocation** — CLI or admin script:

   ```bash
   python -m orbit_relay.admin revoke --install-id <uuid>
   ```

4. **Optional invite gate** — if `INVITE_CODE` env set, reject registration without `X-Orbit-Invite` header (distribute code privately to beta users).

5. **IP + device anomaly** — in `limits.py`:
   - Max **3 registrations per IP per day**
   - Reject duplicate `install_id` re-registration (return existing token or 409)

6. **Structured logging** (no bodies):

   ```json
   {"event":"chat","device_id_hash":"...","status":200,"tokens_est":1200,"latency_ms":840}
   ```

7. **Privacy policy patch** — add § to `docs/gdpr/PRIVACY_POLICY.md`: cloud AI opt-in, what's transmitted (prompt only), retention (none for message bodies), rate limits.

8. **Deploy relay** — document one target (e.g. Fly.io):
   - `fly secrets set OPENROUTER_API_KEY=... ORBIT_RELAY_SECRET=...`
   - HTTPS only; set `CloudAIService.defaultRelayURL` to production URL

### Documentation references

- `docs/gdpr/PRIVACY_POLICY.md`
- `scripts/grep_antipatterns.sh` — ensure no key patterns in repo

### Verification checklist

```bash
# Simulate rate limit
for i in $(seq 1 45); do curl -s -o /dev/null -w "%{http_code}\n" \
  -X POST $RELAY/v1/chat/completions -H "Authorization: Bearer $TOKEN" \
  -d '{"system":"s","user":"hi","model":"owl-alpha"}'; done
# Expect 429 after daily cap

rg 'OPENROUTER_API_KEY\s*=\s*["\']sk' --glob '!*.example' .
# Expect: zero matches outside relay deploy docs
```

### Anti-pattern guards

- Do not disable rate limits in production for convenience.
- Do not log full prompts even in debug builds of the relay.

---

## Phase 5: Verification

### Acceptance criteria

> A new user can download Orbit Access, start the daemon, tap **Enable Cloud AI**, send a chat message, and receive an AI answer — without ever seeing or configuring `OPENROUTER_API_KEY`. A single abusive device cannot exceed configured daily caps, and BYOK users are unaffected.

### Tasks

1. **Static checks**

   ```bash
   bash scripts/grep_antipatterns.sh
   rg 'OPENROUTER_API_KEY' OrbitAccessApp/   # Expect: zero
   rg 'complete_via_relay|load_cloud_config' orbit/check/
   cd OrbitAccessApp && swift build
   cd services/orbit-relay && pytest
   python scripts/test_bridge_api.py --port 18765   # BYOK or mock relay
   ```

2. **Regression matrix**

   | # | Feature | Expected |
   |---|---------|----------|
   | 1 | Offline snippet chat (daemon off) | Unchanged (`plans/09-offline-orbit-access.md`) |
   | 2 | `search_bridge` without vec_atoms | Unchanged (lexical fallback) |
   | 3 | BYOK `.env` | Direct OpenRouter, no relay call |
   | 4 | Bridge `/api/status` | Unchanged |

3. **Security review checklist**
   - [ ] OpenRouter key only in relay host env
   - [ ] Device tokens hashed at rest on relay
   - [ ] HTTPS for relay in production
   - [ ] User opt-in before first cloud request
   - [ ] Spending limit set on OpenRouter account

### Anti-pattern guards

- Do not mark complete without manual end-to-end test on a clean `~/.orbit/` (no `.env` key).
- Do not commit `cloud.json`, `.env`, or test tokens.

---

## Execution order

```
Phase 1 (relay skeleton)
    → Phase 2 (daemon routing)     # can test with curl + cloud.json before UI
    → Phase 3 (app UX)
    → Phase 4 (hardening + deploy)
    → Phase 5 (verification)
```

Phases 1 and 2 can be validated in terminal before any Swift work. Phase 4 invite gate and admin revoke can ship after Phase 3 if beta is small.

## Known gaps (out of scope)

| Gap | Reason deferred |
|-----|-----------------|
| Apple ID / email auth | Device token sufficient for v1 |
| Streaming tokens through relay | Matches current pseudo-SSE; upgrade later |
| `dispatch()` via relay | Higher abuse surface; keep BYOK for task execution |
| Per-user billing | No payment integration yet |
| E2E encrypted prompts | Trust-based relay v1; document clearly |

## Copy-ready file touch list

| File | Phases |
|------|--------|
| `services/orbit-relay/**` (new) | 1, 4 |
| `orbit/check/llm.py` | 2 |
| `orbit/check/cloud_config.py` (new) | 2 |
| `pyproject.toml` | 2 (`httpx` dep) |
| `OrbitAccessApp/Services/CloudAIService.swift` (new) | 3 |
| `OrbitAccessApp/Views/Settings/CloudAISettingsView.swift` (new) | 3 |
| `OrbitAccessApp/App/AppViewModel.swift` | 3 |
| `OrbitAccessApp/Views/Chat/MainChatView.swift` | 3 |
| `OrbitAccessApp/Stores/ChatStore.swift` | 3 (error copy only) |
| `docs/gdpr/PRIVACY_POLICY.md` | 4 |
| `plans/10-one-line-install.md` | 4 (mention cloud opt-in) |

## Phase → chat prompt cheatsheet

Use these as the opening message when executing each phase in a fresh session:

| Phase | Prompt |
|-------|--------|
| 1 | *"Execute Phase 1 of `plans/11-cloud-ai-relay.md`: create `services/orbit-relay/` FastAPI service with device registration, rate limits, and OpenRouter proxy. Copy OpenRouter call shape from `orbit/check/llm.py:29-40`."* |
| 2 | *"Execute Phase 2 of `plans/11-cloud-ai-relay.md`: add `cloud_config.py` and relay routing to `orbit/check/llm.py` with BYOK-first precedence."* |
| 3 | *"Execute Phase 3 of `plans/11-cloud-ai-relay.md`: add Cloud AI enablement UX in OrbitAccessApp per plan — Keychain + `~/.orbit/cloud.json`, no OpenRouter in Swift."* |
| 4 | *"Execute Phase 4 of `plans/11-cloud-ai-relay.md`: abuse hardening, deploy docs, privacy policy update."* |
| 5 | *"Execute Phase 5 of `plans/11-cloud-ai-relay.md`: run verification matrix and fix regressions."* |

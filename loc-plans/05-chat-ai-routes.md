# Plan 05: Chat AI routes (local, cloud, BYOK)

Three ways to get AI answers in chat — all route through the daemon bridge (`POST /api/chat`), never Swift → LLM directly. Cloud agents added Ollama mode and relay auth but could not run Ollama, relay, or the live app.

**Commits:** `cdb59cd`, `5d4d06d`, `bd05365`  
**Source plans:** `plans/11-cloud-ai-relay.md`, `plans/14-chat-enablement.md`

## Prerequisites

- Daemon online (`03-daemon-lifecycle.md`)
- Signed in (`04-user-signup-and-scoping.md`)
- Some captured context (switch apps for 1–2 min) so chat has snippets to retrieve

## Part A — Local Ollama

### Install and run Ollama

```bash
# https://ollama.com/download
ollama serve &
ollama pull llama3.1
curl -s http://127.0.0.1:11434/api/tags | head
```

### Configure via Orbit Access UI

1. Settings → **Cloud AI** / AI setup.
2. Choose **Local model (Ollama)**.
3. Enter model name `llama3.1` (or your pulled tag).
4. Save.

**Pass:** `~/.orbit/.env` contains:

```
ORBIT_LLM_PROVIDER=local
ORBIT_LOCAL_LLM_MODEL=llama3.1
ORBIT_LOCAL_LLM_BASE_URL=http://localhost:11434/v1
```

### Chat test

1. Chat tab → send: *What apps was I just using?*
2. **Pass:** streaming answer (single delta chunk today), not 503.
3. **Pass:** input placeholder shows normal “Ask Orbit…” not “Offline mode”.

CLI equivalent:

```bash
curl -s -N -X POST http://127.0.0.1:8765/api/chat \
  -H 'Content-Type: application/json' \
  -d '{"query":"hello from curl"}'
```

**Pass:** SSE `event: delta` with model text.

### Error copy

Stop Ollama (`pkill ollama`) and send again.

**Pass:** friendly error above input (not raw `URLError` / stack trace).

## Part B — BYOK (OpenRouter)

1. Disable Cloud AI / local mode in settings.
2. Add to `~/.orbit/.env`:

```
OPENROUTER_API_KEY=sk-or-...
```

3. Restart daemon: sidebar Stop → Start.
4. Send a chat message.

**Pass:** answer streams; no cloud registration prompt; relay not required.

## Part C — Cloud AI (relay)

### Start relay locally

```bash
cd ~/path/to/orbit/services/orbit-relay
cp .env.example .env
# Edit: OPENROUTER_API_KEY, ORBIT_RELAY_SECRET (random string)
bash run-local.sh
```

**Pass:** `curl -s http://127.0.0.1:8080/health` → `{"ok":true}`

### Enable in app

1. Settings or chat card → **Enable Cloud AI**.
2. **Pass:** no connection refused; `~/.orbit/cloud.json` created:

```bash
cat ~/.orbit/cloud.json   # device_token, relay_base_url
```

3. Send chat message.

**Pass:** answer via relay; rate-limit message after daily cap (optional stress test).

### Kill switch

Set `RELAY_DISABLED=1` in relay `.env`, restart relay, send chat.

**Pass:** user-facing “Cloud AI temporarily unavailable” (not opaque JSON).

## Part D — Offline / no AI fallback

1. Stop daemon; keep `~/.orbit/orbit.db`.
2. Send chat message.

**Pass:** offline keyword snippets returned; copy says offline mode.

3. Daemon on, no AI configured (no Ollama, no BYOK, no cloud).

**Pass:** enable prompt or clear “no AI credentials” message — not a silent failure.

## Part E — Chat routing regression (`5d4d06d`)

| Scenario | Expected |
|----------|----------|
| Daemon off, DB present | Offline snippets; search works |
| Daemon on, hybrid search | Sidebar search returns hits |
| Invalid relay URL | Human-readable error, not `NSURLError -1004` raw |
| Cloud + local both configured | Last saved mode in settings wins; `.env` `ORBIT_LLM_PROVIDER` matches |

## Pass criteria

- [ ] Part A: Ollama chat answers
- [ ] Part B: BYOK works without relay
- [ ] Part C: Cloud AI register + chat
- [ ] Part D: offline fallback correct
- [ ] Part E: error messages are user-readable

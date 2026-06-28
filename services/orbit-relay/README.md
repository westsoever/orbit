# Orbit Cloud AI Relay

Standalone FastAPI service that registers Orbit Access devices and proxies chat completions to OpenRouter using **your** subscription key. The key never ships in the app or daemon.

## Environment variables

| Variable | Required | Default | Purpose |
|----------|----------|---------|---------|
| `OPENROUTER_API_KEY` | yes | — | Your OpenRouter API key |
| `ORBIT_RELAY_SECRET` | yes | — | HMAC secret for hashing device tokens at rest |
| `DAILY_REQUESTS_PER_DEVICE` | no | `40` | Chat calls per device per UTC day |
| `DAILY_TOKENS_PER_DEVICE` | no | `80000` | Estimated prompt chars per device per day |
| `DAILY_REQUESTS_PER_IP` | no | `200` | Chat calls per IP per UTC day |
| `MAX_REGISTRATIONS_PER_IP_PER_DAY` | no | `3` | Device registrations per IP per day |
| `MAX_PROMPT_CHARS` | no | `32000` | Reject oversized prompts |
| `INVITE_CODE` | no | — | If set, `X-Orbit-Invite` header required on register |
| `RELAY_DISABLED` | no | `0` | Set `1` to disable all completions (kill switch) |
| `RELAY_DATABASE_PATH` | no | `relay.db` | SQLite path for devices and usage |
| `ORBIT_DEFAULT_MODEL` | no | `owl-alpha` | Default model if client omits `model` |
| `TOKEN_TTL_DAYS` | no | `365` | Device token lifetime |

Copy `.env.example` to `.env` and set `OPENROUTER_API_KEY` and `ORBIT_RELAY_SECRET`.

**OpenRouter dashboard:** set a monthly spending limit and usage alerts at 50% / 80% before exposing the relay publicly.

## Operations

### Kill switch

Set `RELAY_DISABLED=1` to return HTTP 503 for registration and chat. Orbit Access shows *"Cloud AI temporarily unavailable."*

### Revoke a device

```bash
cd services/orbit-relay
source .venv/bin/activate
orbit-relay-admin revoke --install-id <uuid>
```

### Production URL

Set `ORBIT_RELAY_URL` when building or launching Orbit Access (e.g. `https://ai.yourdomain.com`). Defaults to `http://127.0.0.1:8080` for local development.

## Install and run locally

```bash
cd services/orbit-relay
python -m venv .venv && source .venv/bin/activate
pip install -e ".[dev]"
cp .env.example .env   # edit with real values
orbit-relay
# or: uvicorn orbit_relay.main:app --host 0.0.0.0 --port 8080
```

## API

### `GET /health`

```json
{"ok": true}
```

### `POST /v1/devices/register`

```bash
curl -s -X POST http://localhost:8080/v1/devices/register \
  -H 'Content-Type: application/json' \
  -d '{"install_id":"550e8400-e29b-41d4-a716-446655440000","app_version":"0.1"}'
```

Response `201`:

```json
{"device_token": "<opaque>", "expires_at": "2027-06-29T00:00:00+00:00"}
```

Optional header when `INVITE_CODE` is set: `X-Orbit-Invite: <code>`.

### `POST /v1/chat/completions`

```bash
curl -s -X POST http://localhost:8080/v1/chat/completions \
  -H "Authorization: Bearer <device_token>" \
  -H 'Content-Type: application/json' \
  -d '{"system":"You are helpful.","user":"Say hi in 3 words.","model":"owl-alpha"}'
```

Response `200`:

```json
{"content": "..."}
```

Rate limit response `429`:

```json
{"error": "rate_limit_exceeded", "retry_after": 3600}
```

## Tests

```bash
pip install -e ".[dev]"
pytest
```

## Deploy (Fly.io sketch)

```bash
fly launch --no-deploy
fly secrets set OPENROUTER_API_KEY=... ORBIT_RELAY_SECRET=...
fly deploy
```

Use HTTPS in production. Point Orbit Access `relay_base_url` at your deployed host.

## Security notes

- Device tokens are stored as HMAC-SHA256 hashes only — raw tokens are returned once at registration.
- Request bodies are not logged; only metadata (device id hash, token estimate, latency).
- Do not commit `.env` with real keys.

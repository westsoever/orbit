#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
[[ -d .venv ]] || python3 -m venv .venv
source .venv/bin/activate
pip install -q -e ".[dev]"
if [[ ! -f .env ]]; then
  cp .env.example .env
  echo "Created .env from template. Edit OPENROUTER_API_KEY and ORBIT_RELAY_SECRET, then re-run." >&2
  exit 1
fi
if ! grep -q '^OPENROUTER_API_KEY=.\+' .env || ! grep -q '^ORBIT_RELAY_SECRET=.\+' .env; then
  echo "ERROR: set OPENROUTER_API_KEY and ORBIT_RELAY_SECRET in services/orbit-relay/.env" >&2
  exit 1
fi
echo "Starting orbit-relay on http://127.0.0.1:8080 …"
exec orbit-relay

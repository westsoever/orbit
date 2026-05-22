#!/usr/bin/env bash
set -e
cd "$(dirname "$0")/.."

echo "Checking for anti-patterns..."

! grep -RIn --include='*.py' -- '\-\-frontmost\|--watch\|--text-only' orbit/ && echo "OK: no macapptree flag anti-patterns"
! grep -RIn --include='*.py' -- 'INT PRIMARY KEY\|BIGINT PRIMARY KEY' orbit/ scripts/ && echo "OK: no INT PRIMARY KEY (must be INTEGER)"
! grep -RIn --include='*.py' -- 'subprocess.*macapptree' orbit/ && echo "OK: no subprocess macapptree"
! grep -RIn --include='*.py' -- 'openai\|cohere\|voyageai' orbit/ && echo "OK: no cloud embedding providers"

echo "Anti-pattern check: OK"

# Plan 04: User sign-up and user-scoped context

Validates local user identity, onboarding gate, and per-user isolation in SQLite. Merged in #3 without macOS GUI or live capture testing.

**Commit:** `5126edf` — *Add user sign-up flow and user-scoped context collection*  
**Tests (run in Plan 01):** `tests/test_user_session.py`, `services/orbit-relay/tests/test_auth.py`

## Part A — Fresh onboarding

Use a clean profile or backup/remove `~/.orbit/` first (optional):

```bash
orbit stop 2>/dev/null || true
mv ~/.orbit ~/.orbit.bak-$(date +%Y%m%d)   # optional
```

1. Launch Orbit.
2. **Pass:** Sign-up screen appears before main UI.
3. Create account: email, display name, accept privacy toggle.
4. **Pass:** lands in main window; no daemon start before sign-in completes.

Check files:

```bash
test -f ~/.orbit/session.json
sqlite3 ~/.orbit/orbit.db "SELECT id, email FROM users LIMIT 5;"
cat ~/.orbit/session.json
```

**Pass:** `session.json` contains `user_id`; `users` row matches sign-up email.

## Part B — Daemon gated on sign-in

1. Sign out (Settings → Account → sign out, if exposed) or delete `session.json` and relaunch.
2. **Pass:** capture/daemon does not auto-start while signed out.
3. Sign in again.
4. **Pass:** daemon auto-start resumes (`03-daemon-lifecycle.md` Part A).

## Part C — Capture scoped to active user

1. Signed in as User A — switch between Terminal and Notes for ~1 min.
2. Confirm events exist:

```bash
UID=$(python3 -c "import json; print(json.load(open('$HOME/.orbit/session.json'))['user_id'])")
sqlite3 ~/.orbit/orbit.db \
  "SELECT count(*) FROM context_events WHERE user_id = '$UID';"
```

**Pass:** count > 0; all new rows carry active `user_id`.

## Part D — Search and privacy scoped

1. Sidebar search for text visible in a captured window.
2. **Pass:** results only from current user's atoms.
3. Run:

```bash
orbit privacy show-policy
orbit privacy export --out /tmp/orbit-export.jsonl
```

**Pass:** export succeeds; file contains only current user's data (no cross-user leakage if you create a second local user).

## Part E — Optional cloud account link

1. On sign-up or in Settings, enable **Link cloud account**.
2. Enter password; submit.

**Requires:** relay running (`05-chat-ai-routes.md` Part C) with valid `OPENROUTER_API_KEY` and `ORBIT_RELAY_SECRET`.

**Pass:**

- Relay logs show signup/login.
- `users.cloud_user_id` populated in SQLite.
- Sign-in persists across app restart.

**Skip** if relay is not deployed yet; local-only sign-up still must pass Parts A–D.

## Part F — Legacy DB migration

If you have an **old** `orbit.db` from before #3 (no `users` table):

1. Back up DB.
2. Open with latest Orbit / run `orbit start` once.
3. **Pass:** migration adds `users`, `user_id` columns; legacy user row exists; existing events backfilled.

## Pass criteria

- [ ] Part A: onboarding + `session.json`
- [ ] Part B: daemon gated on sign-in
- [ ] Part C: capture rows tagged with `user_id`
- [ ] Part D: search/privacy respect active user
- [ ] Part E: cloud link (optional, relay required)
- [ ] Part F: legacy migration (if applicable)

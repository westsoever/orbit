# Data Protection Impact Assessment (DPIA) Template — Art. 35 GDPR

> **For B2B buyers** deploying Orbit for employee context capture. Complete with legal counsel and works-council consultation where required (DE/NL/FR).

## 1. Processing description

| Field | Response |
|-------|----------|
| Controller | _Employer legal entity_ |
| Processor (if any) | _Orbit vendor / host_ |
| Purpose | _e.g. productivity assistance, task detection, audit trail_ |
| Categories of data subjects | Employees using monitored workstations |
| Categories of personal data | App/window metadata, AX text, optional URLs, optional file paths, optional OCR text |
| Capture tiers enabled | Tier 0 ☐ Tier 1 ☐ Tier 2 ☐ Tier 3 ☐ Tier 4 ☐ Tier 5 ☐ |
| Retention period | _Default 90 days; policy key `retention_days`_ |
| Recipients | _Local device only / LLM provider for `orbit check`_ |
| Transfers outside EEA | _Yes/No — document subprocessors_ |

## 2. Necessity and proportionality

- Why is systematic monitoring necessary for the stated purpose?
- Can a less intrusive means achieve the same goal (e.g. Tier 0–1 only, work-hours scope)?
- Document exclusion list for banking/password apps.
- Confirm keystroke logging and continuous screen recording are **not** enabled.

## 3. Risks to rights and freedoms

| Risk | Likelihood | Severity | Mitigation |
|------|------------|----------|------------|
| Over-capture of sensitive content | | | Tier minimisation, exclusions, retention purge |
| Covert monitoring / lack of transparency | | | Employee notice, policy URL, consent/opt-in for enhanced tiers |
| Re-identification via URLs/file paths | | | Tier 2/3 opt-in, URL blocklist for internal tools |
| Unauthorised access to local DB | | | File permissions, future SQLCipher + keychain |
| LLM leakage via `orbit check` | | | Dry-run, scoped prompts, DPA with provider |

## 4. Measures to address risks

- Technical: local-first storage, `capture_audit` table, `orbit privacy export/delete`
- Organisational: written monitoring policy, training, DPIA review cycle
- Legal: legitimate interest assessment (see `LIA_TEMPLATE.md`) or consent for B2C

## 5. Consultation

- DPO sign-off: ______________ Date: __________
- Works council (if applicable): ______________ Date: __________
- Supervisory authority consultation required? ☐ Yes ☐ No

## 6. Review

- Next review date: __________
- Trigger events: new tier enabled, new country rollout, incident

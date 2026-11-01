---
id: 57
type: chore
title: MIGRATE.md: adopting sdd in new, brownfield and Spec Kit repos
status: shipped
created: 2026-11-01
approved: f8fe79a6f196367414dc471f77de20a18d914e5f 2026-11-01 joexbayer
shipped: 2026-11-01
---
# 57 MIGRATE.md: adopting sdd in new, brownfield and Spec Kit repos

## What and why
`MIGRATE.md` at the repo root (one page, ~80 lines): adopting sdd in a new project, a brownfield
repo, and a Spec Kit repo, from the NarrowBot pilot's 11 problems. README's "Moving from Spec Kit"
paragraph becomes a link to it. For the beta: the user tries sdd on new projects (2026-11-01).

## Security
none: docs only.

## Built
- `MIGRATE.md` (75 lines): every case (install on main, sync, commit; then gate, budget, launcher,
  secret scan), new project, existing repo (constitution from rules you live by, no backfill),
  Spec Kit repo (remove, convert the constitution, old folders stay), upgrading, overrides.
- `README.md`: the Spec Kit paragraph is now a link to MIGRATE.md.
- Verifier findings fixed: the constitution warning is for a prose `specs/constitution.md` (not
  before the move); the cap is "at most 30" and configurable.
- Check passed. Security: docs only; the guide says to check each gitleaks fingerprint is fake.
Verified by: claude-sonnet-5-5: 14 of 16 claims checked; 2 misleading lines (fixed)

## Review (optional)
<!-- The human's review notes: what to change, one per line. The agent works through them
and says under "## Built" what it changed for each. -->

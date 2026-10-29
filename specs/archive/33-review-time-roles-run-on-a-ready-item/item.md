---
id: 33
type: fix
title: Review-time roles run on a ready item
status: shipped
created: 2026-10-29
approved: b2e28b5160bde02cf27d8b0dc01b14a161a9034f 2026-10-29 joexbayer
shipped: 2026-10-29
---
# 33 Review-time roles run on a ready item

## Current behaviour
<!-- What happens now, and how to reproduce it. -->
Pilot arm B (2026-10-29): the Opus builder wrote "## Built" in its last batch, so the item reached
review (reason ready) and `sdd run verifier 1` and `sdd run finisher 1` were refused: "item 1 is
waiting for the human … no role runs now". The driver stopped before the verifier pass and ship.

## Expected behaviour
<!-- FR-33.1 WHEN <trigger> THE SYSTEM SHALL <response>.
  e.g. <input> → <output> -->
FR-33.1 WHEN an item is ready for review THE SYSTEM SHALL let review-time roles run (any role but
the builder), and still refuse the builder.
  e.g. ready item → `sdd run verifier 3` runs; `sdd run builder 3` → "item 3 is waiting for the human …", exit 2

## Must not change
<!-- Behaviour that has to stay exactly as it is (so the fix breaks nothing else). -->
Every other human-only state (approval, changed plan, contract change, PR, not open) still
refuses every role. Approve and ship stay human-only (SDD_RUN).

## Security
<!-- Does this touch untrusted input, login or permissions, secrets or personal data, a new
dependency, files/network/shell, or CI/agent config? If not: "none: <why>". Otherwise, per risk:
what can go wrong → what we do (an FR with a test, a D line, or "accept: <why>").
    e.g. uploads are untrusted → FR-33.4 rejects non-images and files over 5 MB -->
none: a verifier reads and reports; approve and ship still refuse role runs.

## Test
<!-- The regression test (name and file) that fails now and passes after the fix. -->
tests/t_run.sh: a ready item lets the verifier run and refuses the builder (fails before the fix).

## Built
<!-- Written by the agent at the end of the build, for the review: per requirement what
changed (file:line) and which test proves it; deviations from the plan and why; follow-ups. -->
FR-33.1: .sdd/core/cmd/run.sh, the human's-turn case: `ready` now refuses only the builder.
tests/t_run.sh (end): a ready fix item runs `sdd run verifier` and refuses `sdd run builder` with
exit 2; it failed before the fix ("no role runs now"). Verified: `sdd check` passes.
Verified by: none (one-line fix; its regression test is the proof)

## Review (optional)
<!-- The human's review notes: what to change, one per line. The agent works through them
and says under "## Built" what it changed for each. -->

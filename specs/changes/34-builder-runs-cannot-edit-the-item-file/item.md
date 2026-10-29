---
id: 34
type: fix
title: Builder runs cannot edit the item file
status: open
created: 2026-10-29
approved: d1aa2f8599e7edaf208c0d09dce97f01e9adcb68 2026-10-29 joexbayer
---
# 34 Builder runs cannot edit the item file

## Current behaviour
<!-- What happens now, and how to reproduce it. -->
Pilot arm A (2026-10-29): qwen, as `sdd run builder`, wrote its own "## Built" text into the middle
of the plan (inside How). The plan hash changed, so the approval was void: `task done` refused
every tick and the driver stopped at "plan: changed". In arm B, Opus wrote Built in its last
batch, so the item skipped straight to review.

## Expected behaviour
<!-- FR-34.1 WHEN <trigger> THE SYSTEM SHALL <response>.
  e.g. <input> → <output> -->
FR-34.1 WHEN `sdd run builder` ends THE SYSTEM SHALL restore the item file as it was before the
agent ran (warning when the agent changed it) before ticking the batch's tasks (FR-31.1): the plan
and Built are not the builder's to write.
  e.g. agent appends to item.md → "⚠ the builder edited specs/changes/1-x/item.md: restored (sdd ticks its tasks; Built is written after the build)", then "✓ T-1.1 done …"

## Must not change
<!-- Behaviour that has to stay exactly as it is (so the fix breaks nothing else). -->
Other roles (verifier, finisher, planner) may edit the item file as today. Code the builder wrote
stays. Interactive builders (not `sdd run`) are unaffected.
D-34.1 Restore the whole file, not just the plan part: sdd ticks the tasks itself after the run,
so a builder never needs to write the item file at all, and Built belongs to the finishing step.

## Security
<!-- Does this touch untrusted input, login or permissions, secrets or personal data, a new
dependency, files/network/shell, or CI/agent config? If not: "none: <why>". Otherwise, per risk:
what can go wrong → what we do (an FR with a test, a D line, or "accept: <why>").
    e.g. uploads are untrusted → FR-34.4 rejects non-images and files over 5 MB -->
none: restores a file sdd itself tracks, from a copy made at the start of the run.

## Test
<!-- The regression test (name and file) that fails now and passes after the fix. -->
tests/t_run.sh: a fake builder that writes into the plan and adds "## Built" text; after the run
the item file equals the pre-run copy plus the ticks, the warning is printed, and the tasks tick.

## Built
<!-- Written by the agent at the end of the build, for the review: per requirement what
changed (file:line) and which test proves it; deviations from the plan and why; follow-ups. -->

## Review (optional)
<!-- The human's review notes: what to change, one per line. The agent works through them
and says under "## Built" what it changed for each. -->

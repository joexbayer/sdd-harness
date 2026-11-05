---
id: 62
type: fix
title: sdd next says verified only when it was
status: open
created: 2026-11-05
approved: 20dd02cb51bc9152faf24c90f552b52be2ec9978 2026-11-05 joexbayer
---
# 62 sdd next says verified only when it was

## Current behaviour
A live NarrowBot test (2026-11-04): no verifier ran, "## Built" had no `Verified by:` line, yet `sdd next` said
"Phase: review (verified and written up; …)" (`.sdd/core/lib/common.sh`, `item_phase`), and ship passed
silently: `[profile "lite"] verified = off`, the default. A blind review later found serious defects.

## Expected behaviour
FR-62.1 WHEN an item reaches review and its `verified` gate is on and "## Built" has no real `Verified by:` line
THE SYSTEM SHALL say so in the phase line.
  e.g. no line → `written up, NOT verified (no "Verified by:" line); walk through it with: …`; `Verified by: none (no second model)` → the same, with `Verified by: none`
FR-62.2 WHEN it has a real line THE SYSTEM SHALL say `verified and written up` as today; WHEN the type's gate is off
(e.g. a roadmap) it SHALL say `written up`.
  e.g. `Verified by: sonnet: 2 of 2 FRs proven` → `verified and written up; …`; a roadmap → `written up; …`
FR-62.3 WHEN an item ships unverified in the default `lite` profile THE SYSTEM SHALL warn and still ship: `lite`'s
`verified` goes from off to warn.
  e.g. `sdd: warning: item 1: not verified (gate verified): …`, exit 0

How: `item_phase`'s ready branch picks the wording with `gate_level verified "$ITYPE"`, `verified` and `verified_by` (existing
helpers; only at review, so `next` mid-build keeps its git-call budget). `.sdd/core/config`: `[profile "lite"] verified = warn`.
D-62.1 Warn, not block, in `lite`: a human reviews, and `Verified by: none` with a reason is honest; `strict` already
blocks, and unattended runs should set it.
D-62.2 Stop-hook and phase logic do not change: an unverified item is still in review, the human's step.

## Must not change
- `standard` warns and `strict` blocks as today; `WHYCODE` stays `ready`; the stop hook stays quiet in review.

## Security
none: an honest message and a warning; no input or dependency.

## Test
`tests/t_verified.sh`, new section in `lite`: no line → `next` says `NOT verified`, and ship warns and ships; `Verified by: none (…)` →
`NOT verified`; a real line → `verified and written up`, no warning; a roadmap → `written up`, no `NOT verified`. Fails now:
always "verified and written up", no warning.

## Built
- FR-62.1, FR-62.2: `item_phase` in `.sdd/core/lib/common.sh` picks the wording from `gate_level`, `verified`, `verified_by`.
  Test: `tests/t_verified.sh` (no line, none, a real line, a roadmap).
- FR-62.3: `.sdd/core/config`: `[profile "lite"] verified = warn`. Same test.
- Deviation: the older FR-22.3 check in that test pinned "lite does not ask", which FR-62.3 changes on purpose, so it now
  expects the warning.
- Check passed under sh and dash. Security: a message and a warning; no new input.

## Review (optional)
<!-- The human's review notes: what to change, one per line. The agent works through them
and says under "## Built" what it changed for each. -->

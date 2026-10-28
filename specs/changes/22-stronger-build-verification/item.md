---
id: 22
type: feature
title: Stronger build verification
status: open
created: 2026-10-28
approved: dfa4699ca34676de9d607f8e7adc86fb1d6fc859 2026-10-28 joexbayer
---
# 22 Stronger build verification

## Why
A cheap builder's word is not proof. In item 17's trial qwen reported "successfully completed"
before verifying, and went past its task. Three gaps, each taken from pstack (kb:
specs/kb/pstack.md): a test-first task counts as red when it fails for any reason, even a typo;
nobody but the builder checks the build against the requirements; and code changed after the
human's review ships without another look.

## What changes
FR-22.1 WHEN a task says `expect: fail "<text>"` THE SYSTEM SHALL, in `task done`, accept the
red run only when its output contains that text (fixed string); plain `expect: fail` keeps
today's rule.
  e.g. `(test: sh test_wf.sh; expect: fail "wordfreq: not found")`, the test fails with "syntax
  error" → "✗ T-1.3 failed, but not for the expected reason (wordfreq: not found)", not ticked
FR-22.2 WHEN the build is verified and the check passes THE SYSTEM SHALL tell the main agent
(finish steps) to hand the item to the `verifier` role (its subagent, or `sdd run verifier`, or
a fresh subagent on another model when no role is set): it checks each FR by running something,
reports only findings with the command and its output, and the result goes under "## Built" as
`Verified by: <model>: <n> of <m> FRs proven; <findings or "no findings">`, or `Verified by: none`.
  e.g. "Verified by: claude-opus-5-5: 4 of 4 FRs proven; no findings"
FR-22.3 WHEN `sdd ship` runs THE SYSTEM SHALL apply a new gate `verified`: a "Verified by:" line
other than "none" under "## Built" (off in lite, warn in standard, block in strict); `sdd review`
shows the line.
  e.g. strict, "Verified by: none" → ship refuses, naming the gate
FR-22.4 WHEN the human runs `sdd review` THE SYSTEM SHALL record the fingerprint of the item's
code change (`git patch-id` of the diff from the merge base, specs/ left out), and `sdd ship`
SHALL apply a new gate `reviewed` when it differs or no record exists in this clone (warn in lite
and standard, block in strict), saying what changed since.
  e.g. review, then an agent edits src/a.js → ship: "code changed since your review (src/a.js):
  run sdd review"; a rebase onto a newer base keeps the same fingerprint → no warning

## Not in scope (optional)
Rules recording what enforces them, "Depends on" checks, the experiment's method (kb:
specs/kb/pstack.md, "later"). Several models racing on one task (cost).

## How
- `task.sh`: `expect` keeps `fail` and takes an optional quoted text; `task_rows` (item 17's
  grammar) carries it; `grep -F` on the red log.
- `prompts/finish.md` (item 21): the verifier step. `prompts/role-verifier.md`: what a verifier
  does (run, prove, report with output; never edit code or the plan).
- `review.sh` writes `.git/sdd/checks/<id>.reviewed` (`patch=<id>`, files); `ship.sh` gates
  `verified` and `reviewed`; `core/config` adds both gates and their levels.
D-22.1 The verifier is a role (item 16), so the project picks its model; the default prompt asks
for another model than the builder's, because a model checking its own work misses its own blind
spots.
D-22.2 The review record is per clone: a teammate's review shows in the PR's review state (item
10), which the forge gate already checks; strict teams get both.
D-22.3 A fixed string, not a regex: test output is full of regex characters, and a plain text is
what a planner writes.
D-22.4 Gate levels (lite/standard/strict): verified off/warn/block, reviewed warn/warn/block, so
lite stays light and strict proves everything.

## Security
- A builder writing its own "Verified by:" line → accept: the line names the model, `sdd usage`
  shows whether a verifier run happened, and the human reads it in review; the gate stops a
  missing step, not a forged one (same as D-21.1).
- The expected text goes to `grep -F` as an argument, never into a shell string.

## Done when
DOD-22.1 `sdd check` passes, with a test naming each FR, under /bin/sh and dash.
DOD-22.2 On a scratch repo, a qwen build verified by an Opus or Sonnet verifier writes a real
"Verified by:" line, and editing code after `sdd review` makes ship warn.

## Tasks (optional)
- [x] T-22.1 Expected failure text, FR-22.1 (files: .sdd/core/lib/common.sh, .sdd/core/cmd/task.sh, .sdd/core/prompts/plan.md, .sdd/core/templates/feature.md, tests/t_expect.sh; test: SH=/bin/sh SRC=$PWD sh tests/t_expect.sh; size: S)
- [ ] T-22.2 Verifier step, role prompt and the verified gate, FR-22.2, FR-22.3 (files: .sdd/core/prompts/finish.md, .sdd/core/prompts/role-verifier.md, .sdd/core/cmd/ship.sh, .sdd/core/cmd/review.sh, .sdd/core/config, tests/t_verified.sh; test: SH=/bin/sh SRC=$PWD sh tests/t_verified.sh; size: M)
- [ ] T-22.3 Review fingerprint and the reviewed gate, FR-22.4 (files: .sdd/core/cmd/review.sh, .sdd/core/cmd/ship.sh, .sdd/core/config, tests/t_reviewed.sh; test: SH=/bin/sh SRC=$PWD sh tests/t_reviewed.sh; size: M)
- [ ] T-22.4 Help, design and README (files: .sdd/core/cmd/help.sh, specs/design.md, README.md; size: S)

## Built
<!-- Written by the agent at the end of the build, for the review: per requirement what
changed (file:line) and which test proves it; deviations from the plan and why; follow-ups. -->

## Review (optional)
<!-- The human's review notes: what to change, one per line. The agent works through them
and says under "## Built" what it changed for each. -->

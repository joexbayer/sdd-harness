---
id: 19
type: feature
title: Plan analysis before approval
status: open
created: 2026-10-28
approved: 3bc502f1407ea689132848cde8178a9d551cec89 2026-10-28 joexbayer
---
# 19 Plan analysis before approval

## Why
A plan is approved after a read by eye, so gaps slip through: a requirement no task builds, a
task serving no requirement, an open question, a requirement with no example. The builder may
be a small model that sees one task at a time, so it cannot notice. Spec Kit has `/analyze`
and `/clarify` for this (research: Spec Kit vs sdd, 2026-10-28); sdd has nothing before review.

## What changes
US-19.1 As the human I see what is missing in a plan before I approve it, so that the builder
gets a complete one.
FR-19.1 WHEN `sdd analyze` runs on an item THE SYSTEM SHALL print one line per problem found in
the plan and exit 1, or say it found none and exit 0. Problems:
  an FR no task names (only when the plan has tasks); a task naming an FR the plan lacks; an FR
  line with no `e.g.` example under it; a Q line with no `→ decided`; an ID written twice; a
  task line the task grammar cannot read.
  e.g. FR-4.3 has no task, Q-4.1 has no decision → "✗ FR-4.3 (export as CSV): no task names it"
  and "✗ Q-4.1 (which date format?): not decided", exit 1
FR-19.2 WHEN the human runs `sdd approve` and the analysis finds problems THE SYSTEM SHALL
apply a new gate `analyzed`: warn in lite (print the problems, approve anyway), block in
standard and strict (print them, approve nothing, exit 1).
  e.g. standard profile, one open question → approve exits 1 naming Q-4.1
FR-19.3 WHEN `sdd next` runs in the plan phase and the plan is filled in THE SYSTEM SHALL add
the analysis problems to its step, so the agent fixes them before asking for approval.
  e.g. "Before asking for approval, fix: ✗ FR-4.3 (export as CSV): no task names it"
FR-19.4 WHEN an agent plans THE SYSTEM SHALL tell it (plan prompt) to check the plan for gaps
before asking for approval: scope edges, errors and edge cases, data and state, speed,
several developers at once, security; and to ask the human about each gap it finds.
  e.g. the plan step lists those six checks

## Not in scope (optional)
- Checking with a model that the plan makes sense: that stays with the human and the planner.
- More agent adapters (opencode, Cursor, Gemini): a later item when the experiment needs one.
- Unknown task attributes: item 17 (task batches) makes the task grammar refuse them; FR-19.1
  then reports them through the same "cannot read" check.

## How
`plan_findings` in common.sh: one awk pass over `plan_part` (comments and fences left out)
plus `task_rows`; prints `<id>\t<name>\t<problem>`. `cmd/analyze.sh` prints it; `approve.sh`
and the plan step of `next` call the same function. No new files under `.git/`.
D-19.1 Mechanical checks only, because they are fast, exact and the same for every agent; a
model's judgement of the plan is the planner's and the human's job.
D-19.2 A gate of its own rather than part of `planned`, because teams may want empty sections
to block but analysis only to warn, or the other way round.
D-19.3 Applied at approve, not at ship: an approved plan cannot change without re-approval,
so checking again at ship finds nothing new.

## Security
none: reads the item file only; no new input, dependency, command or network use.

## Questions (optional)
Q-19.1 Should the gate block in standard and strict, or only warn everywhere? → recommend:
block in standard and strict, warn in lite (this repo is lite, so it warns here). → decided: as recommended (joexbayer, 2026-10-28)

## Done when
DOD-19.1 `sdd analyze` on items 16, 17 and 18 in this repo gives a correct list (checked by hand).

## Tasks (optional)
- [ ] T-19.1 `plan_findings` and `sdd analyze`, FR-19.1 (files: .sdd/core/lib/common.sh, .sdd/core/cmd/analyze.sh, .sdd/core/cmd/help.sh, tests/t_analyze.sh; test: SH=/bin/sh SRC=$PWD sh tests/t_analyze.sh; expect: fail)
- [ ] T-19.2 Gate `analyzed` at approve, FR-19.2 (files: .sdd/core/config, .sdd/core/cmd/approve.sh, tests/t_analyze.sh; test: SH=/bin/sh SRC=$PWD sh tests/t_analyze.sh)
- [ ] T-19.3 Findings in the plan step of next, gap checklist in the plan prompt, FR-19.3, FR-19.4 (files: .sdd/core/cmd/next.sh, .sdd/core/prompts/plan.md, tests/t_analyze.sh; test: SH=/bin/sh SRC=$PWD sh tests/t_analyze.sh)

## Built
<!-- Written by the agent at the end of the build, for the review: per requirement what
changed (file:line) and which test proves it; deviations from the plan and why; follow-ups. -->

## Review (optional)
<!-- The human's review notes: what to change, one per line. The agent works through them
and says under "## Built" what it changed for each. -->

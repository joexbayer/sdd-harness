---
id: 58
type: fix
title: Planner-written tests cannot be bent by the builder
status: open
created: 2026-11-01
approved: 55425aaccc2dbb059c53dd96970f4ce860ea91ad 2026-11-01 joexbayer
---
# 58 Planner-written tests cannot be bent by the builder

## Current behaviour
A `by: planner` task's test is the contract the builder must meet (FR-36.1), but nothing stops the
builder from editing it later. In the experiment (2026-10-30, arm A) the builder bent its tests to
match wrong code. memdoor's team-solve keeps the scoring tests away from the solver (user asked to
adapt, 2026-11-01).

## Expected behaviour
FR-58.1 WHEN a done `by: planner` task's `files:` changed after the commit that names it (later
commits or the working tree) and "## Built" does not name that file THE SYSTEM SHALL refuse ship:
`item <id>: <task>'s test <file> (written by the planner) changed after it was written: undo it, or say why under "## Built" naming the file`
  e.g. T-1.1 (by: planner; files: t1.sh) ticked in commit A; a later commit edits t1.sh → ship
  refuses with that line naming T-1.1 and t1.sh
FR-58.2 WHEN "## Built" names the changed file THE SYSTEM SHALL ship as usual.
  e.g. Built says "t1.sh: the planner's sample used the wrong date format" → ship goes on
FR-58.3 WHEN `sdd review` runs and FR-58.1 would refuse THE SYSTEM SHALL print the same line, so the
human sees it before ship.
  e.g. review shows "⚠ item 1: T-1.1's test t1.sh (written by the planner) changed …"

How: `.sdd/core/lib/common.sh`: `bent_tests` prints one line per changed planner file:
for each done row with `by` = planner, `git diff --name-only <task_commit> -- <files>` plus the
working tree; skip a file whose path appears in the Built section. `ship.sh` fails with the
lines; `review.sh` prints them with ⚠. Builder-written tests are not covered (D-58.1).
D-58.1 Only `by: planner` tests: a builder's own test-first tests are its to change; protecting them
needs a second author, which the planner tests already are.

## Must not change
- Tasks without `by: planner`, and planner tasks whose files nobody touched, ship as today.
- Ship's other task gates (ticked without a commit, ticked by hand).

## Security
none: a stricter local gate; no input or dependency.

## Test
`tests/t_task.sh`, a new section: a `by: planner` task done and committed; edit its file and commit
→ review shows the FR-58.3 line and ship refuses with the FR-58.1 line; add the file to Built →
ship passes the check (FR-58.2). An untouched planner task and a builder task edited later ship
(must not change). Fails now: ship ships.

## Built
<!-- Written by the agent at the end of the build, for the review: per requirement what
changed (file:line) and which test proves it; deviations from the plan and why; follow-ups. -->

## Review (optional)
<!-- The human's review notes: what to change, one per line. The agent works through them
and says under "## Built" what it changed for each. -->

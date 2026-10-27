---
id: 15
type: feature
title: Tasks: small steps a coder model builds one at a time
status: open
created: 2026-10-27
approved: f2369c5440c48e7ad12b26fe9a68ff20bb272b35 2026-10-27 joexbayer
---
# 15 Tasks: small steps a coder model builds one at a time

## Why
The experiment (Opus plans, a small coder model builds) needs plans that end in small,
checkable steps: small models obey gates and drift on big steps (kb/narrow-lessons.md). Today a
task is only a counted checkbox: nothing hands the builder one task, checks it, or keeps the box
honest, and ticking a box would change the plan and void its approval.

## What changes
US-15.1 As a planner I end the plan in small tasks, so that a builder (often a small model)
does one checked step at a time and anyone reading the item sees how far it is.
FR-15.1 WHEN a plan lists `- [ ] T-<id>.<n> <what> (files: …; test: <command>; expect: fail)`
THE SYSTEM SHALL read each task's files, test command and expectation (`expect: fail` optional),
and the FRs its text names.
  e.g. `- [ ] T-4.2 Page the orders query, FR-4.1 (files: src/orders.js; test: npm test -- orders)`
FR-15.2 WHEN `sdd task done T-<id>.<n>` runs THE SYSTEM SHALL run that task's test from the
repo root (all check commands when it names none), and when it passes (exit 0; with
`expect: fail`, a non-zero exit) tick the task's box and print the commit message to use;
otherwise leave it unticked, show the log, and exit 1.
  e.g. `✓ T-4.2 done (its test passed) · commit with: feat(4): T-4.2 page the orders query`
FR-15.3 WHEN the plan is not approved or changed since, or the task is unknown or already ticked
THE SYSTEM SHALL refuse `task done` before running anything (exit 1).
FR-15.4 WHEN approval is pinned or checked THE SYSTEM SHALL ignore whether boxes are ticked, so
ticking never voids an approval; any other plan edit still does.
FR-15.5 WHEN an item in build has open tasks THE SYSTEM SHALL give the first open one as the
phase reason, and `next` SHALL show it first: its line, files, test, the FRs it names with their
examples, and the steps (only this task, then `task done`, then a commit naming it).
  e.g. `Phase: build (task T-4.2 of 5: Page the orders query)`
FR-15.6 WHEN `sdd task` runs THE SYSTEM SHALL list the item's tasks with their box and whether
a commit on the branch names each.
FR-15.7 WHEN `ship` runs THE SYSTEM SHALL refuse a ticked task that no commit on the branch names
(every profile), and apply a `tasks` gate to features: at least one task, all ticked (lite
warns, standard and strict block).
FR-15.8 WHEN a feature is planned THE SYSTEM SHALL have the template and plan prompt ask for
small, ordered tasks, each naming files, a test and the FRs it serves, with `expect: fail` for a
test written first.

## Not in scope (optional)
Parallel markers and task dependencies ([P] in Spec Kit), `sdd run` (model roles, next item).

## How
```
 plan: - [ ] T-15.n … (files; test; expect)  ──parse_item──▶ task rows (files, test, expect, FRs)
 build: next ─▶ first open task + its FRs      task done ─▶ run test ─▶ tick box (no commit)
 agent commits "feat(15): T-15.n …"            ship ─▶ ticked ⇒ named by a commit; tasks gate
 plan_hash: boxes normalised to [ ] first, so a tick is not a plan change
```
- `lib/common.sh`: `parse_item` task attributes, `task_rows`, `plan_hash` normalising boxes,
  `item_phase` reason `task`; new `cmd/task.sh`; `cmd/next.sh` current-task block; `cmd/ship.sh`
  tasks gate and drift check; `core/config` gate `tasks` (feature) per profile;
  `templates/feature.md` `## Tasks (optional)`; `prompts/plan.md` task guidance.
- Teammates see progress on remote branches through committed ticks, as `ls` reads them today.
- Also: design §7 (task grammar), §8 (`task`), §16 (the agreed roadmap order).
D-15.1 Ticks are written by sdd, proven by git: a box only changes in `task done` after its test
passes, and ship refuses a tick no commit names (C-2: the file shows facts, git proves them).
D-15.2 `task done` does not commit (C-4); the agent commits code and tick together.
D-15.3 A task's test runs only for an approved, unchanged plan, so a command edited in after
approval never runs.

## Security
`task done` runs a shell command written in the item. Risk: a command changed after approval
(an injected or careless edit) runs on the developer's machine → FR-15.3 runs it only for an
approved, unchanged plan (D-15.3); the command is otherwise trusted like check commands. No new
dependency, input, secret or network.

## Questions (optional)
Q-15.1 How does sdd know a task is done? → recommend: derived from git; revised with the human
to checkboxes sdd ticks after the task's test passes, proven by commits at ship. → decided:
sdd ticks them (joexbayer, 2026-10-27)
Q-15.2 What does `task done` run? → recommend: the task's own test command. → decided: the
task's own test (joexbayer, 2026-10-27)
Q-15.3 What does `next` give the builder? → recommend: the current task first, with its FRs.
→ decided: the current task first (joexbayer, 2026-10-27)
Q-15.4 Test first? → recommend: an optional red task (`expect: fail`). → decided: optional red
task (joexbayer, 2026-10-27)
Q-15.5 When are tasks required? → recommend: standard and strict, features. → decided:
standard+ for features (joexbayer, 2026-10-27)

## Done when
DOD-15.1 `sdd check` passes, with a test naming each FR, under /bin/sh and dash.
DOD-15.2 This item's own remaining tasks are ticked through `sdd task done`, and ship verifies
each against its commit.

## Tasks (optional)
- [ ] T-15.1 Parse task attributes and FRs; normalise boxes in plan_hash, FR-15.1, FR-15.4 (files: .sdd/core/lib/common.sh, tests/t_task.sh; test: SH=/bin/sh SRC=$PWD sh tests/t_task.sh)
- [ ] T-15.2 `sdd task` and `sdd task done`, FR-15.2, FR-15.3, FR-15.6 (files: .sdd/core/cmd/task.sh, tests/t_task.sh; test: SH=/bin/sh SRC=$PWD sh tests/t_task.sh)
- [ ] T-15.3 Current task in the phase and `next`, FR-15.5 (files: .sdd/core/lib/common.sh, .sdd/core/cmd/next.sh; test: SH=/bin/sh SRC=$PWD sh tests/t_task.sh)
- [ ] T-15.4 Ship drift check and the tasks gate, FR-15.7 (files: .sdd/core/cmd/ship.sh, .sdd/core/config; test: SH=/bin/sh SRC=$PWD sh tests/t_task.sh)
- [ ] T-15.5 Template, plan prompt, help and design, FR-15.8 (files: .sdd/core/templates/feature.md, .sdd/core/prompts/plan.md, specs/design.md)

## Built
<!-- Written by the agent at the end of the build, for the review: per requirement what
changed (file:line) and which test proves it; deviations from the plan and why; follow-ups. -->

## Review (optional)
<!-- The human's review notes: what to change, one per line. The agent works through them
and says under "## Built" what it changed for each. -->

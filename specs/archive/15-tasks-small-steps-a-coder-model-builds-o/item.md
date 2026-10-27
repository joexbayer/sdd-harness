---
id: 15
type: feature
title: Tasks: small steps a coder model builds one at a time
status: shipped
created: 2026-10-27
approved: f2369c5440c48e7ad12b26fe9a68ff20bb272b35 2026-10-27 joexbayer
shipped: 2026-10-27
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
- [x] T-15.1 Parse task attributes and FRs; normalise boxes in plan_hash, FR-15.1, FR-15.4 (files: .sdd/core/lib/common.sh, tests/t_task.sh; test: SH=/bin/sh SRC=$PWD sh tests/t_task.sh)
- [x] T-15.2 `sdd task` and `sdd task done`, FR-15.2, FR-15.3, FR-15.6 (files: .sdd/core/cmd/task.sh, tests/t_task.sh; test: SH=/bin/sh SRC=$PWD sh tests/t_task.sh)
- [x] T-15.3 Current task in the phase and `next`, FR-15.5 (files: .sdd/core/lib/common.sh, .sdd/core/cmd/next.sh; test: SH=/bin/sh SRC=$PWD sh tests/t_task.sh)
- [x] T-15.4 Ship drift check and the tasks gate, FR-15.7 (files: .sdd/core/cmd/ship.sh, .sdd/core/config; test: SH=/bin/sh SRC=$PWD sh tests/t_task.sh)
- [x] T-15.5 Template, plan prompt, help and design, FR-15.8 (files: .sdd/core/templates/feature.md, .sdd/core/prompts/plan.md, specs/design.md)

## Built
- FR-15.1 (task attributes): `task_rows` (`.sdd/core/lib/common.sh:395`) reads each task's
  files, test, `expect` and the FRs it names from a final `(files: …; test: …; expect: fail)`;
  a value runs to the next `; <key>:`, so a test may contain `;` and parentheses. Test:
  tests/t_task.sh (`sdd task` output).
- FR-15.2, FR-15.3 (`task done`): `.sdd/core/cmd/task.sh`. It refuses before running anything
  unless the plan is approved and unchanged (`task.sh:34`), runs the task's test from the repo
  root (the check when it names none), treats exit 126/127 as "could not run" even with
  `expect: fail`, ticks the box and prints the commit message. Test: t_task.sh (unapproved,
  unknown, already ticked, a red task that passes, a failing test, no test → check).
- FR-15.4 (ticks do not void approval): `plan_hash` (`common.sh:182`) counts every box as
  unticked. Test: t_task.sh. Approved items keep their hash (their boxes were unticked).
- FR-15.5 (the current task): `item_phase` gives reason code `task` with "task T of N: …"
  (`common.sh:374`); `next.sh:28` prints the task, its files, test, expectation and the FRs it
  serves with their examples, then the steps. `summary` shows it as "building: task …". Test:
  t_task.sh.
- FR-15.6 (`sdd task`): lists boxes, test, FRs and the commit naming each (`task_commit`,
  `common.sh:425`: whole IDs in the subject, so T-4.1 is not T-4.10). Test: t_task.sh.
- FR-15.7 (ship): `ship.sh:194` refuses ticked tasks no commit names (every profile) and applies
  the `tasks` gate (`core/config`: feature only; lite warn, standard and strict block). Test:
  t_task.sh (refused in lite, blocked in standard until the last task is ticked, then shipped).
- FR-15.8: `templates/feature.md` `## Tasks (optional)` with the line format; `prompts/plan.md`
  asks for small, ordered tasks with a test of their own. Test: t_task.sh.
- Also: help, design §7 (task grammar), §8 (`task`), §16 (the agreed roadmap order: 12, 15,
  then model roles + usage, multi-item plans, contracts, the experiment; team mode later).
- Dogfooding (DOD-15.2): this item's five tasks were ticked with `sdd task done`, each tick
  committed naming its task; `sdd task` shows a commit for every one.

Deviations:
- All five of this item's tasks share one test file (my planning mistake), so none could pass
  `task done` before the whole feature worked: they were built in order, each committed under its
  ID, and ticked at the end. The plan prompt and template now ask for a test of each task's own.
- tests/t_query.sh hand-ticks a task: its commit now names that task, because ship refuses an
  unproven tick (FR-15.7). No assertion was dropped.
- Found while dogfooding: `sdd task` printed a commit hash twice; fixed and tested.

Fresh-context review (no blockers, 7 warnings, 6 nits; security pass: no injection) and what
changed:
- Fixed: a box ticked by hand, with any commit naming the task, used to ship (D-15.1 was not
  enforced). `task done` now notes each tick in this clone (`.git/sdd/checks/<id>.tasks`), and
  ship refuses a tick whose naming commit is yours but has no note; a teammate's tick (their
  commit) needs only the commit. This repo's own five ticks were redone through `task done`.
- Fixed: a red task passed when its test could not run: its `files:` must exist, and a red test
  whose log shows the check's no-tests patterns is refused. (Matching "No such file" was tried
  and dropped: a red test legitimately fails on code that does not exist yet.)
- Fixed: attributes that do not end the task line (a wrapped line, words after them) made sdd run
  the full check instead of the task's test; `task done` now refuses such a line and `sdd task`
  flags it. The tick only touches the task's own line in the plan part, outside code fences, by
  whole ID, and fails loudly if it finds none.
- Fixed: `[type "feature"] gates` overrode a project's own `sdd.gates`; `tasks` is now in the
  default gate list and `tasks = off` for fix, refactor and amendment.
- Fixed nits: a test that hides failures (`|| true`) is refused as in check; task text prints with
  printf; task IDs must look like `T-<id>.<n>`; "serves" reads FRs from the description, not the
  test command. Tests: t_task.sh (a second item with each case).
- Accepted: types without an approval step (hotfix, chore) run a task's test unapproved, the same
  trust as check commands (noted in task.sh). `item_phase` parses the item twice per row (fine at
  tens of items).

Upgrading (for items already open when this lands):
- In standard and strict, an open feature without tasks is blocked at ship; adding tasks
  changes its plan, so the human approves again.
- A box ticked before this version needs `task done` (untick, then run it) and a commit naming
  the task before ship.

## Review (optional)
<!-- The human's review notes: what to change, one per line. The agent works through them
and says under "## Built" what it changed for each. -->

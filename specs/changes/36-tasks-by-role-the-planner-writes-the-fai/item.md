---
id: 36
type: feature
title: Tasks by role: the planner writes the failing tests
status: open
created: 2026-10-29
approved: 90b11d177add7ef89eb0a99b6308b4b9a73c2714 2026-10-29 joexbayer
---
# 36 Tasks by role: the planner writes the failing tests

## Why
<!-- The problem in plain words: who hurts, and how. 2-4 lines. -->
Small builders write hollow tests (narrow spot runs 1-2: 7/12 and 8/12), but make a big model's
red tests pass (run 3, Opus wrote the red tests: 10/12). Pilot arm A: qwen's failures were all
protocol (it wrote Built into the plan, ticked with narrow's own task tool, prefixed `cd`), never
code. So: the planner writes the tests that define done, and the builder gets a narrow job.

## What changes
<!-- User-visible behaviour. One requirement per entry, each with a concrete example:
    US-36.1 As a <role> I <action>, so that <outcome>.
    FR-36.1 WHEN <trigger> THE SYSTEM SHALL <response>.
      e.g. <input> → <output>
Start each entry at the beginning of its line, ID first. IDs never change; leave gaps. -->
FR-36.1 WHEN a task line has `by: <role>` THE SYSTEM SHALL read it as the role that builds it
(default builder), refuse a role that is not a lowercase word, and show it in `next` and
`task next` after size.
  e.g. `- [ ] T-7.1 Login test (files: tests/test_login.py; test: pytest -q tests/test_login.py; expect: fail; size: S; by: planner)` → task next: `[ ] T-7.1 Login test (size: S; by: planner)`
  e.g. `by: Planner!` → "T-7.1: by: must be a role name (a lowercase word)"
FR-36.2 WHEN the batch is computed THE SYSTEM SHALL keep tasks of different roles in different
batches, so a batch belongs to one role.
  e.g. T-7.1 (S, by: planner), T-7.2 (S), T-7.3 (S) → batches [T-7.1], [T-7.2 T-7.3]
FR-36.3 WHEN `sdd run <role> <id>` runs in build and the current batch belongs to another role
THE SYSTEM SHALL refuse and name the role whose turn it is.
  e.g. batch by planner, `sdd run builder 7` → "T-7.1 is the planner's: sdd run planner 7", exit 2
FR-36.4 WHEN `sdd run <role>` ends for the batch's own role THE SYSTEM SHALL restore the item file
and tick the batch (FR-34.1, FR-31.1) for that role as for the builder today.
  e.g. `sdd run planner 7` on [T-7.1] → item file restored, "✓ T-7.1 done (its test fails, as expected)", "ticked 1 of 1"
FR-36.5 WHEN a role run works a batch THE SYSTEM SHALL add a role prompt that says its job: write
only the code and tests of these tasks; sdd ticks them and the orchestrator commits; never edit
the item file, never run task done, never commit; run the commands without `cd`.
  e.g. prompt of `sdd run builder 7` contains "sdd ticks these tasks for you"
FR-36.6 WHEN `next` gives plan rules THE SYSTEM SHALL say that a test-first task can be `by: planner`,
so the planner writes the test that defines done from the FR's example, and the builder makes it pass.
  e.g. plan rules contain "by: planner"

## Not in scope (optional)
<!-- What this deliberately leaves out, and where it went. -->
Role names beyond the project's [role] config are not validated against it (a run of an unset role
fails as today). The experiment's arm C and its narrow `cd` allowance: a chore after this ships.

## How
<!-- What a reviewer needs: an ASCII sketch of the moving parts, key types or signatures,
and the decisions they would question, each at the start of its line:
    D-36.1 <decision>, because <reason>. -->
D-36.1 `by:` is a task attribute like size and expect (AWK_TASK), field 11 of task_rows; task_batch
breaks a batch where the role changes; run.sh compares the batch's role with the run's.
D-36.2 Ticking and the item-file restore apply to the role that owns the batch (generalising
FR-31.1 and FR-34.1 from "builder" to "the batch's role"). A role run outside build (verifier,
finisher) is unchanged.
D-36.3 The role prompt is prompts/role-batch.md, added after next's output for any batch run; a
project's prompts/role-<role>.md still follows it.
D-36.4 narrow parses `task next`'s first line: `(size: S)` becomes `(size: S; by: planner)` only when
by is set, so lines without it are unchanged (narrow is told before this ships).

## Security
<!-- Does this touch untrusted input, login or permissions, secrets or personal data, a new
dependency, files/network/shell, or CI/agent config? If not: "none: <why>". Otherwise, per risk:
what can go wrong → what we do (an FR with a test, a D line, or "accept: <why>").
    e.g. uploads are untrusted → FR-36.4 rejects non-images and files over 5 MB -->
Role names come from the approved plan and are checked as lowercase words before use; they
select config ([role "<name>"]) as `sdd run` already does. No new input.

## Questions (optional)
<!-- Q-36.1 <question> → recommend: <answer>. Resolve before building. -->

## Done when
<!-- DOD-36.1 <observable outcome>, e.g. "works against staging". -->
DOD-36.1 `sdd check` passes; t_task.sh, t_batch.sh and t_run.sh prove FR-36.1 to FR-36.6 with fake agents.

## Tasks (optional)
<!-- Small, ordered steps the builder does one at a time, each in one sitting, each with a test
of its own (so it can pass before the next task exists):
    - [ ] T-36.1 Page the orders query, FR-36.1 (files: src/orders.js; test: npm test -- orders; size: S)
Size each task `S`, `M` or `L` (none is M): consecutive S tasks go to one builder together, M and
L ones alone. Add `; expect: fail` for a test written first (it must fail), or
`; expect: fail "<text>"` (it must fail with that text in its output); without `test:` the
full check runs. `.sdd/bin/sdd task done T-36.1` ticks a task when its test passes. -->
- [x] T-36.1 by: attribute, its check and display, FR-36.1 (files: .sdd/core/lib/common.sh, .sdd/core/cmd/task.sh, .sdd/core/cmd/next.sh, tests/t_task.sh; test: SRC=$PWD SH=dash dash tests/t_task.sh; size: M)
- [x] T-36.2 Batches by role, FR-36.2 (files: .sdd/core/lib/common.sh, tests/t_batch.sh; test: SRC=$PWD SH=dash dash tests/t_batch.sh; size: S)
- [x] T-36.3 Runs by role: refuse, restore, tick; the role prompt, FR-36.3, FR-36.4, FR-36.5 (files: .sdd/core/cmd/run.sh, .sdd/core/prompts/role-batch.md, tests/t_run.sh; test: SRC=$PWD SH=dash dash tests/t_run.sh; size: M)
- [x] T-36.4 Plan rule, README, design, sdd-dev notes, FR-36.6 (files: .sdd/core/prompts/plan.md, README.md, specs/design.md, .claude/skills/sdd-dev/SKILL.md, tests/t_prompts_tests.sh; test: SRC=$PWD SH=dash dash tests/t_prompts_tests.sh; size: S)

## Built
<!-- Written by the agent at the end of the build, for the review: per requirement what
changed (file:line) and which test proves it; deviations from the plan and why; follow-ups. -->
- FR-36.1: `by:` is a known task attribute in AWK_TASK (.sdd/core/lib/common.sh:819), checked as a
  lowercase word (common.sh:823, "by: must be a role name (a lowercase word)"), field 11 of
  task_rows (common.sh:830). `task next` prints `(size: S; by: planner)` only when set
  (.sdd/core/cmd/task.sh:39; without by: the line is byte-identical); `next` prints
  `  by      planner (.sdd/bin/sdd run planner 7)` under the task (.sdd/core/cmd/next.sh:98).
  Test: tests/t_task.sh (FR-36.1 block at the end); t_analyze's expected "known: …" list now
  includes by.
- FR-36.2: task_batch ends a batch where the role changes; no by: and `by: builder` are the same
  role (common.sh:844). Test: tests/t_batch.sh (FR-36.2 block: planner / builder+builder / writer).
- FR-36.3: run.sh reads the batch's role (first task's field 11, builder when empty) and refuses
  another role with usage_die "T-x.y is the <role>'s: sdd run <role> <id>", exit 2, before a run
  slot is taken, so nothing is logged (.sdd/core/cmd/run.sh:49-55). Test: tests/t_run.sh (FR-36.3,
  both directions: builder on the planner's batch, planner on the builder's).
- FR-36.4: the item-file restore and the ticking now apply to any batch run (run.sh:81, :107),
  which after FR-36.3 means the run's role owns the batch; the warning names the role. Test:
  tests/t_run.sh (FR-36.4: planner run scribbles in the item file → "⚠ the planner edited …:
  restored", "✓ T-1.2 done", "ticked 1 of 1"). FR-28.1 and FR-33.1 tests unchanged and passing.
- FR-36.5: .sdd/core/prompts/role-batch.md, appended after next's output for any batch run, before
  a project's role-<role>.md (run.sh:61). Test: tests/t_run.sh (builder and planner prompts contain
  "sdd ticks these tasks for you" / "never commit"; a run with no batch does not get it).
- FR-36.6: plan rule in .sdd/core/prompts/plan.md:37. Test: tests/t_prompts_tests.sh.
- Docs: README.md (Now let's build), specs/design.md (task grammar row, build loop paragraph),
  .claude/skills/sdd-dev/SKILL.md (field 11; role-owned batches in run.sh).

Deviations and notes:
- `next` has no size to show it after, so it gets its own `by` line under the task, with the
  command to run (the plan said "after size" for both).
- Existing t_run.sh tests changed shape (not weakened): item 1 got a planner task T-1.2, and the
  planner-on-claude tests that ran mid-build now run either on the planner's batch or once no task
  is open, because FR-36.3 refuses a role run on another role's batch. Consequence: a verifier (or
  any non-owning role) can no longer run while a task is open; it runs once none is (as the build
  loop already does).
- Unlikely edge, not handled: an unreadable `by:` (e.g. `Planner!`) still lands in field 11, so
  `next`/run.sh name it in their message. Failure mode: a refusal message quoting the bad name
  (never executed; the task itself cannot be ticked). Likelihood: only with a plan analyze already
  flags. Cost to filter: one more condition; skipped.
- Security pass: the role name only reaches echo/usage_die text and the existing `role.<name>.tier`
  config lookup (run.sh already restricts the run's role to [a-z0-9-]); nothing is evaled or used
  as a path except prompts/role-<role>.md, as before.

Verified by: none (builder self-checked; the orchestrator verifies)

## Review (optional)
<!-- The human's review notes: what to change, one per line. The agent works through them
and says under "## Built" what it changed for each. -->

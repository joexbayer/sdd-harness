---
id: 65
type: fix
title: Show what a task's test proved, and fix the audit skill's steps
status: open
created: 2026-11-08
approved: 7d3b1a8a9359c1679fe0a25633a6ff16957a8a7e 2026-11-08 joexbayer
---
# 65 Show what a task's test proved, and fix the audit skill's steps

## Current behaviour
From two real runs (Lith adoption; the first `/sdd-audit-states` on NarrowBot):
1. `task done` ticks a passing test without showing its output: Lith's printed `goldens 0`, exit 0, and two tasks counted.
2. `expect: fail` with no text accepts any failure: one task went red only because the checkout had no compiler.
3. A test command that turns out wrong: the builder renamed a test to fit it, because changing it voids approval.
4. `build.md` opens with "The human approved the plan", also for chores and hotfixes, which have no approval step (by design).
5. The audit skill: `sdd next` after `new chore` prints plan steps that contradict it; no `sdd check` step; "scripts in a temp folder" fails where tests must sit in the package (Go); a subagent's count is trusted (it said 0 of 3000 for a race the parent's re-runs hit 6, 1, 0, 1).

## Expected behaviour
FR-65.1 WHEN a task's test passes THE SYSTEM SHALL print the last line of its output.
  e.g. `  last line: goldens 0` under the ✓ line
FR-65.2 WHEN an `expect: fail` test goes red with no expected text THE SYSTEM SHALL print its last line and say no reason is pinned, without blocking.
  e.g. `  red for: sh: cc: not found (no expected text: check this is the bug)`
FR-65.3 WHEN the planner writes an `expect: fail` task THE SYSTEM SHALL tell it to give the text when it knows the failure.
  e.g. plan.md: `expect: fail "goldens 0"`
FR-65.4 WHEN a task's test command proves wrong during build THE SYSTEM SHALL tell the builder to stop and ask for re-approval, never bend the test to fit.
  e.g. build.md says so
FR-65.5 WHEN the item has no approval step THE SYSTEM SHALL NOT say the human approved its plan.
  e.g. build.md: "The plan is settled and the human is not watching."
FR-65.6 WHEN `/sdd-audit-states` runs THE SYSTEM SHALL say: the skill replaces the plan steps `sdd next` prints; run `sdd check` before Built; where tests must sit in the package, work in a `git archive` copy in the temp folder; the parent re-runs each reproduction itself, repeatedly for a race.
  e.g. the skill's steps 1 to 3

How: `task.sh`: `tail -n 1` of the log on the two paths (a helper that skips blank lines). Text: `plan.md`, `build.md`, `skills/audit-states.md`.
D-65.1 Show, not detect: sdd can't know a test proved nothing; the configured `no-tests` patterns already cover what a project can name. Warn only on a missing reason: a reason is not always known.
D-65.2 The task's command stays pinned: the pin is what stopped agents at the right place in both runs.

## Must not change
- `task done` outcomes and exit codes; the `✓ T-n done (…)` line; `expect: fail "<text>"` still enforced.

## Security
none: prints a line of the test's own output, which it already shows on failure.

## Test
`tests/t_task.sh` (FR-65.1, 65.2), `tests/t_prompts_tests.sh` (FR-65.3 to 65.5), `tests/t_agents.sh` (FR-65.6). Written first, seen to fail.

## Built
<!-- Written by the agent at the end of the build, for the review: per requirement what
changed (file:line) and which test proves it; deviations from the plan and why; follow-ups. -->
FR-65.1: `.sdd/core/cmd/task.sh` prints `  last line: <x>` after the ✓ line on a pass (helper `last_line` skips blank lines). Test: `tests/t_task.sh`.
FR-65.2: same file, `  red for: <x> (no expected text: check this is the bug)` when `expect: fail` has no text; not blocking. Test: `tests/t_task.sh`.
FR-65.3: `.sdd/core/prompts/plan.md` tells the planner to give the text when known, e.g. `expect: fail "goldens 0"`. Test: `tests/t_prompts_tests.sh`.
FR-65.4: `.sdd/core/prompts/build.md` says stop and ask for re-approval when a test command proves wrong. Test: `tests/t_prompts_tests.sh`.
FR-65.5: `build.md` now opens "The plan is settled and the human is not watching." for all types. Test: `tests/t_prompts_tests.sh`.
FR-65.6: `.sdd/core/agents/skills/audit-states.md`: replaces plan steps, `git archive` copy, `check` before Built, parent re-runs repeatedly for a race. Test: `tests/t_agents.sh`.

Deviations: the plan word ceiling in `tests/t_prompts_tests.sh` raised 800 to 820 (plan.md grew by the FR-65.3 text). Wording in build.md is the same for all types (simplest; no per-type branch).


## Review (optional)
<!-- The human's review notes: what to change, one per line. The agent works through them
and says under "## Built" what it changed for each. -->

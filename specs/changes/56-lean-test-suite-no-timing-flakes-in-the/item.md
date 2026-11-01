---
id: 56
type: refactor
title: Lean test suite: no timing flakes in the gate, less duplicate work
status: open
created: 2026-11-01
approved: d27e14379becaf74f49e2262b6affe801f564f75 2026-11-01 joexbayer
---
# 56 Lean test suite: no timing flakes in the gate, less duplicate work

## Goal
The gate (`sdd check` here) is slow and sometimes red for no reason (2026-11-01: 130-290 s on a
busy machine; t_perf failed at 0.20 s against a 0.2 s budget; t_run failed once with exit 2).
- t_perf (timing) leaves the gate: `tests/run.sh` skips `t_perf*.sh` unless `SDD_PERF=1`; AGENTS.md
  and the sdd-dev skill name it as a test the check leaves out, run at finish and by the verifier.
- t_check_budget.sh keeps its `sleep 2` for one check only, not three.
- t_discipline.sh is folded into t_prompts_tests.sh (its 3 phrases not already there join the
  phrase list) and deleted.
- The t_run.sh flake: find the cause under load (run it 20 at once); fix it if found, else record.
D-56.1 No new gate tier (fast vs full): `task done` already runs only a task's own test; the full
check runs at finish and for tasks without a test.
D-56.2 Overlapping files (t_usage*, t_reviewed/t_verified, t_roadmap/t_depends) stay: merging
saves little and churns history.

## Invariants
- Every FR test that ran before still runs (t_perf through `SDD_PERF=1 sh tests/run.sh`).
- `sdd check` passes under sh and dash.

## Built
- `tests/run.sh`: `t_perf*.sh` runs and counts only with `SDD_PERF=1` (job loop and results loop).
  Checked: without it 35 tests, with it 36 and t_perf passes.
- `tests/t_check_budget.sh`: the `sleep 2` stays for the warning and budget-0 cases, then is dropped
  (two slow checks, not three). Verifier finding fixed: dropping it before budget 0 left FR-35.2's
  "off" half unproven; now removing the `budget -gt 0` guard fails the test (checked).
- `tests/t_discipline.sh` deleted; its phrases (FR-20.1, 20.3, 20.5) joined the phrase lists in
  `tests/t_prompts_tests.sh`.
- t_run flake: 40 parallel runs (20 dash, 20 bash) passed, so not reproduced. The exit-2 paths in
  `sdd run` are usage errors (e.g. "item waiting for the human"); the assertion now prints what sdd
  said, so the next one shows its cause.
- AGENTS.md and `.claude/skills/sdd-dev/SKILL.md` name `SDD_PERF=1 sh tests/run.sh /bin/sh` as the
  test the check leaves out.
- Check passed under sh and dash. Security: test files only.
Verified by: claude-sonnet-5-5: 3 of 4 invariants proven; FR-35.2 budget-0 case lost its slow check (fixed)

## Review (optional)
<!-- The human's review notes: what to change, one per line. The agent works through them
and says under "## Built" what it changed for each. -->

---
id: 56
type: refactor
title: Lean test suite: no timing flakes in the gate, less duplicate work
status: open
created: 2026-11-01
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
<!-- Written by the agent at the end of the build, for the review: per requirement what
changed (file:line) and which test proves it; deviations from the plan and why; follow-ups. -->

## Review (optional)
<!-- The human's review notes: what to change, one per line. The agent works through them
and says under "## Built" what it changed for each. -->

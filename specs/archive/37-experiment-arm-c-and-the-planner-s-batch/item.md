---
id: 37
type: chore
title: Experiment: arm C and the planner's batches
status: shipped
created: 2026-10-29
approved: b8972f2a8ee45630b14189870ae8b380e6c9b044 2026-10-29 joexbayer
shipped: 2026-10-29
---
# 37 Experiment: arm C and the planner's batches

## What and why
<!-- 1-3 lines: what changes (dependencies, config, CI, ...) and why now. No behaviour change. -->
Prepare the second pilot after items 34-36. experiment/ only.
- Arm C: like A (qwen builds through narrow), but the planner marks every test-first task
  `by: planner`, so Opus writes the failing tests (item 36). Arms A and B: the planner prompt says
  not to use `by:`, so they stay as before. `sh experiment/run.sh C` works like A and B.
- The driver works batches by role: when the current batch belongs to the planner it runs
  `sdd run planner <id>` (Opus tier), else `sdd run builder <id>`; per-task caps and commits as now.
  `sdd run` now ticks and restores the item file for the batch's own role, and refuses another
  role's batch (exit 2: a driver bug if it happens, counted as a stop).
- narrow allowlist: `cd` is allowed in a chain (it runs nothing itself; the rest of the chain is
  still checked); arm A showed qwen prefixes `cd <repo> &&` to every command.
- Results: per role and per phase as now; the planner's build-phase runs count under build, and
  results.md says how many tasks each role ticked.
- README: arm C, and how to compare three arms.
D-37.1 Arm C differs from A only in the planner prompt's by: rule, so A vs C measures "who writes
the failing tests".

## Security
<!-- Does this touch untrusted input, login or permissions, secrets or personal data, a new
dependency, files/network/shell, or CI/agent config? If not: "none: <why>". Otherwise, per risk:
what can go wrong → what we do (an FR with a test, a D line, or "accept: <why>").
    e.g. uploads are untrusted → FR-37.4 rejects non-images and files over 5 MB -->
The allowlist gains `cd` only as a chain step; every other program in the chain is still
checked, and narrow's dangerous-command floor still applies.

## Built
<!-- Written by the agent at the end of the build, for the review: per requirement what
changed (file:line) and which test proves it; deviations from the plan and why; follow-ups. -->
What changed (experiment/ only, plus the sdd-dev skill note):
- run.sh: arm C (`sh experiment/run.sh C`): set up as A (narrow builder, the run's own narrow
  config). The planner prompt gets `{{BYRULE}}` from prompts/by-planner.md in C, by-none.md in A
  and B (D-37.1). In the build the driver reads the batch's owner from `sdd task next` (`; by:
  <role>)` on the first `[ ]` line, the builder when none) and runs `sdd run <role>`; a role
  other than builder or planner, or exit 2 from sdd run (refused: another role's batch), is a
  stop. Per-task cap (3 runs), commits from "commit with:", check after, and failure counting
  are as before, per role. Each batch run logs the role in taskruns.tsv and the tasks it ticked
  (show --json done count before and after) in ticks.tsv.
- prompts/planner.md: `{{BYRULE}}` line; prompts/by-planner.md, prompts/by-none.md: new.
- narrow/allow.lisp: `cd DIR` (or a bare `cd`) is allowed as a step; the rest of the chain is
  still checked.
- lib/xp.py: `state` adds the ticked count; results add "tasks ticked, by role", the planner's
  build-phase runs (runs.tsv phase build) count under build, and "builder runs that left their
  task open" is now "batch runs …".
- fake/fake_agent.py: when the planner prompt asks for `by: planner`, the fake plans a
  planner-owned failing test (T-n.1 expect: fail, by: planner), the code that makes it pass
  (T-n.2) and a third task; a planner run with a current task writes that failing test.
- README.md: three arms, the by: rule, what A vs B, A vs C and B vs C measure.

How verified (no real runs):
- --dry end to end: A and B (2 builder batches each, ticked builder 2, shipped); C: `sdd run
  planner 1` for T-1.1 (ticked red and committed "feat(1): T-1.1 Version test first"; the
  driver's check after it failed, as a red test should), then two builder batches; results
  "tasks ticked, by role: builder 2, planner 1", the planner's batch under build. C's planner
  prompt held the by-planner rule, A's the by-none rule. C with XP_FAKE_COST=60 stopped at the
  $150 cap; C with XP_FAKE_REVISE=1 stopped after 3 plan rounds.
- narrow allowlist on narrow-13b380e with only allow.lisp loaded: :allow for `cd /Users/x/repo
  && python3 -m pytest -q`, `cd repo && git status && .sdd/bin/sdd check`, `cd repo`; :ask for
  `cd repo && curl x`, `cd a b && git status`, `cd $HOME && git status`, `rm -rf x`.
- `shellcheck -s sh experiment/run.sh` clean. `.sdd/bin/sdd check` passed (566 s under load;
  it warns about its 30 s budget, as expected).

Not exercised: the stop on exit 2 (the driver always asks for the batch's own role, so only a
driver bug reaches it). Deviation: the by: rule lives in two small prompt files instead of
inline in run.sh (shell quoting of backticks).

security pass: only I looked. `cd` takes at most one argument and no expansion, so it can only
change the directory of the chain's later commands, which are still the allowlisted programs;
no other confinement changed. The planner's build runs use its existing Opus tier and wrapper.

Verified by: none (builder self-checked; the orchestrator verifies)

## Review (optional)
<!-- The human's review notes: what to change, one per line. The agent works through them
and says under "## Built" what it changed for each. -->

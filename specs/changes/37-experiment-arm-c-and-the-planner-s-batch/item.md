---
id: 37
type: chore
title: Experiment: arm C and the planner's batches
status: open
created: 2026-10-29
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

## Review (optional)
<!-- The human's review notes: what to change, one per line. The agent works through them
and says under "## Built" what it changed for each. -->

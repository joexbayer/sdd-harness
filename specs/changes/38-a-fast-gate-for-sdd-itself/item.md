---
id: 38
type: refactor
title: A fast gate for sdd itself
status: open
created: 2026-10-29
---
# 38 A fast gate for sdd itself

## Goal
<!-- What gets better (structure, readability, performance) and why it matters now. -->
sdd's own gate (`sdd check`: shellcheck, then every tests/t_*.sh under /bin/sh and dash) takes
200-330 s and now warns about its own 30 s budget (item 35). Follow our own rule: a fast gate.
Target: under 60 s on this machine when idle, and no slower under load than today.
Approach: measure first (each test file's time alone, under dash), then fix the slowest causes
(repeated repo setup, sleeps, many sdd/git calls per assertion), and cap tests/run.sh's
parallelism at the CPU count instead of starting all ~70 at once. Slow by nature (t_perf): keep
it, as now run alone. If 60 s cannot be reached without dropping coverage, set this repo's
`[check] budget` to what it is and record why.

## Invariants
<!-- Behaviour that must not change. Existing tests stay as they are; they prove it. -->
Every test keeps every assertion (none weakened, skipped or deleted); both shells still run;
t_perf still runs alone. Measured before/after times go under Built.

## Built
<!-- Written by the agent at the end of the build, for the review: per requirement what
changed (file:line) and which test proves it; deviations from the plan and why; follow-ups. -->

## Review (optional)
<!-- The human's review notes: what to change, one per line. The agent works through them
and says under "## Built" what it changed for each. -->

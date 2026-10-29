---
id: 38
type: refactor
title: A fast gate for sdd itself
status: open
created: 2026-10-29
approved: 81776557a506bc7c54ff99ec429f5b42cbd65611 2026-10-29 joexbayer
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
Measured first (12-CPU Mac, other sessions loading it; load average given with each number):
- Before, each file alone under dash: 242 s summed (load 8-15); slowest t_verified 17 s,
  t_perf 15, t_contracts 14, t_agents 13, t_run 12. No file is slow because of one thing: the
  cost is process starts (sdd and git), system time about 2x user time.
- Before, `sh tests/run.sh /bin/sh dash`: **9 min 4 s** (load 9 → 13), 92% CPU. Starting all
  70 jobs at once was slower than running them one by one: they contend on process starts.
- Hot spots across the suite: ~44 `new_repo` (git init, sdd init, 2 commits: ~0.6 s each),
  3 `git config --global` per file (~0.3 s), t_perf's 95 git add + commit pairs.

Changed:
- tests/run.sh:22-48 runs a job queue (mkdir claims), one worker per CPU (`getconf
  _NPROCESSORS_ONLN`, else `sysctl -n hw.ncpu`; `SDD_TEST_JOBS` overrides), shells interleaved.
  t_perf still runs alone after the rest, one shell at a time (run.sh:49-56). Tried 8/12/16
  workers: 104/108/151 s, so the CPU count stays.
- tests/run.sh:30-35 builds one `new_repo` per shell; tests/lib.sh:27-33 `new_repo` copies it
  (`SDD_TEMPLATE`, `cp -R`, the `.git/sdd-config` cache dropped). A file run alone builds its
  repo as before.
- tests/lib.sh:12 writes the global git config with one printf (byte-identical to the three
  `git config --global` runs, checked with cmp).
- tests/t_perf.sh:38-59 writes its 95 shipped commits with one `git fast-import` (blobs from
  one `git hash-object --stdin-paths`); same history (one commit per item, same messages), and
  it now asserts the tree is clean and HEAD has 97 commits. t_perf alone: 17 → 11 s.
- No sleeps to remove: t_check_budget's `sleep 2` is what it tests (a check over a 1 s budget),
  and t_perf's 3 s pause only follows an over-budget time.

After:
- Each file alone under dash: 212 s summed (load 13 → 7).
- `sh tests/run.sh /bin/sh dash`: **1 min 49 s** (load 4 → 15), 415% CPU; 2 min 22 s at load 9-12.
- `.sdd/bin/sdd check` (shellcheck 5 s + both suites): 144 s (load 11-15), 139 s (load 8-14).

Deviation: 60 s was not reached. The suite is ~450 CPU-s of mostly process starts, and the
machine was never idle to measure. So .sdd/config:9-12 sets `[check] budget = 150` with why.
Every assertion stays; both shells run; all 35 files pass under each.
Follow-up (needs your call, not done): a test-side `sdd` runs the source copy, which execs the
repo's vendored copy, so every call starts two shells and parses common.sh twice; calling the
vendored copy directly halves a light call (`status`: 0.107 → 0.057 s) but bypasses that
delegation path in most tests. Shrinking processes inside sdd itself is product work.
sdd-dev skill updated: profiling the suite, the template repo, the CPU cap, the budget.

Verified by: none (builder self-checked; the orchestrator verifies)

## Review (optional)
<!-- The human's review notes: what to change, one per line. The agent works through them
and says under "## Built" what it changed for each. -->

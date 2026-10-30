---
id: 40
type: chore
title: Experiment: progress-aware stops
status: open
created: 2026-10-30
approved: e4699d59dd4c43a75180721260d5bcbae1cdfdd2 2026-10-30 joexbayer
---
# 40 Experiment: progress-aware stops

## What and why
<!-- 1-3 lines: what changes (dependencies, config, CI, ...) and why now. No behaviour change. -->
Pilot 2 arm C stopped while qwen was still converging (T-1.7 ended at 2 of 18 tests failing):
"2 failed runs in a row" ignores progress. experiment/ only:
- A failed batch run counts toward the stop only when the failing-test count of its task's test
  did not drop since the previous run of that task (read from the task's test log pytest summary
  "N failed"; unknown counts as no progress). The per-task cap goes from 3 to 4 runs.
- Arms A and C set `[build] max-size = S` in the run repo's config (item 39), B leaves it unset;
  results.md shows each run's failing count trend per task.
- A commit subject from "commit with:" is cut to its first 72 characters at a word boundary (the
  full message goes in the body), so `git log --oneline` stays readable.
D-40.1 Progress is the failing-test count, the one number every task test (pytest) prints.

## Security
<!-- Does this touch untrusted input, login or permissions, secrets or personal data, a new
dependency, files/network/shell, or CI/agent config? If not: "none: <why>". Otherwise, per risk:
what can go wrong → what we do (an FR with a test, a D line, or "accept: <why>").
    e.g. uploads are untrusted → FR-40.4 rejects non-images and files over 5 MB -->
none: driver logic and config only.

## Built
<!-- Written by the agent at the end of the build, for the review: per requirement what
changed (file:line) and which test proves it; deviations from the plan and why; follow-ups. -->
Progress-aware stop: experiment/run.sh:308-327. A failed run is progress, not a failure toward
"2 failed runs in a row", when it ticked a task, or when the failing count of the task it failed
on dropped since the last run that failed there. The count comes from experiment/lib/xp.py:136
(`xp.py failing`, the last pytest summary's failed + errors, `?` when unread), and an unread count
is no progress. The per-task cap is 4 runs (run.sh:279). Each run's count goes to trend.tsv.
max-size: arms A and C set `build.max-size S` in the run repo's config (run.sh:454); B leaves it
unset. results.md gains "Failing tests per task run" (xp.py:305).
Commit subjects: run.sh:292-299 cuts a "commit with:" message longer than 72 characters to a
subject at a word boundary (xp.py:154), with the whole message as the body.
Docs: experiment/README.md:69-78 (caps, max-size, subjects), :94-95 (two new dry runs), :118 (the
trend); the fake agent's docstring names its two new switches.

Proven by dry runs (fake agents, nothing spent): A, B and C each reach ship, with max-size S in A
and C and unset in B; a long task title gives a 65-character subject and the full message in the
body. XP_FAKE_CONVERGE=T-1.1 runs 5 → 2 → 0 and ships; XP_FAKE_STALL=T-1.1 runs 2 → 2 and stops
on "2 failed builder runs in a row". The older dry scenarios behave as before.

Deviations:
- A failed run that still ticked a task also counts as progress. The plan names only the falling
  count, but a ticked task is the clearest progress there is.
- The fake agent now builds every task in a batch, and its tasks are size S, matching the real
  batched builds since item 31 and max-size S. This was needed to test the new stop.

Follow-ups:
- arms A and C need item 39 in main before the re-runs. Until then, sdd ignores `[build] max-size`.
- The README line `XP_FAKE_COST=8 … # the spend cap stops it` is wrong: that run ends at $40 of
  $150, on main too. It was already wrong before this item, so it is left for its own change.

Security pass: no findings (a fresh Sonnet reviewer given only the diff; agent text reaches git
and Python only as quoted arguments).
Verified by: claude-sonnet: 3 of 3 plan points proven, including the unread count and the cap of 4 in variant copies; two doc nits (the fake agent's docstring, fixed; the stale COST=8 README line, a follow-up)

## Review (optional)
<!-- The human's review notes: what to change, one per line. The agent works through them
and says under "## Built" what it changed for each. -->

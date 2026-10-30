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

## Review (optional)
<!-- The human's review notes: what to change, one per line. The agent works through them
and says under "## Built" what it changed for each. -->

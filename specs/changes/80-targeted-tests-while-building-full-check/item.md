---
id: 80
type: chore
title: Targeted tests while building, full check once at finish
status: open
created: 2026-11-21
---
# 80 Targeted tests while building, full check once at finish

## What and why
Builders re-run the full check (5-10 min here) after small steps. The build prompt says: while building, run only the current task's test; the full check runs once at finish and for a task with no test of its own. Saves time and tokens; the gate is unchanged.

## Security
none: prompt wording only; `check` still gates finish and ship.

## Built
<!-- Written by the agent at the end of the build, for the review: per requirement what
changed (file:line) and which test proves it; deviations from the plan and why; follow-ups. -->
build.md:59-61: "Run only the current task's test; run `check` ... once at finish and for a task without one. Never re-run a passed check on unchanged code." Test: t_prompts_tests.sh asserts both phrases; the build step stays under its 820-word ceiling (trimmed to fit).
Deviations: none. Check passed (423 s; the budget warning is the machine load).

## Review (optional)
<!-- What to change, one per line (the agent writes what the human asks). The agent works through them
and says under "## Built" what it changed for each. -->

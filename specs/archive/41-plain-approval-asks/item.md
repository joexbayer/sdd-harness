---
id: 41
type: fix
title: Plain approval asks
status: shipped
created: 2026-10-30
approved: 461f497545a6e11f4c7dbe4a2b8a6a364cb0fdb7 2026-10-30 joexbayer
shipped: 2026-10-30
---
# 41 Plain approval asks

## Current behaviour
<!-- What happens now, and how to reproduce it. -->
The plan rules end with "summarise it for the human and ask them to approve it". On 2026-10-30
the agent chained plan writing, a commit and `sdd approve` in one shell command, so the human's
approval prompt showed a wall of Python: "hard to read, barely understandable".

## Expected behaviour
<!-- FR-41.1 WHEN <trigger> THE SYSTEM SHALL <response>.
  e.g. <input> → <output> -->
FR-41.1 WHEN the plan rules reach approval THE SYSTEM SHALL tell the agent to post a plain summary
of at most about 15 lines (the problem, what changes, one concrete example, a small ASCII sketch
of the flow), ask for a yes in words, and only then run `sdd approve` as a command on its own,
never chained to other commands.
  e.g. `sdd next` in plan → contains "a command on its own"

## Must not change
<!-- Behaviour that has to stay exactly as it is (so the fix breaks nothing else). -->
Only the human approves (human_only, the ask rule); the rest of the plan rules.

## Security
<!-- Does this touch untrusted input, login or permissions, secrets or personal data, a new
dependency, files/network/shell, or CI/agent config? If not: "none: <why>". Otherwise, per risk:
what can go wrong → what we do (an FR with a test, a D line, or "accept: <why>").
    e.g. uploads are untrusted → FR-41.4 rejects non-images and files over 5 MB -->
none: prompt text. It keeps the human's approval prompt readable, which is what the ask rule
on approve is for.

## Test
<!-- The regression test (name and file) that fails now and passes after the fix. -->
tests/t_prompts_tests.sh: plan-phase `next` contains "a command on its own" and "ASCII".

## Built
<!-- Written by the agent at the end of the build, for the review: per requirement what
changed (file:line) and which test proves it; deviations from the plan and why; follow-ups. -->
FR-41.1: the closing paragraph of the plan rules (.sdd/core/prompts/plan.md:55-58) now tells the
agent to post a plain summary of at most about 15 lines (problem, what changes, one example, a
small ASCII sketch), ask for a yes in words, and only after that yes run approve as a command on
its own, never chained to other commands. Proven by tests/t_prompts_tests.sh:27-31, which failed
before the change ("expected output to contain [a command on its own]") and passes after.

Deviations:
- The old phrase "and then confirm it" is gone. The confirmation still happens: approve itself is
  unchanged and still asks the human (human_only; t_role_guard.sh and t_agents.sh pass).
- The test asserts two more phrases than the plan's Test section named ("a yes in words",
  "never chained to other commands"), after the verifier said those parts were untested.

Follow-ups:
- check took 156 s and then 175 s against its 150 s budget. The two added prompt assertions do not
  account for that, so it is probably machine load, but the margin is thin.

Security pass: no findings (a fresh Sonnet reviewer given only the diff).
Verified by: claude-sonnet: 1 of 1 FRs proven; the test was too weak on "a yes in words" and "never chained", now asserted

## Review (optional)
<!-- The human's review notes: what to change, one per line. The agent works through them
and says under "## Built" what it changed for each. -->

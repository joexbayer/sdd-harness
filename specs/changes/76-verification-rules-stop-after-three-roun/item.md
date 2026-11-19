---
id: 76
type: feature
title: Verification rules: stop after three rounds, no flaky workarounds, graded findings
status: open
created: 2026-11-18
approved: 5c7568de78f1a5274b6d9e754daad180bd445522 2026-11-19 joexbayer
---
# 76 Verification rules: stop after three rounds, no flaky workarounds, graded findings

## Why
A builder told to work "until the check passes" can loop on a failure it cannot fix, or get green by rerunning a flaky test or adding a sleep. Verifier findings come unranked, so a pre-existing bug blocks as hard as a real one, and a second round re-checks from scratch. Taken from how the Claude Code team verifies (stop after three rounds, no flaky workarounds, severity tags, rounds that build on each other).

## What changes
US-76.1 As the human I hear from the agent when it is stuck, so that it does not burn hours on a failure it cannot fix.
FR-76.1 WHEN `check` fails for an item for the third time in a row THE SYSTEM SHALL say so and tell the agent to stop and tell the human what fails and what it tried; a pass resets the count.
  e.g. third failed `sdd check` → `✗ check failed 3 times in a row: stop and tell the human what fails and what you tried`
FR-76.2 WHEN the build prompt is shown for a type with code THE SYSTEM SHALL forbid making a flaky test pass by rerunning, sleeping, retrying or skipping, and say: if the cause is unknown, delete the test and record why under "## Built".
  e.g. `sdd next` in build → contains `rerun`, `sleep` and `delete the test`
FR-76.3 WHEN the verifier prompt is shown THE SYSTEM SHALL ask for each finding tagged must-fix, should-fix, nit or pre-existing, and the build prompt SHALL say: fix must-fix, decide should-fix, list the rest under "## Built"; a pre-existing bug never counts against the item.
  e.g. role-verifier text → contains `must-fix` and `pre-existing`
FR-76.4 WHEN the verifier runs again on an item that has earlier findings THE SYSTEM SHALL tell it to check those fixes first and look near them, not re-check from scratch.
  e.g. role-verifier text → contains `earlier round`

## Not in scope (optional)
A `verify.run` smoke command and property or differential tests (a later feature). Reviewer recall evals.

## How
```
sdd check ──fail──▶ $ST/checks/<id>.fails  (count +1) ──≥3──▶ "stop and tell the human"
          ──pass──▶ rm <id>.fails
prompts/build.md          + flaky rule, + how to act on tagged findings
prompts/role-verifier.md  + tags, + earlier-round rule
```
D-76.1 The count lives next to the check logs in `$ST/checks/` (per clone, not committed), like the check fingerprint: it is a hint, not item state (C-2).
D-76.2 Three, fixed, not configurable: the post's number; nothing needs it changed yet.
D-76.3 The count is per item, any failure: telling one failure from another is not worth the code.
D-76.4 "Proves nothing" (exit 3) and "could not run" count too: both are failures the agent may loop on.

## Security
none: prompt text and a per-clone counter file under `.git/sdd/`; no input crosses a trust boundary.

## Questions (optional)

## Done when
DOD-76.1 Three failed checks in a row print the stop line; the prompts carry the rules (tests show both).

## Tasks (optional)
- [ ] T-76.1 Failing tests: the stop line on the third failure and its reset, the prompt rules, FR-76.1 FR-76.2 FR-76.3 FR-76.4 (files: tests/t_check.sh, tests/t_prompts_tests.sh; test: for t in check prompts_tests; do SRC=$PWD SH=dash dash tests/t_$t.sh || exit 1; done; expect: fail; size: S)
- [ ] T-76.2 Count failures in check, FR-76.1 (files: .sdd/core/cmd/check.sh; test: SRC=$PWD SH=dash dash tests/t_check.sh; size: S)
- [ ] T-76.3 Prompt rules, FR-76.2 FR-76.3 FR-76.4 (files: .sdd/core/prompts/build.md, .sdd/core/prompts/role-verifier.md; test: for t in prompts_tests verified security; do SRC=$PWD SH=dash dash tests/t_$t.sh || exit 1; done; size: S)

## Built
<!-- Written by the agent at the end of the build, for the review: per requirement what
changed (file:line) and which test proves it; deviations from the plan and why; follow-ups. -->

## Review (optional)
<!-- What to change, one per line (the agent writes what the human asks). The agent works through them
and says under "## Built" what it changed for each. -->

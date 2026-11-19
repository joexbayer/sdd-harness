---
id: 76
type: feature
title: Verification rules: stop after three rounds, no flaky workarounds, graded findings
status: shipped
created: 2026-11-18
approved: 5c7568de78f1a5274b6d9e754daad180bd445522 2026-11-19 joexbayer
shipped: 2026-11-19
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
- [x] T-76.1 Failing tests: the stop line on the third failure and its reset, the prompt rules, FR-76.1 FR-76.2 FR-76.3 FR-76.4 (files: tests/t_check.sh, tests/t_prompts_tests.sh; test: for t in check prompts_tests; do SRC=$PWD SH=dash dash tests/t_$t.sh || exit 1; done; expect: fail; size: S)
- [x] T-76.2 Count failures in check, FR-76.1 (files: .sdd/core/cmd/check.sh; test: SRC=$PWD SH=dash dash tests/t_check.sh; size: S)
- [x] T-76.3 Prompt rules, FR-76.2 FR-76.3 FR-76.4 (files: .sdd/core/prompts/build.md, .sdd/core/prompts/role-verifier.md; test: for t in prompts_tests verified security; do SRC=$PWD SH=dash dash tests/t_$t.sh || exit 1; done; size: S)

## Built
- FR-76.1: `check.sh:14-24` counts failures in `$ST/checks/<id>.fails` (exit 1, exit 3, could not run all count; a pass removes it; `n=0` first so the environment cannot leak in); `check.sh:58` prints the stop line at 3 or more. Only the `check` verb counts: ship and task done call `run_check` directly. Test: `t_check.sh` (new: no line at 1 and 2, the line at 3, reset by a pass).
- FR-76.2, FR-76.3 (build side): `prompts/build.md:35-36`, the flaky rule and how to act on tagged findings. Test: `t_prompts_tests.sh`.
- FR-76.3, FR-76.4 (verifier side): `prompts/role-verifier.md` step 3 asks for must-fix / should-fix / nit / pre-existing and, on a later round, the earlier findings and their fixes first. Test: `t_prompts_tests.sh`.
- Deviation: the build-prompt word ceiling in `t_prompts_tests.sh:88` went 770 → 820 (prompt now 812 words); the repo has raised it this way before. Next prompt addition will need a trim.
- Not tested: exit 3 counting (same branch as any failure).
- Known: two full checks failed on unrelated tests under load (`t_verified`, then `t_gitcalls`, load ~16); both pass alone; the third run passed (342 s, budget 150 s).
- Security pass (the verifier, on the diff): nothing exploitable; the counter path uses sdd's own item id under `.git/sdd`.

Verified by: claude-opus-5-5: PASS; FR-76.1 proven by three check.sh mutants (no line, no reset, no write), prompts by removing the lines; the two load failures traced to run_check, not the counter; uninitialised n fixed

## Review (optional)
<!-- What to change, one per line (the agent writes what the human asks). The agent works through them
and says under "## Built" what it changed for each. -->

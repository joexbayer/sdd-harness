---
id: 35
type: feature
title: Tests that stay fast and prove something
status: shipped
created: 2026-10-29
approved: 9c1349b88107463a9a95cd7b93e84a920d945148 2026-10-29 joexbayer
shipped: 2026-10-29
---
# 35 Tests that stay fast and prove something

## Why
<!-- The problem in plain words: who hurts, and how. 2-4 lines. -->
Pilot arm B (2026-10-29) built a good app whose gate took 78 s, mostly real password hashing in
every test, run after every task: about half the build was waiting. narrow's spot runs showed
small models writing hollow tests that pass the red gate but prove nothing. Research:
specs/kb/agent-testing.md. The human: in-depth end-to-end tests belong to the feature's own task,
not to the project-wide gate run forever.

## What changes
<!-- User-visible behaviour. One requirement per entry, each with a concrete example:
    US-35.1 As a <role> I <action>, so that <outcome>.
    FR-35.1 WHEN <trigger> THE SYSTEM SHALL <response>.
      e.g. <input> → <output>
Start each entry at the beginning of its line, ID first. IDs never change; leave gaps. -->
FR-35.1 WHEN `sdd check` runs THE SYSTEM SHALL say how long it took, and record it with the result.
  e.g. → "✓ check passed for item 7 (12 s)"
FR-35.2 WHEN a check takes longer than `[check] budget` seconds (default 30; 0 turns it off) THE
SYSTEM SHALL warn, without failing, naming the usual causes and that slow tests belong to their
task's own test, not the gate.
  e.g. 78 s → "⚠ the check took 78 s (budget 30 s): keep the gate fast. Slow tests (end-to-end, real hash cost, sleeps, network) belong to their task's test: mark them and leave them out of check.run; make cost settings (hash rounds, timeouts) configurable and minimal in tests, with one test on the real values"
  e.g. `[check] budget = 0` → no warning
FR-35.3 WHEN `next` gives plan rules THE SYSTEM SHALL include the test rules: the gate is fast; a
task's own test may be deep (end-to-end, real cost settings) and is marked so the gate leaves it
out; cost settings are configurable and minimal in tests; each task's test asserts its FR's
example literally; list endpoints get a test that counts queries.
  e.g. `sdd next` in plan → contains "The gate (check) stays fast"
FR-35.4 WHEN `next` gives build rules THE SYSTEM SHALL include: a test that would still pass if
every function returned nothing is no test; expected values never come from the code under test;
write just enough code to pass, without abstractions or defensive code nothing asked for.
  e.g. `sdd next` in build → contains "returned nothing"
FR-35.5 WHEN the verifier role's prompt is given THE SYSTEM SHALL ask, per FR, whether some test
would fail if that FR were dropped, and to report each FR with no such test.
  e.g. role-verifier.md → contains "would fail if"

## Not in scope (optional)
<!-- What this deliberately leaves out, and where it went. -->
Opus writing the red tests (`by: planner`): item 36. Review warnings for assertion-less tests and
mutation spot checks: after the next pilot.

## How
<!-- What a reviewer needs: an ASCII sketch of the moving parts, key types or signatures,
and the decisions they would question, each at the start of its line:
    D-35.1 <decision>, because <reason>. -->
D-35.1 sdd stays runner-neutral: it times `check.run` as a whole and warns; the project marks and
excludes slow tests itself (pytest `-m "not slow"`, a tag, a separate command), as the plan rules say.
D-35.2 A warning, not a gate: a slow suite is a cost, not wrong code; 30 s fits a run after every
task batch (Beck: "all the tests except long-running ones each time"; kb/agent-testing.md).
D-35.3 The rules quote their sources' short forms (ub-mode's "returned nothing", pstack's "computed
by the code under test", Anthropic's over-engineering prompt), already proven with agents.

## Security
<!-- Does this touch untrusted input, login or permissions, secrets or personal data, a new
dependency, files/network/shell, or CI/agent config? If not: "none: <why>". Otherwise, per risk:
what can go wrong → what we do (an FR with a test, a D line, or "accept: <why>").
    e.g. uploads are untrusted → FR-35.4 rejects non-images and files over 5 MB -->
none: timing and prompt text only; no new input or dependency.

## Questions (optional)
<!-- Q-35.1 <question> → recommend: <answer>. Resolve before building. -->

## Done when
<!-- DOD-35.1 <observable outcome>, e.g. "works against staging". -->
DOD-35.1 `sdd check` passes; tests prove FR-35.1 to FR-35.5. specs/kb/agent-testing.md committed.

## Tasks (optional)
<!-- Small, ordered steps the builder does one at a time, each in one sitting, each with a test
of its own (so it can pass before the next task exists):
    - [ ] T-35.1 Page the orders query, FR-35.1 (files: src/orders.js; test: npm test -- orders; size: S)
Size each task `S`, `M` or `L` (none is M): consecutive S tasks go to one builder together, M and
L ones alone. Add `; expect: fail` for a test written first (it must fail), or
`; expect: fail "<text>"` (it must fail with that text in its output); without `test:` the
full check runs. `.sdd/bin/sdd task done T-35.1` ticks a task when its test passes. -->
- [x] T-35.1 Check time and budget warning, FR-35.1, FR-35.2 (files: .sdd/core/lib/common.sh, .sdd/core/cmd/check.sh, .sdd/core/config, tests/t_check_budget.sh; test: SRC=$PWD SH=dash dash tests/t_check_budget.sh; size: M)
- [x] T-35.2 Test rules in the plan, build and verifier prompts, FR-35.3, FR-35.4, FR-35.5 (files: .sdd/core/prompts/plan.md, .sdd/core/prompts/build.md, .sdd/core/prompts/role-verifier.md, tests/t_prompts_tests.sh; test: SRC=$PWD SH=dash dash tests/t_prompts_tests.sh; size: S)
- [x] T-35.3 README, design, kb note, sdd-dev notes (files: README.md, specs/design.md, specs/kb/agent-testing.md, .claude/skills/sdd-dev/SKILL.md; size: S)

## Built
<!-- Written by the agent at the end of the build, for the review: per requirement what
changed (file:line) and which test proves it; deviations from the plan and why; follow-ups. -->
- FR-35.1: `run_check` times the `check.run` commands with `date +%s` into `CHECK_SECS`
  (.sdd/core/lib/common.sh:912, :923) and records it as `secs=` (check_record, :683, :936).
  `check` shows it on every outcome: "✓ check passed for item 7 (12 s)", "✗ check failed
  (12 s; full log: …)", "✗ check proves nothing: … (12 s; log: …)" (.sdd/core/cmd/check.sh:16,
  :27, :36). Test: tests/t_check_budget.sh (shown time equals the recorded `secs=`; a failing
  check shows its time).
- FR-35.2: `budget = 30` with its comment in .sdd/core/config `[check]`; the warning is printed
  after the result, exit code unchanged (.sdd/core/cmd/check.sh:41-46), with the FR's wording
  exactly. Test: tests/t_check_budget.sh (`sleep 2` with budget 1 → warning and still exit 0;
  budget 0 → no warning).
- FR-35.3: a "Tests:" bullet in .sdd/core/prompts/plan.md:38-42 ("The gate (check) stays
  fast", deep task tests marked and left out of check.run, cost settings configurable and
  minimal, the FR's example asserted literally, a query-counting test for list endpoints).
- FR-35.4: .sdd/core/prompts/build.md:26-29 adds "never from the code under test" and "Write
  just enough code to pass the test, without abstractions, options or defensive code nothing
  asked for"; "returned nothing" was already there (:22-25) and stays.
- FR-35.5: .sdd/core/prompts/role-verifier.md:9-12: "Per FR, ask: is there a test that would
  fail if that FR were dropped?", and an FR with no such test is a finding.
  Tests for FR-35.3..5: tests/t_prompts_tests.sh (plan `next`, build `next`, and the synced
  `sdd-verifier` subagent).
- Docs: README.md (`sdd check` row), specs/design.md §9 step 2, .claude/skills/sdd-dev/SKILL.md
  (timing notes); specs/kb/agent-testing.md committed.

Deviations and choices:
- The time is also shown on fail and "proves nothing", not only on pass (FR-35.1 says "say how
  long it took"; the e.g. shows the pass line).
- The warning shows on any outcome, not only a pass: a slow failing gate is just as slow.
- A `[check] budget` that is not a whole number warns and counts as 0 (off), rather than a
  shell arithmetic error.
- Only `sdd check` prints the time and warning; `task done` and `ship` also run `run_check`, so
  their records get `secs=` too, but print nothing new (the FR names `sdd check`).

Follow-ups:
- This repo's own check takes ~220 s on this machine, so it now warns every run. I did not set
  a budget in .sdd/config (the build rules keep the builder out of `.sdd/`): the human may set
  `budget = 300` there, or 0.

Edge cases left out (not coded): whole-second `date +%s` timing can be off by up to 1 s around
a second boundary or if the clock jumps (NTP) during a run; failure mode: a check right at the
budget warns or not, or a negative time shows once; likely rare, harmless (a warning only);
cost of fixing: a sub-second timer, not in POSIX.

Security pass: the diff reads one config number (validated as digits before arithmetic) and
prints text; no new input, dependency, file or network use. No findings.

Verified by: none (builder self-checked; the orchestrator verifies)

## Review (optional)
<!-- The human's review notes: what to change, one per line. The agent works through them
and says under "## Built" what it changed for each. -->

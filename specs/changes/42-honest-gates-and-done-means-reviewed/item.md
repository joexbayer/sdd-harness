---
id: 42
type: feature
title: Honest gates, and done means reviewed
status: open
created: 2026-10-30
approved: 4b67cf3a8039ff620b168f81da121ee1069785b1 2026-10-30 joexbayer
---
# 42 Honest gates, and done means reviewed

## Why
<!-- The problem in plain words: who hurts, and how. 2-4 lines. -->
Two runs on 2026-10-30 and the private-project study show green gates over wrong work. In arm A, qwen
wrote tests that agreed with its wrong code, so 46 green tests passed a shape check that accepts
what the plan rejects. In private-project, an e2e script stayed broken behind green gates that never
ran it. And the design's "done" still asks for an unattended qwen run, which is not how sdd is used.

## What changes
<!-- User-visible behaviour. One requirement per entry, each with a concrete example:
    US-42.1 As a <role> I <action>, so that <outcome>.
    FR-42.1 WHEN <trigger> THE SYSTEM SHALL <response>.
      e.g. <input> → <output>
Start each entry at the beginning of its line, ID first. IDs never change; leave gaps. -->
FR-42.1 WHEN `next` gives plan rules THE SYSTEM SHALL say that a test's setup gives a different
result for the FR's rule than for a plausible wrong rule.
  e.g. plan rules contain "a plausible wrong rule"
FR-42.2 WHEN the verifier gets its rules (its role prompt, and the finish step's hand-off to a
fresh verifier) THE SYSTEM SHALL tell it to run the tests the check leaves out, and to report a
new function, file, table or stored value that nothing in the shipped code calls or reads.
  e.g. sdd-verifier.md and the finish step contain "tests the check leaves out" and "nothing calls or reads"

Docs and housekeeping (no behaviour change):
- specs/design.md section 16: the exit criteria say a human reviews. A real repo ships about 10
  items, no gate is bypassed, reviews take minutes, and the human finds the problems at review
  rather than after ship. Small models are supported and supervised. The experiment row is done.
- specs/kb/experiment-results.md: the three-arm result of 2026-10-30, and what it means.
- Commit specs/kb/private-project-lessons.md, and the experiment's claude runs using the claude-experiment
  config (experiment/run.sh, experiment/README.md).

## Not in scope (optional)
<!-- What this deliberately leaves out, and where it went. -->
A "not run" list printed by check, a plan-size warning (item 39 did it), a periodic whole-system
review (a roadmap habit), caps on skills, and more experiment runs. Users adapt the prompts
through `.sdd/local/` overrides, so no new command or config key.

## How
<!-- What a reviewer needs: an ASCII sketch of the moving parts, key types or signatures,
and the decisions they would question, each at the start of its line:
    D-42.1 <decision>, because <reason>. -->
D-42.1 Default lines in the prompts users can already override, not new machinery, because users
adapt sdd to their codebase the way they adapt Spec Kit.
D-42.2 No new rule against tests bent to fit the code: the build rules already say expected
values come from the FR's example. Arm A broke that rule, and a human review is what catches it.

## Security
<!-- Does this touch untrusted input, login or permissions, secrets or personal data, a new
dependency, files/network/shell, or CI/agent config? If not: "none: <why>". Otherwise, per risk:
what can go wrong → what we do (an FR with a test, a D line, or "accept: <why>").
    e.g. uploads are untrusted → FR-42.4 rejects non-images and files over 5 MB -->
none: prompt text and docs. The experiment change only points claude at the user's config folder.

## Questions (optional)
<!-- Q-42.1 <question> → recommend: <answer>. Resolve before building. -->

## Done when
<!-- DOD-42.1 <observable outcome>, e.g. "works against staging". -->
DOD-42.1 `sdd check` passes, and tests/t_prompts_tests.sh proves FR-42.1 and FR-42.2.

## Tasks (optional)
<!-- Small, ordered steps the builder does one at a time, each in one sitting, each with a test
of its own (so it can pass before the next task exists):
    - [ ] T-42.1 Page the orders query, FR-42.1 (files: src/orders.js; test: npm test -- orders; size: S)
Size each task `S`, `M` or `L` (none is M): consecutive S tasks go to one builder together, M and
L ones alone. Add `; expect: fail` for a test written first (it must fail), or
`; expect: fail "<text>"` (it must fail with that text in its output); without `test:` the
full check runs. `.sdd/bin/sdd task done T-42.1` ticks a task when its test passes. -->
- [x] T-42.1 The plan line and the verifier lines, FR-42.1, FR-42.2 (files: .sdd/core/prompts/plan.md, .sdd/core/prompts/role-verifier.md, .sdd/core/prompts/finish.md, tests/t_prompts_tests.sh; test: SRC=$PWD SH=dash dash tests/t_prompts_tests.sh; size: S)
- [ ] T-42.2 Design exit criteria and the experiment results note (files: specs/design.md, specs/kb/experiment-results.md; size: S)

## Built
<!-- Written by the agent at the end of the build, for the review: per requirement what
changed (file:line) and which test proves it; deviations from the plan and why; follow-ups. -->

## Review (optional)
<!-- The human's review notes: what to change, one per line. The agent works through them
and says under "## Built" what it changed for each. -->

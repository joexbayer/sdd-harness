---
id: 55
type: feature
title: Lean prompts: brief, big questions first, chat reviews, fewer tests
status: open
created: 2026-11-01
approved: 4b735705e844a233c8c343f8ad3295e39c793b9c 2026-11-01 joexbayer
---
# 55 Lean prompts: brief, big questions first, chat reviews, fewer tests

## Why
User feedback (2026-11-01) and the practices review (scratchpad note, 2026-11-01):
- Approvals should look like the user's Spec Kit "Pre-Task Review" (ASCII, not Mermaid).
- The human never reads markdown: plans and reviews are presented in chat.
- Load-bearing questions first, at most ~5 (Spec Kit's clarify).
- Be brief: `sdd next` prints ~900 words while planning and ~770 while building.
- Rules breed tests: every edge case its own FR (plan.md:24), a test per task (plan.md:31), deleting
  a test banned (build.md:21). The experiment wrote 945 lines of code and 2,289 of tests.
- The verifier asks whether a test would catch a dropped FR (role-verifier.md:9) but does not try.

## What changes
FR-55.1 WHEN the plan is complete THE SYSTEM SHALL tell the agent to present, in chat: one line on what
is planned and what it does not need; an ASCII architecture sketch; 2-4 critical parts, each with its
file and 2-3 sentences; assumptions to check; testing; then the action, with the approval question
itself carrying a 2-4 sentence plain summary.
  e.g. plan-phase `sdd next` contains "Critical parts" and "Assumptions to check"
FR-55.2 WHEN the agent plans THE SYSTEM SHALL tell it to ask the load-bearing questions first
(architecture, data, interfaces, scope), at most about 5, and record smaller choices as D lines.
  e.g. plan-phase `sdd next` contains "load-bearing questions first"
FR-55.3 WHEN the agent reviews with the human THE SYSTEM SHALL tell it to present the review in chat (per
FR one line: what it does, an example, the proof), never send the human to read a file, and write the
changes the human says into "## Review" itself.
  e.g. review-phase `sdd next` and the `/sdd-review` skill contain "never send the human to read a file"
FR-55.4 WHEN `sdd init` writes the AGENTS.md block THE SYSTEM SHALL include "Be brief: short plain words,
only what is needed, in chat and in files. Never send the human to read a file: summarise it in chat
with an example."
  e.g. a fresh init → AGENTS.md has "Never send the human to read a file"
FR-55.5 WHEN the plan and build rules talk about tests THE SYSTEM SHALL say: cases that share one rule
share one FR (one example per case); a task's test may extend an existing test; a test that only
repeats another's case may be deleted, listed under "## Built".
  e.g. build-phase `sdd next` contains "may be deleted"; plan-phase contains "share one FR"
FR-55.6 WHEN the verifier checks an FR THE SYSTEM SHALL tell it to undo that FR's code in a scratch copy,
run its test, and report the FR unproven if the test still passes; and to report tests that repeat
another test's case.
  e.g. the synced verifier agent contains "undo that FR's code in a scratch copy"
FR-55.7 WHEN `sdd next` prints the plan or build step THE SYSTEM SHALL stay under a loose ceiling of
750 words (plan) and 700 words (build), counted with `wc -w` in a fresh repo: it catches bloat, not
useful lines (amended 2026-11-01, the user's choice: "goal is a good product").
  e.g. plan step today ~898 words → under 750

## Not in scope (optional)
- The test suite itself (wording checks, gate speed, merged files): item 56.
- New commands or config.

## How
Text only: `.sdd/core/prompts/plan.md`, `build.md`, `finish.md`, `review.md`, `role-verifier.md`,
`.sdd/core/agents/skills/review.md`, and the AGENTS.md block in `.sdd/core/cmd/init.sh`. Cut words
first: drop lines the template already says (plan.md:30-39 repeats the Tasks comment), web-only rules
(query counts) go to `<prompt>.append.md` examples in the README.
D-55.1 Tests check one short phrase per rule, not wrapped paragraphs (item 56 removes the old ones).
D-55.2 Word limits are tested so the prompts cannot grow back unnoticed.

## Security
none: prompt text only; the security rules in build.md stay word for word.

## Questions (optional)
<!-- Q-55.1 <question> → recommend: <answer>. Resolve before building. -->

## Done when
`tests/t_prompts_tests.sh` passes under sh and dash, and `sdd check` passes.

## Tasks (optional)
- [x] T-55.1 Plan prompt: the review shape, big questions first, test rules, cut to 600 words, FR-55.1, FR-55.2, FR-55.5, FR-55.7 (files: .sdd/core/prompts/plan.md, tests/t_prompts_tests.sh; test: SRC=$PWD SH=dash dash tests/t_prompts_tests.sh; size: S)
- [x] T-55.2 Build, finish, review, verifier, review skill and AGENTS block, FR-55.3, FR-55.4, FR-55.5, FR-55.6, FR-55.7 (files: .sdd/core/prompts/build.md, .sdd/core/prompts/finish.md, .sdd/core/prompts/review.md, .sdd/core/prompts/role-verifier.md, .sdd/core/agents/skills/review.md, .sdd/core/cmd/init.sh, tests/t_prompts_tests.sh; test: SRC=$PWD SH=dash dash tests/t_prompts_tests.sh; size: S)

## Built
<!-- Written by the agent at the end of the build, for the review: per requirement what
changed (file:line) and which test proves it; deviations from the plan and why; follow-ups. -->

## Review (optional)
<!-- The human's review notes: what to change, one per line. The agent works through them
and says under "## Built" what it changed for each. -->

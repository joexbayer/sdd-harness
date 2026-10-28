---
id: 20
type: feature
title: Build and plan discipline
status: shipped
created: 2026-10-28
approved: 65fa153c1d1d1d77bb9896ef1c9154c62250e039 2026-10-28 joexbayer
shipped: 2026-10-28
---
# 20 Build and plan discipline

## Why
The builder may be a small coder model (qwen in item 16's runs). Such models keep patching when
a fix fails, write tests that pass whatever the code returns, and bolt new requirements onto an
old design. Uncle Bob's ub-mode skill (github.com/unclebob/ub-mode, read 2026-10-28) names rules
against each; sdd's prompts lack them.

## What changes
FR-20.1 WHEN an agent builds THE SYSTEM SHALL tell it (build prompt): after two fixes resting
on the same assumption fail, write that assumption in one sentence under "## Built" and stop,
instead of a third fix.
  e.g. two edits to the date parser both fail the same test → Built says "assumed dates are
  UTC; the fixture is local time", the builder stops and reports
FR-20.2 WHEN an agent builds THE SYSTEM SHALL tell it: a test must call the code the way its
user does and check what that user sees; a test that would still pass if every function
returned nothing is to be rewritten.
  e.g. a test asserting only "no exception" → rewritten to assert the returned rows
FR-20.3 WHEN an agent plans THE SYSTEM SHALL tell it (plan prompt): take complexity out before
adding any, and plan what would have been built had the requirement existed from the start,
delivered in tasks, rather than bolting it on.
  e.g. a third special case in one function → the plan reshapes the function, then adds the case
FR-20.5 WHEN an agent plans THE SYSTEM SHALL tell it (plan prompt): before writing a question for
the human, check whether running something (a probe, a quick script, reading the code) could
answer it, and if so run it; questions are for product and preference calls.
  e.g. "does the API page at 100?" → the planner calls the API and writes the answer as a D line
FR-20.4 WHEN someone reads the README THE SYSTEM SHALL say in its opening that sdd checks its
workflow (approval, test-first tasks, check results, finish gate) rather than asking the
agent to follow rules.
  e.g. the first paragraph names those checks

## Not in scope (optional)
- Uncle Bob's quality tools (crapper, dryer, mutator): language-specific; any of them already
  fits a `[check] run` line. Suggesting one in `init` can come later.
- Glossary, idempotency and shared-state rules: general advice, not sdd's to enforce.

## How
Text only: `prompts/build.md` (all build types include it), `prompts/plan.md`, `README.md`.
A test runs `sdd next` in the build and plan phases and finds each rule.
D-20.1 Prompt rules, not gates, because neither "same assumption" nor "behaviour test" can be
judged by a script; sdd already gates what a script can (red-first tasks, check results).

## Security
none: prompt and README text only; no new input, command or dependency.

## Done when
DOD-20.1 `sdd check` passes, with a test naming FR-20.1, FR-20.2, FR-20.3 and FR-20.5.

## Tasks (optional)
- [x] T-20.1 Build prompt rules, FR-20.1, FR-20.2 (files: .sdd/core/prompts/build.md, tests/t_discipline.sh; test: SH=/bin/sh SRC=$PWD sh tests/t_discipline.sh)
- [x] T-20.2 Plan prompt rules, FR-20.3, FR-20.5 (files: .sdd/core/prompts/plan.md, tests/t_discipline.sh; test: SH=/bin/sh SRC=$PWD sh tests/t_discipline.sh)
- [x] T-20.3 README opening, FR-20.4 (files: README.md)

## Built
<!-- Written by the agent at the end of the build, for the review: per requirement what
changed (file:line) and which test proves it; deviations from the plan and why; follow-ups. -->

- FR-20.1, FR-20.2: two build rules in .sdd/core/prompts/build.md:23-29 (behaviour tests; two
  failed fixes on one assumption → state it, stop). tests/t_discipline.sh checks `next` in build.
- FR-20.3, FR-20.5: two plan rules in .sdd/core/prompts/plan.md:10-15 (probe before asking;
  subtract before adding, redesign rather than bolt on). tests/t_discipline.sh checks `next` in plan.
- FR-20.4: README.md:6-9, the opening names what sdd checks (approval, red-first tasks, check
  per exact code, finish gate). No test: text.
- Deviations: none. Built by the main session directly (text only, three small tasks).
- Security pass: none needed beyond reading the diff myself: prompt and README text only, no
  code, input or dependency (only I looked).
- Follow-up: t_perf fails under heavy load (load average 12-16 from other sessions):
  `hook stop` measures 0.20 s against a 0.2 s budget even when idle machines give 0.15-0.17 s.
  Either make the stop hook cheaper or have t_perf retry once before failing; a later item.

## Review (optional)
<!-- The human's review notes: what to change, one per line. The agent works through them
and says under "## Built" what it changed for each. -->

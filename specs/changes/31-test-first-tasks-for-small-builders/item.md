---
id: 31
type: feature
title: Test-first tasks for small builders
status: open
created: 2026-10-29
approved: 6514d3a77bf21c4e619178e3fe7a932560e48457 2026-10-29 joexbayer
---
# 31 Test-first tasks for small builders

## Why
<!-- The problem in plain words: who hurts, and how. 2-4 lines. -->
narrow's spot run (2026-10-29: Opus planned, qwen built): the app worked and the check passed,
but 0 of 6 tasks were ticked. qwen wrote each test with its code, so the first test-first
`task done` refused ("passed: write the test first"); it then never ticked anything. Small
models do not follow a protocol from prompt text; the tool must run it (as TDD agent harnesses do).

## What changes
<!-- User-visible behaviour. One requirement per entry, each with a concrete example:
    US-31.1 As a <role> I <action>, so that <outcome>.
    FR-31.1 WHEN <trigger> THE SYSTEM SHALL <response>.
      e.g. <input> → <output>
Start each entry at the beginning of its line, ID first. IDs never change; leave gaps. -->
FR-31.1 WHEN `sdd run builder <id>` ends with the agent's exit accepted THE SYSTEM SHALL run
`task done` for each still-open task of that run's batch, in plan order, and commit each one it
ticks (all changes, message `<kind>(<id>): <task> <what>`), stopping at the first that fails and
printing its output; the run's result says how many it ticked.
  e.g. batch T-7.1 T-7.2, agent never ticks → "✓ T-7.1 done … committed", "✓ T-7.2 done … committed", "ticked 2 of 2"
  e.g. T-7.2's test fails → "✗ T-7.2: its test failed …", "ticked 1 of 2", exit 1
FR-31.2 WHEN `task done` runs on an `expect: fail` task whose test passes AND the working tree has
uncommitted changes outside that task's `files:` THE SYSTEM SHALL run the test once more in a
throwaway checkout of HEAD with only the task's files copied in, and accept it as red when it
fails there (for the reason the plan names, if any), without touching the working tree.
  e.g. qwen wrote tests/test_api.py and track/api.py together → "✓ T-7.1 done (its test fails without the uncommitted code)"
FR-31.3 WHEN that red check cannot prove it (the test passes there too, or the code is already
committed) THE SYSTEM SHALL refuse as today and name the way back.
  e.g. → "✗ T-7.1 expected its test to fail, but it passes even without the uncommitted code: the test does not test the change; fix the test"
  e.g. code committed → "✗ … it passed: the code is already committed, so sdd cannot see the test fail; …"

## Not in scope (optional)
<!-- What this deliberately leaves out, and where it went. -->
Splitting a test-first batch into two agent runs (test, then code): FR-31.2 proves red without it.
Interactive builders: they tick themselves as today (FR-31.1 is `sdd run` only).

## How
<!-- What a reviewer needs: an ASCII sketch of the moving parts, key types or signatures,
and the decisions they would question, each at the start of its line:
    D-31.1 <decision>, because <reason>. -->
D-31.1 The tool ticks, not the model: in a role run the batch's own tests decide; a model
forgetting `task done` costs nothing (FR-31.1). Ticks commit at once, so the ship gate's "a ticked
task needs a commit naming it" holds; `git add -A` relies on the project's .gitignore.
D-31.2 The red check runs in `git worktree add --detach <tmp> HEAD` plus the task's files, removed
afterwards (also on failure): the human's tree is never stashed or reset. A test needing
untracked setup (a venv) can fail there for the wrong reason; the plan's expected-reason text
(FR-22.1) guards that when given.
D-31.3 The red check only runs when needed (test passed and other files changed), so the common
path costs nothing extra.

## Security
<!-- Does this touch untrusted input, login or permissions, secrets or personal data, a new
dependency, files/network/shell, or CI/agent config? If not: "none: <why>". Otherwise, per risk:
what can go wrong → what we do (an FR with a test, a D line, or "accept: <why>").
    e.g. uploads are untrusted → FR-31.4 rejects non-images and files over 5 MB -->
Task tests are shell commands from the approved plan, run as today; the throwaway checkout is
under $TMPDIR and removed. Auto-commit could commit a secret the agent wrote → the project's check
(gitleaks in init) still runs before ship; accept: same as a builder committing it today.

## Questions (optional)
<!-- Q-31.1 <question> → recommend: <answer>. Resolve before building. -->

## Done when
<!-- DOD-31.1 <observable outcome>, e.g. "works against staging". -->
DOD-31.1 `sdd check` passes; t_task.sh / t_run.sh prove FR-31.1 to FR-31.3 with a fake builder
that writes test and code together and never ticks.

## Tasks (optional)
<!-- Small, ordered steps the builder does one at a time, each in one sitting, each with a test
of its own (so it can pass before the next task exists):
    - [ ] T-31.1 Page the orders query, FR-31.1 (files: src/orders.js; test: npm test -- orders; size: S)
Size each task `S`, `M` or `L` (none is M): consecutive S tasks go to one builder together, M and
L ones alone. Add `; expect: fail` for a test written first (it must fail), or
`; expect: fail "<text>"` (it must fail with that text in its output); without `test:` the
full check runs. `.sdd/bin/sdd task done T-31.1` ticks a task when its test passes. -->
- [x] T-31.1 Red check without the uncommitted code, FR-31.2, FR-31.3 (files: .sdd/core/cmd/task.sh, tests/t_expect.sh; test: SRC=$PWD SH=dash dash tests/t_expect.sh; size: M)
- [ ] T-31.2 sdd run builder ticks and commits its batch, FR-31.1 (files: .sdd/core/cmd/run.sh, tests/t_run.sh; test: SRC=$PWD SH=dash dash tests/t_run.sh; size: M)
- [ ] T-31.3 README, design, sdd-dev notes (files: README.md, specs/design.md, .claude/skills/sdd-dev/SKILL.md; size: S)

## Built
<!-- Written by the agent at the end of the build, for the review: per requirement what
changed (file:line) and which test proves it; deviations from the plan and why; follow-ups. -->

## Review (optional)
<!-- The human's review notes: what to change, one per line. The agent works through them
and says under "## Built" what it changed for each. -->

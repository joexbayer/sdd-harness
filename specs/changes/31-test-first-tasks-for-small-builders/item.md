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
`task done` for each still-open task of that run's batch, in plan order, stopping at the first
that fails and printing its output; it commits nothing (C-4): the run's result says how many it
ticked and the commit the orchestrator makes.
  e.g. batch T-7.1 T-7.2, agent never ticks → "✓ T-7.1 done …", "✓ T-7.2 done …", "ticked 2 of 2 · commit with: feat(7): T-7.1 T-7.2 <what>"
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
forgetting `task done` costs nothing (FR-31.1). The orchestrator (the session or script running
the build) commits, as C-4 keeps commits to new, approve and ship (the human's call, 2026-10-29);
an uncommitted tick is caught by ship's "a ticked task needs a commit naming it".
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
under $TMPDIR and removed. sdd commits nothing new (C-4).

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

QUESTION for the human (build stopped at T-31.2 (sdd run builder ticks and commits its batch)):
FR-31.1 says `sdd run` commits each tick, but constitution article C-4 (only new, approve and
ship create commits) forbids it, and `sdd check` enforces it (tests/constitution/c4-commits.sh
fails when any other cmd/ or lib/ file runs `git commit`). Changing C-4 needs an amendment item,
which only the human starts. Options:
- (a) An amendment first: C-4 gains "`run builder` commits the ticks of its own batch" and
  c4-commits.sh allows run.sh; item 31 then `depends:` on it and T-31.2 builds as planned.
- (b) Change FR-31.1 (re-approval): `sdd run` ticks but does not commit; the orchestrating
  session commits each tick. Keeps C-4, but a small builder's ticks wait for the orchestrator.
Recommend (a): the commit is the point of D-31.1 (the ship gate needs a commit per tick).

Done so far:
- FR-31.2 (red check without the uncommitted code): .sdd/core/cmd/task.sh:52-91
  (`red_without_code`, called at :129 only when an `expect: fail` test passed, D-31.3). Other
  changes = `git diff --name-only HEAD` plus untracked files, minus the task's files: (an entry
  also covers paths under it) and minus the item file. The throwaway checkout is
  `git worktree add --detach $TMPDIR/sdd-red.XXXXXX/wt HEAD`; the task's files are copied in
  with their paths, the test runs there with that dir as cwd, then the worktree is removed
  (`--force`) and the dir deleted; an EXIT trap does the same when a die stops it midway. Its log
  is `.git/sdd/checks/<id>.<task>.red.log`. Proved by tests/t_expect.sh:100-160 (FR-31.2: ticked
  with the plan's reason, refused for another reason, working tree and git status unchanged, no
  worktree or temp dir left).
- FR-31.3: refusals at task.sh:66-70 (no other changes: "the code is already committed (or there
  is none)") and :85-89 ("passes even without the uncommitted code … fix the test"); a red-check
  exit 126/127 is refused like the normal run's. Tests: t_expect.sh:121-129, :153-160.
- Deviation: the item file itself does not count as an "other change" (a Built edit is not
  code), so editing it alone gets the "already committed" refusal, not a red check.

Not handled (no code, per the no-speculative-complexity rule):
- A signal (Ctrl-C) during the red run leaves $TMPDIR/sdd-red.* and a stale worktree entry
  (dash runs no EXIT trap on a signal). Likelihood: low (a human interrupting a test). Cost of a
  fix: trapping INT/TERM/HUP too, 1 line. `git worktree prune` clears the entry.
- A files: entry with `..` (e.g. `../x`) is copied outside the throwaway checkout, still under
  $TMPDIR, and is not deleted with it. Likelihood: very low (files: comes from the approved plan).
  Cost: refusing `..` entries, ~2 lines.

Verified by: none (builder self-checked; the orchestrator verifies)

## Review (optional)
<!-- The human's review notes: what to change, one per line. The agent works through them
and says under "## Built" what it changed for each. -->

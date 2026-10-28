---
id: 22
type: feature
title: Stronger build verification
status: open
created: 2026-10-28
approved: dfa4699ca34676de9d607f8e7adc86fb1d6fc859 2026-10-28 joexbayer
---
# 22 Stronger build verification

## Why
A cheap builder's word is not proof. In item 17's trial qwen reported "successfully completed"
before verifying, and went past its task. Three gaps, each taken from pstack (kb:
specs/kb/pstack.md): a test-first task counts as red when it fails for any reason, even a typo;
nobody but the builder checks the build against the requirements; and code changed after the
human's review ships without another look.

## What changes
FR-22.1 WHEN a task says `expect: fail "<text>"` THE SYSTEM SHALL, in `task done`, accept the
red run only when its output contains that text (fixed string); plain `expect: fail` keeps
today's rule.
  e.g. `(test: sh test_wf.sh; expect: fail "wordfreq: not found")`, the test fails with "syntax
  error" → "✗ T-1.3 failed, but not for the expected reason (wordfreq: not found)", not ticked
FR-22.2 WHEN the build is verified and the check passes THE SYSTEM SHALL tell the main agent
(finish steps) to hand the item to the `verifier` role (its subagent, or `sdd run verifier`, or
a fresh subagent on another model when no role is set): it checks each FR by running something,
reports only findings with the command and its output, and the result goes under "## Built" as
`Verified by: <model>: <n> of <m> FRs proven; <findings or "no findings">`, or `Verified by: none`.
  e.g. "Verified by: claude-opus-5-5: 4 of 4 FRs proven; no findings"
FR-22.3 WHEN `sdd ship` runs THE SYSTEM SHALL apply a new gate `verified`: a "Verified by:" line
other than "none" under "## Built" (off in lite, warn in standard, block in strict); `sdd review`
shows the line.
  e.g. strict, "Verified by: none" → ship refuses, naming the gate
FR-22.4 WHEN the human runs `sdd review` THE SYSTEM SHALL record the fingerprint of the item's
code change (`git patch-id` of the diff from the merge base, specs/ left out), and `sdd ship`
SHALL apply a new gate `reviewed` when it differs or no record exists in this clone (warn in lite
and standard, block in strict), saying what changed since.
  e.g. review, then an agent edits src/a.js → ship: "code changed since your review (src/a.js):
  run sdd review"; a rebase onto a newer base keeps the same fingerprint → no warning

## Not in scope (optional)
Rules recording what enforces them, "Depends on" checks, the experiment's method (kb:
specs/kb/pstack.md, "later"). Several models racing on one task (cost).

## How
- `task.sh`: `expect` keeps `fail` and takes an optional quoted text; `task_rows` (item 17's
  grammar) carries it; `grep -F` on the red log.
- `prompts/finish.md` (item 21): the verifier step. `prompts/role-verifier.md`: what a verifier
  does (run, prove, report with output; never edit code or the plan).
- `review.sh` writes `.git/sdd/checks/<id>.reviewed` (`patch=<id>`, files); `ship.sh` gates
  `verified` and `reviewed`; `core/config` adds both gates and their levels.
D-22.1 The verifier is a role (item 16), so the project picks its model; the default prompt asks
for another model than the builder's, because a model checking its own work misses its own blind
spots.
D-22.2 The review record is per clone: a teammate's review shows in the PR's review state (item
10), which the forge gate already checks; strict teams get both.
D-22.3 A fixed string, not a regex: test output is full of regex characters, and a plain text is
what a planner writes.
D-22.4 Gate levels (lite/standard/strict): verified off/warn/block, reviewed warn/warn/block, so
lite stays light and strict proves everything.

## Security
- A builder writing its own "Verified by:" line → accept: the line names the model, `sdd usage`
  shows whether a verifier run happened, and the human reads it in review; the gate stops a
  missing step, not a forged one (same as D-21.1).
- The expected text goes to `grep -F` as an argument, never into a shell string.

## Done when
DOD-22.1 `sdd check` passes, with a test naming each FR, under /bin/sh and dash.
DOD-22.2 On a scratch repo, a qwen build verified by an Opus or Sonnet verifier writes a real
"Verified by:" line, and editing code after `sdd review` makes ship warn.

## Tasks (optional)
- [x] T-22.1 Expected failure text, FR-22.1 (files: .sdd/core/lib/common.sh, .sdd/core/cmd/task.sh, .sdd/core/prompts/plan.md, .sdd/core/templates/feature.md, tests/t_expect.sh; test: SH=/bin/sh SRC=$PWD sh tests/t_expect.sh; size: S)
- [x] T-22.2 Verifier step, role prompt and the verified gate, FR-22.2, FR-22.3 (files: .sdd/core/prompts/finish.md, .sdd/core/prompts/role-verifier.md, .sdd/core/cmd/ship.sh, .sdd/core/cmd/review.sh, .sdd/core/config, tests/t_verified.sh; test: SH=/bin/sh SRC=$PWD sh tests/t_verified.sh; size: M)
- [x] T-22.3 Review fingerprint and the reviewed gate, FR-22.4 (files: .sdd/core/cmd/review.sh, .sdd/core/cmd/ship.sh, .sdd/core/config, tests/t_reviewed.sh; test: SH=/bin/sh SRC=$PWD sh tests/t_reviewed.sh; size: M)
- [x] T-22.4 Help, design and README (files: .sdd/core/cmd/help.sh, specs/design.md, README.md; size: S)

## Built
<!-- Written by the agent at the end of the build, for the review: per requirement what
changed (file:line) and which test proves it; deviations from the plan and why; follow-ups. -->

**FR-22.1 (expected failure text).** `task_row` (.sdd/core/lib/common.sh:625) reads
`expect: fail "<text>"` into field 6 `fail` plus a new field 10 (the text); `fail` followed by
anything else is unreadable ("expect must be fail or fail \"<text>\""), so plan_findings/analyze
flag it and `task done` refuses it. `task done` (.sdd/core/cmd/task.sh:92-100) passes the text to
`grep -qF --` as an argument after the red run's other checks and refuses with "✗ T-n.m failed,
but not for the expected reason (<text>)". `sdd task`, `task next` (task.sh:23, :42) and `sdd
next` (next.sh:74) show the text. The plan prompt (prompts/plan.md:32) and feature template
(templates/feature.md:45) name the optional text. Test: tests/t_expect.sh (wrong reason not
ticked, right reason ticked, plain `expect: fail` unchanged, a passing test still refused, shell
syntax in the text never runs, the malformed form flagged by analyze).

**FR-22.2 (verifier step).** prompts/finish.md:10-18 (shown only once no task is open): hand the
item to the `verifier` role (its `sdd-verifier` subagent, `sdd run verifier <id>`, or a fresh
subagent on another model), with the `Verified by:` line format and the `none` fallback.
New prompts/role-verifier.md: run each FR's proof, report only findings with command and output,
never edit or commit, and do not do the build steps `next` prints or hand off to another
verifier. `install_subagents` (agents/claude.sh) already appends `prompts/role-<role>.md` to any
role's subagent, and `sdd run` appends it to the prompt, so nothing changed there. Test:
tests/t_verified.sh (finish text, the `sdd-verifier` subagent with the role prompt after `sync
claude`, `sdd run verifier 1` giving it to the agent).

**FR-22.3 (verified gate).** `verified_by` and `verified` (common.sh:299-311) find the last
`Verified by:` line in Built, ignoring guidance and a list bullet. A value that starts with
"none" counts as not verified, so "none (why)" is allowed. The ship gate is at ship.sh:194. The
gate is added to `sdd.gates` and the profiles (core/config: off/warn/block). `sdd review` prints
`verify  <the line>` or `Verified by: (missing)` (review.sh:35). Test: tests/t_verified.sh
(review shows missing/none/real; strict refuses missing and none, naming the gate, and ships with
a real line; standard warns and ships; lite does not mention it).

**FR-22.4 (reviewed gate).** `review_print` (common.sh:317) prints `patch=<git patch-id
--stable>` of `git diff --binary <merge-base> HEAD -- . ':(exclude)specs'`, the same merge base
review.sh uses, then `<blob>\t<path>` per changed file. `sdd review` writes it to
`.git/sdd/checks/<id>.reviewed` (review.sh:12). The ship gate (ship.sh:198-209) compares the
patch line and names the files whose post-change blob differs from the record. The gate is added
to `sdd.gates` and the profiles (warn/warn/block). Test: tests/t_reviewed.sh (strict refuses with
no record; an edit after review is refused naming src/a.js and not src/b.js, and an item-file
edit does not count; after a rebase onto a moved main the same change ships in strict; lite warns
and ships; a docs-only item is not asked).

**T-22.4.** help.sh (review line), specs/design.md (gate table: the "independent review" row
became the `verified` and `reviewed` rows; the task grammar row; a "Verifying" paragraph in §10),
README.md (task line and a "Verified, then reviewed" paragraph).

Deviations and choices:
- An item with no code diff (docs only) skips `reviewed`: nothing to have changed. This was the
  simplest option.
- The fingerprint is of HEAD, not the working tree. Code still uncommitted at review time and
  committed later makes ship warn. Ship needs a clean tree, so HEAD is what lands.
- `fail <anything>` other than the two forms is now an unreadable task (one awk line) instead of
  silently counting as a test that must pass. Other `expect:` values behave as before.
- The `Verified by:` line may be a list item (`- Verified by: …`), because agents write Built as
  bullets.
- next.sh is not in T-22.1's files but shows the expected text to the builder (4 lines).
- Amendments: `verified` and `reviewed` are pinned to block like the other gates (core/config
  [type "amendment"], decided in the main session after the build). tests/t_constitution.sh
  adds a verifier line before its amendment ships and checks that ship refuses without one.
- No existing test setup needed changing: no existing test ships in strict, and the warnings in
  lite/standard broke no assertion. t_verified.sh runs `sdd review` before its strict ship.

Follow-ups (for the human to decide):
- `sdd review` records whoever runs it, so an agent (or a role run) that runs review itself
  refreshes the record. Like the forged-line case under Security, this stops a forgotten step,
  not a deliberate one. Skipping the record under `SDD_RUN` would be a two-line change if wanted.
- DOD-22.2 (a real qwen build with an Opus/Sonnet verifier on a scratch repo) is left for the
  main session.

Review change (DOD-22.2 trial): qwen's first batch was T-1.1 (test first, `expect: fail "FAIL
slug"`), T-1.2 (the code) and T-1.3. It wrote both, the red run then passed, `task done` refused
T-1.1, and qwen thrashed (it even ran `git stash`, hiding its tick) until its 80-step limit.
`task_batch` (common.sh:638) now ends a batch after an `expect: fail` task, so its code is in the
next batch. Test: tests/t_expect.sh (a red first task runs alone; a red task ends a batch of S
tasks). README, design §9 and core/config say so.

Check: `.sdd/bin/sdd check` passed (shellcheck and the suite under /bin/sh and dash).
Security pass: a fresh subagent (Sonnet) given only the diff found nothing (it traced the expected
text to `grep -F` arguments and prints only; the review record path uses the numeric ID).

Verified by: claude-sonnet-5-5: 4 of 4 FRs proven; no findings

## Review (optional)
<!-- The human's review notes: what to change, one per line. The agent works through them
and says under "## Built" what it changed for each. -->
- A test written first must not share a batch with the code that makes it pass (found by the
  DOD-22.2 trial).

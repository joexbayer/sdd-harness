---
id: 19
type: feature
title: Plan analysis before approval
status: shipped
created: 2026-10-28
approved: 3bc502f1407ea689132848cde8178a9d551cec89 2026-10-28 joexbayer
shipped: 2026-10-28
---
# 19 Plan analysis before approval

## Why
A plan is approved after a read by eye, so gaps slip through: a requirement no task builds, a
task serving no requirement, an open question, a requirement with no example. The builder may
be a small model that sees one task at a time, so it cannot notice. Spec Kit has `/analyze`
and `/clarify` for this (research: Spec Kit vs sdd, 2026-10-28); sdd has nothing before review.

## What changes
US-19.1 As the human I see what is missing in a plan before I approve it, so that the builder
gets a complete one.
FR-19.1 WHEN `sdd analyze` runs on an item THE SYSTEM SHALL print one line per problem found in
the plan and exit 1, or say it found none and exit 0. Problems:
  an FR no task names (only when the plan has tasks); a task naming an FR the plan lacks; an FR
  line with no `e.g.` example under it; a Q line with no `→ decided`; an ID written twice; a
  task line the task grammar cannot read.
  e.g. FR-4.3 has no task, Q-4.1 has no decision → "✗ FR-4.3 (export as CSV): no task names it"
  and "✗ Q-4.1 (which date format?): not decided", exit 1
FR-19.2 WHEN the human runs `sdd approve` and the analysis finds problems THE SYSTEM SHALL
apply a new gate `analyzed`: warn in lite (print the problems, approve anyway), block in
standard and strict (print them, approve nothing, exit 1).
  e.g. standard profile, one open question → approve exits 1 naming Q-4.1
FR-19.3 WHEN `sdd next` runs in the plan phase and the plan is filled in THE SYSTEM SHALL add
the analysis problems to its step, so the agent fixes them before asking for approval.
  e.g. "Before asking for approval, fix: ✗ FR-4.3 (export as CSV): no task names it"
FR-19.4 WHEN an agent plans THE SYSTEM SHALL tell it (plan prompt) to check the plan for gaps
before asking for approval: scope edges, errors and edge cases, data and state, speed,
several developers at once, security; and to ask the human about each gap it finds.
  e.g. the plan step lists those six checks

## Not in scope (optional)
- Checking with a model that the plan makes sense: that stays with the human and the planner.
- More agent adapters (opencode, Cursor, Gemini): a later item when the experiment needs one.
- Unknown task attributes: item 17 (task batches) makes the task grammar refuse them; FR-19.1
  then reports them through the same "cannot read" check.

## How
`plan_findings` in common.sh: one awk pass over `plan_part` (comments and fences left out)
plus `task_rows`; prints `<id>\t<name>\t<problem>`. `cmd/analyze.sh` prints it; `approve.sh`
and the plan step of `next` call the same function. No new files under `.git/`.
D-19.1 Mechanical checks only, because they are fast, exact and the same for every agent; a
model's judgement of the plan is the planner's and the human's job.
D-19.2 A gate of its own rather than part of `planned`, because teams may want empty sections
to block but analysis only to warn, or the other way round.
D-19.3 Applied at approve, not at ship: an approved plan cannot change without re-approval,
so checking again at ship finds nothing new.

## Security
none: reads the item file only; no new input, dependency, command or network use.

## Questions (optional)
Q-19.1 Should the gate block in standard and strict, or only warn everywhere? → recommend:
block in standard and strict, warn in lite (this repo is lite, so it warns here). → decided: as recommended (joexbayer, 2026-10-28)

## Done when
DOD-19.1 `sdd analyze` on items 16, 17 and 18 in this repo gives a correct list (checked by hand).

## Tasks (optional)
- [x] T-19.1 `plan_findings` and `sdd analyze`, FR-19.1 (files: .sdd/core/lib/common.sh, .sdd/core/cmd/analyze.sh, .sdd/core/cmd/help.sh, tests/t_analyze.sh; test: SH=/bin/sh SRC=$PWD sh tests/t_analyze.sh; expect: fail)
- [x] T-19.2 Gate `analyzed` at approve, FR-19.2 (files: .sdd/core/config, .sdd/core/cmd/approve.sh, tests/t_analyze.sh; test: SH=/bin/sh SRC=$PWD sh tests/t_analyze.sh)
- [x] T-19.3 Findings in the plan step of next, gap checklist in the plan prompt, FR-19.3, FR-19.4 (files: .sdd/core/cmd/next.sh, .sdd/core/prompts/plan.md, tests/t_analyze.sh; test: SH=/bin/sh SRC=$PWD sh tests/t_analyze.sh)

## Built
<!-- Written by the agent at the end of the build, for the review: per requirement what
changed (file:line) and which test proves it; deviations from the plan and why; follow-ups. -->
- FR-19.1 (`sdd analyze`): `plan_findings` (.sdd/core/lib/common.sh:302-345) is one awk over
  parse_item's facts (comments and fences already out, wrapped lines grouped), with AWK_TASK for
  the task grammar; it prints `<id>\t<short name>\t<problem>` in plan order. `findings_lines`
  (common.sh:348) turns that into "✗ <id> (<name>): <problem>". The short name is the first six
  words of the text: an FR's after "SHALL", a question's up to its "?", a task's before its
  attributes. `cmd/analyze.sh` prints them and exits 1, or prints "✓ item <id>: no problems
  found in the plan" and exits 0; `sdd analyze <id>` reads another branch's or an archived item
  (same lookup as `show`). Listed in help.sh:13. Test: tests/t_analyze.sh:28-56 (the exact six
  lines for every kind of problem; a wrapped `→ decided`, a fenced FR and the template's
  commented FR are not problems; by id from main; no tasks → no "no task names it"; clean → 0).
- FR-19.2 (the `analyzed` gate): core/config:9 adds it to `sdd.gates`, with warn in lite, block in
  standard and strict (config:25,33,41). approve.sh:18-27 prints the findings and either dies
  (block: nothing approved, exit 1) or warns and approves. Test: t_analyze.sh:58-79 (standard
  blocks and leaves no `approved:`; lite warns and approves; a per-profile level wins).
- FR-19.3 (findings in `next`): next.sh:93-103, when the plan is filled in and waiting for
  approval (or re-approval), adds "Before asking for approval, fix:" and the findings, read from
  `IR_FACTS` (no second read of the item). Test: t_analyze.sh:81-97 (shown with a problem, gone
  when fixed, absent before the plan is filled and in the build phase).
- FR-19.4 (gap checklist): prompts/plan.md:32-35 lists scope edges, errors and edge cases, data
  and state, speed, several developers at once and security, says to ask the human about each
  gap, then to run `analyze`. Test: t_analyze.sh:99-105.
- DOD-19.1 (analyze on items 16, 17, 18, checked by hand against the files):
  - item 16: 5 lines, all "no e.g. example under it", for FR-16.2, 16.4, 16.6, 16.7, 16.8. Correct:
    those FRs have no `e.g.` line. Its Q-16.4, 16.5 and 16.7 are decided on wrapped lines and are
    rightly not listed; every FR is named by a task.
  - item 17: 1 line, "✗ FR-17.3 (show it the current batch in…): no e.g. example under it". Correct.
  - item 18: no problems. Correct: a refactor with no FR or Q lines, every task readable.
  - item 19 (this one): no problems.
- Verified: `.sdd/bin/sdd check` exit 0 (shellcheck, both suites under /bin/sh and dash).

Deviations:
- Task split: T-19.1 (expect: fail) and T-19.2 share one test file, and T-19.2 cannot touch
  common.sh. So T-19.1 built `plan_findings` and `analyze` and wrote the test for FR-19.1 and
  FR-19.2; it was red only on the FR-19.2 part, which T-19.2 made green. T-19.3 added the
  FR-19.3/19.4 part of the test with its code.
- Amendment items get `analyzed = block` (config:61): core/config says every gate blocks for
  them, in every profile. Spike, hotfix and chore list their own gates without it, so it is off
  for them (a spike's open questions are its point; hotfix and chore have no approve step).
- An extra "cannot read it" case: a task line whose ID is not `T-<item>.<n>` (e.g. `T-19.1:`),
  which task_rows drops silently, is reported as unreadable.
- tests/t_task.sh:92-94: its second item is approved, on purpose, with a task sdd cannot read
  (T-2.3) in standard, to test later refusals; the new gate blocked that approval. The test now
  sets `profile.standard.analyzed = warn` first (on main, before the item, so it is not code
  committed before approval). No assertion changed.

Security pass (fresh context, given only the diff and the tree): nothing exploitable. The id is
digits only; item text reaches awk only on stdin and prints via `%s`; the gate only adds checks
after `human_only`; findings carry nothing the item text does not already put in `next`.

Performance: `next` in the build phase gains only a `case`; the plan phase pays one awk. Under
load (average 15-18 from other sessions) two check runs failed t_perf on one budget each (`next`
0.23 s once, `hook stop` 0.20-0.21 s); `hook stop` does not run any new code. Main and this branch
timed in turn (t_perf, 3 rounds): next 0.13-0.16 vs 0.14-0.17 s, hook stop 0.18-0.20 vs 0.20-0.26
s, the same within noise. The final check passed with the default budgets.

Follow-ups (not built):
- `next` shows findings even when a team sets the gate to off. Failure mode: a nag the team
  turned off for approve; likely only for teams that opt out; cost: one `gate_level` call. Worth
  it only if someone asks.
- Short names are the first six words, which can cut mid-phrase ("write, kept out of git, a…").
  Cosmetic; a better name needs the planner to write one (e.g. an FR title), a template change.

## Review (optional)
<!-- The human's review notes: what to change, one per line. The agent works through them
and says under "## Built" what it changed for each. -->

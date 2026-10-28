---
id: 21
type: fix
title: Roles cannot ship, builders get only their batch
status: open
created: 2026-10-28
approved: bce8e80647ba8db0cc7140f7235fdfd707730ecd 2026-10-28 joexbayer
---
# 21 Roles cannot ship, builders get only their batch

## Current behaviour
Found in item 17's trial (DOD-17.2, scratch repo, builder = narrow + qwen via `sdd run builder`):
- The batch builder chained `git commit … && .sdd/bin/sdd ship` and shipped the item with a
  task open and "## Built" empty: lite only warns. Approve, ship and `tidy --remote` are
  human-only through Claude Code's ask rules alone; an agent `sdd run` starts is not stopped.
- In the task phase `next` prints the whole build prompt, finish steps included (full check,
  security pass in a fresh context, Built), so each batch builder ran a security subagent and
  the check: most of the trial's 930k tokens for three tiny tasks.
- `sdd usage <id>` misaligns rows whose task column is a batch ("T-1.1 T-1.2").

## Expected behaviour
FR-21.1 WHEN `sdd run` starts an agent THE SYSTEM SHALL set `SDD_RUN=<run number>` in that
agent's environment, and `approve`, `ship` and `tidy --remote` SHALL refuse while it is set
(exit 2), naming the human as the one who runs them.
  e.g. a builder runs `.sdd/bin/sdd ship` → "sdd: ship is the human's: a role run (run 3)
  cannot ship", exit 2, no commit
FR-21.2 WHEN `next` runs in the task phase (an open task) THE SYSTEM SHALL print the build rules
without the finish steps (full check, security pass, Built, hand-off to review); those appear
once no task is open, as today.
  e.g. phase "task T-4.1 of 3" → no "security pass"; phase "no passing check" → as today
FR-21.3 WHEN an agent builds THE SYSTEM SHALL tell it (build prompt) never to run approve, ship
or `tidy --remote`: they are the human's.
  e.g. the build rules list that line
FR-21.4 WHEN `sdd usage <id>` lists a batch THE SYSTEM SHALL keep the columns aligned, the task
column as wide as its widest entry.
  e.g. "T-1.1 T-1.2" and "T-1.3" rows line up

## Must not change
`next` with no open task, and for items without tasks, prints exactly what it prints today.
The human's approve, ship and `tidy --remote` (no `SDD_RUN`) work as today. Claude subagents
keep Claude Code's ask rules.
D-21.1 An environment variable, not a lock or a token: the builder is careless, not hostile
(it chained ship after a commit); anything it can set it could also unset, so this stops
mistakes, not attacks. Claude Code's ask rules stay the guard for the main agent.
D-21.2 The finish steps move to `prompts/finish.md` (shown in build when no task is open), so a
project's `local/prompts/build.md` keeps working.

## Security
Agents running human-only verbs → FR-21.1 (refused under `sdd run`), FR-21.3 (prompt). Accept:
an agent that deliberately unsets `SDD_RUN` is out of scope (D-21.1).

## Test
`tests/t_role_guard.sh`: a stub agent under `sdd run` calls approve, ship and `tidy --remote`
and is refused (FR-21.1); `next` in the task phase lacks the finish steps and has them once
tasks are done, and the build rules name the human-only verbs (FR-21.2, FR-21.3); `sdd usage 1`
with a batch row stays aligned (FR-21.4). It fails before the fix.

## Tasks (optional)
- [x] T-21.1 The regression test, FR-21.1, FR-21.2, FR-21.3, FR-21.4 (files: tests/t_role_guard.sh; test: SH=/bin/sh SRC=$PWD sh tests/t_role_guard.sh; expect: fail; size: S)
- [x] T-21.2 The fix: SDD_RUN set by run and refused by approve, ship and tidy --remote; finish steps only when no task is open; human-only verbs in the build rules; usage column width, FR-21.1, FR-21.2, FR-21.3, FR-21.4 (files: .sdd/core/cmd/run.sh, .sdd/core/cmd/approve.sh, .sdd/core/cmd/ship.sh, .sdd/core/cmd/tidy.sh, .sdd/core/lib/common.sh, .sdd/core/prompts/build.md, .sdd/core/prompts/finish.md, .sdd/core/cmd/next.sh, .sdd/core/cmd/usage.sh; test: SH=/bin/sh SRC=$PWD sh tests/t_role_guard.sh; size: M)

## Built
<!-- Written by the agent at the end of the build, for the review: per requirement what
changed (file:line) and which test proves it; deviations from the plan and why; follow-ups. -->
FR-21.1 (roles cannot approve, ship or tidy --remote): `sdd run` exports `SDD_RUN=<run>` just
before the agent starts (.sdd/core/cmd/run.sh:55-57). One helper, `human_only`
(.sdd/core/lib/common.sh:19-27), refuses with exit 2: "sdd: ship is the human's: a role run
(run 3) cannot ship". Called first thing by approve (cmd/approve.sh:6) and ship (cmd/ship.sh:8),
and by tidy only with --remote (cmd/tidy.sh:15), all before any repo work. Proof:
tests/t_role_guard.sh (FR-21.1 block): a stub narrow agent under `sdd run builder` sees
SDD_RUN=1, and all three verbs exit 2 with the message, no commit and still on the item branch;
plain `tidy --dry-run` still works under SDD_RUN. The human's verbs (no SDD_RUN) are unchanged:
t_ship.sh, t_tidy.sh and t_phase.sh pass untouched.
FR-21.2 (finish steps only once no task is open): the security-pass and "You are done when"
paragraphs moved verbatim from prompts/build.md to the new .sdd/core/prompts/finish.md;
`next` prints finish.md right after build.md (before build's .append.md) unless the phase is a
task (.sdd/core/cmd/next.sh:11-15). Proof: t_role_guard.sh (FR-21.2 blocks): the batch phase has
no "security pass" or "You are done when"; after `task done` on every task both are back.
Byte-identity: I ran `next` with main's `.sdd/` and with this branch's in one scratch repo for 8
states (no item, plan, build without tasks, build with build.append.md, fix without tasks, task
open, all tasks done, Built written) and diffed. The only difference with no open task is the
one FR-21.3 line; with a task open, also the finish steps removed.
FR-21.3 (the build rules name the human-only verbs): one rule line in
.sdd/core/prompts/build.md:11. Proof: t_role_guard.sh (FR-21.3 block, and again after the tasks).
FR-21.4 (usage stays aligned): the task column is as wide as its widest entry, minimum 8, header
too (.sdd/core/cmd/usage.sh:46-50, used at :33). Proof: t_role_guard.sh (FR-21.4 block): the
batch row "T-1.1 T-1.2" and a "T-1.3" row line up, all rows one width. tests/t_usage.sh passes
unchanged.

Deviations:
- tests/lib.sh:8-9 now `unset SDD_RUN` (not in the task's file list). Without it, a builder
  started by `sdd run` that runs `sdd check` in this repo would fail t_ship.sh and others, since
  their approve and ship would refuse (confirmed: `SDD_RUN=3 sh tests/t_ship.sh` failed with
  "approve failed" before this line). No test was weakened.
- "Must not change" says `next` with no open task prints exactly what it prints today; FR-21.3
  adds one line to the build rules, so it gains that line and nothing else (see the diff above).
- With usage tracking off a run has no number (`RUN` is "-"), so SDD_RUN is "-" and the message
  says just "a role run cannot ship" (common.sh:24-25; tested in t_role_guard.sh).

Check: `.sdd/bin/sdd check` passed (exit 0). An earlier run failed only in t_perf.sh with load
average ~20 (other sessions); old vs new timed in turn in one perf repo showed no slowdown
(next 0.26/0.13 s old vs 0.16/0.13 s new), and the rerun passed.

Security pass (a fresh subagent given only the diff): no findings. The awk format string holds
only the numeric width (task text is a printf argument), SDD_RUN is printed with `%s`, and
finish.md is rendered like every other prompt. An agent that unsets SDD_RUN is out of scope
(D-21.1).

Follow-ups:
- A project with its own `local/prompts/build.md` copied from the old core still has the finish
  steps in it, so its batch builders get them twice once no task is open, and still get them in
  the task phase. Worth a line in the upgrade notes.
- `sdd run` inside a role run (nested) is not refused; not in this plan.

## Review (optional)
<!-- The human's review notes: what to change, one per line. The agent works through them
and says under "## Built" what it changed for each. -->

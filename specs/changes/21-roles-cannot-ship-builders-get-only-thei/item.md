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

## Review (optional)
<!-- The human's review notes: what to change, one per line. The agent works through them
and says under "## Built" what it changed for each. -->

---
id: 67
type: fix
title: A recorded waiver when a task can't be ticked
status: open
created: 2026-11-08
approved: 7c5f6d917f4a7a2d99d280b349a515a60ada0547 2026-11-08 joexbayer
---
# 67 A recorded waiver when a task can't be ticked

## Current behaviour
From a 10-task feature in Lith:
1. A planner wrote `files: tests/x.lith, .args, .codes` (meaning `tests/x.args`). `analyze` accepted it, `task done` refused ("`.args` does not exist").
2. A test-first task can't go red again once its code exists, and a test that goes green when the next task lands can't be ticked afterwards. So the agent ticked by hand; `ship` refused six tasks a day later, and the owner edited `.git/sdd/checks/8.tasks` by hand. No prompt says not to tick by hand, and there is no sanctioned way out.
3. `finish.md` allows `Verified by: none`, which `ship` refuses where the `verified` gate blocks.

## Expected behaviour
FR-67.1 WHEN the human runs `sdd task waive <T-id> "<reason>"` THE SYSTEM SHALL tick the box and record the reason, who and when under a `## Waived` section of the item.
  e.g. `sdd task waive T-8.3 "files: had a typo; test passes on main"` → `- T-8.3: files: had a typo; test passes on main (joe, 2026-11-08)`; no commit (C-4)
FR-67.2 WHEN a task has a waiver THE SYSTEM SHALL let `ship` accept it without a receipt or a commit naming it.
  e.g. six waived tasks → ship goes on; an unwaived hand-tick is still refused
FR-67.3 WHEN an item has waivers THE SYSTEM SHALL show them in `sdd review`.
  e.g. `waived  T-8.3: files: had a typo; test passes on main (joe, 2026-11-08)`
FR-67.4 WHEN `task waive` has no reason, an unknown task, or a reason with a newline THE SYSTEM SHALL refuse it.
  e.g. `sdd task waive T-8.3 ""` → `a waiver needs a reason`, exit 1
FR-67.5 WHEN Claude Code is synced THE SYSTEM SHALL ask the human before `task waive` runs, and the build prompt SHALL say it is the human's.
  e.g. `Bash(sdd task waive:*)` in the ask rules
FR-67.6 WHEN `task done` cannot work THE SYSTEM SHALL tell the builder never to tick by hand: stop and ask the human.
  e.g. build.md says so
FR-67.7 WHEN `analyze` runs on the current item and a `files:` entry starts with a dot, has no folder, is not on disk, and another entry in that list has a folder THE SYSTEM SHALL warn, without failing.
  e.g. `tests/x.lith, .args` → `warn: T-8.1 files: .args looks like a suffix, not a path`; exit 0
FR-67.8 WHEN the prompt describes `Verified by: none` THE SYSTEM SHALL say ship refuses it where the `verified` gate blocks.
  e.g. finish.md

How: `task.sh` a `waive` branch; `common.sh` `waived <T-id>`, reading `## Waived`; `ship.sh` skips waived tasks in `unproven` and `byhand`; `review.sh` lists them; `analyze.sh` a loop over `task_rows`' files, only with no `<id>`; `claude.sh` ask rules; `help.sh`, README commands.
D-67.1 `## Waived` below `## Built`: the plan hash stays, and a waiver must not make `## Built` look written. In the item, not `.git/sdd/`: teammates and the review see it.
D-67.2 Warn in `analyze` only, not a plan finding: findings block `approve` under stricter profiles, and a new dotfile in a plan is legal.
D-67.3 No waiver for a whole item or for the check: only single tasks.

## Must not change
- A hand-tick with no waiver is still refused at ship; `task done` as today; the plan hash ignores boxes; `## Built` is not counted as written by a waiver.

## Security
An agent can edit the item and write a waiver line itself, as it can append to the receipts file today. The control is the human: the ask rule stops `task waive` running unseen, and every waiver, however written, is shown in `sdd review`. The reason is printed, never run.

## Test
`tests/t_task.sh` (FR-67.1, 67.4, 67.7), `tests/t_ship.sh` or nearest (FR-67.2, and an unwaived hand-tick still refused), `t_review` or nearest (FR-67.3), `t_agents.sh` (FR-67.5), `t_prompts_tests.sh` (FR-67.6, 67.8). Written first, seen to fail.

## Built
<!-- Written by the agent at the end of the build, for the review: per requirement what
changed (file:line) and which test proves it; deviations from the plan and why; follow-ups. -->

## Review (optional)
<!-- The human's review notes: what to change, one per line. The agent works through them
and says under "## Built" what it changed for each. -->

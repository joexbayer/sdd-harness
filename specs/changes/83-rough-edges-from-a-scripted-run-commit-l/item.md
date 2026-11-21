---
id: 83
type: fix
title: Rough edges from a scripted run: commit line, lost reports, vague gates, hidden check output
status: open
created: 2026-11-21
approved: 4a39cf121810a317a9486ef1a540c2008a030937 2026-11-21 joexbayer
---
# 83 Rough edges from a scripted run: commit line, lost reports, vague gates, hidden check output

## Current behaviour
A scripted live run (one agent as lead and verifier, another as builder, Claude Code orchestrating) hit five rough edges in sdd 0.1.5:
- `sdd run` ticks tasks but commits nothing (C-4: only new, approve and ship commit). Its "commit with: …" sits mid-line, and its last line says `next  sdd next`. Two batches' code and ticks stayed uncommitted; review later warned that no commit names T-1.5, T-1.6, and ship refused.
- With `[usage] track = false` (the default) a run's output folder is deleted after it passes, so a verifier's report was lost ($0.74 to run it again).
- Ship's "code was committed before the plan was approved (3f2a1c9)" names commits, not files: the file was `.sdd/local/prompts/role-lead.md`.
- A `[check]` change carried onto an item branch is refused only at ship (item 75).
- A failed `check` prints the log's last 40 lines. When an early command fails (shellcheck), its output is above those lines and never shown: item 81 spent three check runs on it.

## Expected behaviour
FR-83.1 WHEN `sdd run` ticks tasks THE SYSTEM SHALL end with the commit as its `next` line.
  e.g. builder ticks T-1.5, T-1.6 → last line `next    git add -A && git commit -m "feat(1): T-1.5 T-1.6 Sort it, Count it"`
FR-83.2 WHEN usage tracking is off THE SYSTEM SHALL keep the last run's output in `.git/sdd/runs/last/` (replacing the one before) and print where it is.
  e.g. `sdd run verifier 1` with track off → `output  .git/sdd/runs/last/` and the report is still there afterwards
FR-83.3 WHEN ship refuses code committed before approval THE SYSTEM SHALL name the files, up to 5.
  e.g. `code was committed before the plan was approved (3f2a1c9: .sdd/local/prompts/role-lead.md)`
FR-83.4 WHEN `approve` runs on a branch whose `[check]` differs from the base THE SYSTEM SHALL warn, as review does (item 75's check_edited); it still approves.
  e.g. a feature branch changing check.run → `⚠ item 1: changes the check that judges it (check.run): change [check] in a chore`
FR-83.5 WHEN `check` fails THE SYSTEM SHALL print each failed command with the last 40 lines of its own output, not the log's tail.
  e.g. shellcheck fails, the tests pass → `$ shellcheck …`, its warning, `[exit 1]` are shown

## Must not change
- No sdd verb but new, approve and ship commits (C-4): FR-83.1 prints the command, it does not run it.
- With tracking on, runs keep their numbered folders as today.
- Ship still refuses early code and a `[check]` change; approve only warns.

## Security
Standards: none
none: output text, one kept folder under .git/sdd; no input crosses a trust boundary.

## Test
- t_run.sh: the last line after ticking (FR-83.1).
- t_usage_off.sh: `runs/last/` kept and printed (FR-83.2).
- t_ship.sh: the early-code message names the file (FR-83.3); approve's warning (FR-83.4).
- t_check.sh: a failing first command's output shown when later commands pass (FR-83.5).

## Tasks
- [x] T-83.1 Failing tests for FR-83.1 to FR-83.5 (files: tests/t_run.sh, tests/t_usage_off.sh, tests/t_ship.sh, tests/t_check.sh; test: for t in run usage_off ship check; do SRC=$PWD SH=dash dash tests/t_$t.sh || exit 1; done; expect: fail; size: S)
- [x] T-83.2 run: commit as the next line, keep runs/last, FR-83.1 FR-83.2 (files: .sdd/core/cmd/run.sh, .sdd/core/lib/common.sh; test: for t in run usage_off; do SRC=$PWD SH=dash dash tests/t_$t.sh || exit 1; done; size: S)
- [x] T-83.3 ship names the files; approve warns on [check], FR-83.3 FR-83.4 (files: .sdd/core/cmd/ship.sh, .sdd/core/cmd/approve.sh; test: SRC=$PWD SH=dash dash tests/t_ship.sh; size: S)
- [ ] T-83.4 check prints each failed command's output, FR-83.5 (files: .sdd/core/cmd/check.sh, .sdd/core/lib/common.sh; test: SRC=$PWD SH=dash dash tests/t_check.sh; size: S)

## Built
<!-- Written by the agent at the end of the build, for the review: per requirement what
changed (file:line) and which test proves it; deviations from the plan and why; follow-ups. -->

## Review (optional)
<!-- What to change, one per line (the agent writes what the human asks). The agent works through them
and says under "## Built" what it changed for each. -->

---
id: 88
type: fix
title: Gates fail open when a gate_level subshell crashes
status: open
created: 2026-11-27
approved: b69f646648dd505a1d68103bd60c8cdec3a1cd7e 2026-11-27 joexbayer
---
# 88 Gates fail open when a gate_level subshell crashes

## Current behaviour
Three gate checks read `$(gate_level …)` and treat anything but "block" as "not blocking". When the
subshell dies (macOS /bin/dash segfaulted 5 times since 2026-11-25 under load), its output is empty and
the gate opens:
- common.sh:428 approval_current: `[ "$(gate_level approved …)" = block ] || return 0` → an unapproved
  plan reads as approved; seen in chore 87's check: t_analyze showed a new item 3 in phase build.
- task.sh:171: `!= block ] || approval_ok` → a task's test command (shell from the item) runs unapproved (FR-68.8).
- ship.sh:49 gate(): an empty level warns instead of blocking.

## Expected behaviour
FR-88.1 WHEN a gate level is empty or unknown THE SYSTEM SHALL treat it as block in approval_current,
task done and ship's gate().
  e.g. gate_level prints nothing → next says "waiting for the human to approve"; task done refuses; ship fails

## Must not change
Levels off, warn and block behave as today; no extra process per call.

## Security
approval gates task test commands (FR-68.8) → FR-88.1 closes them on a crashed subshell.

## Test
One helper in common.sh, `gate_blocks <gate> <type>`: true unless the level is off or warn (so empty
blocks); approval_current and task.sh use it; ship's gate() switches to a case with block as the default.
tests/t_frontmatter.sh style (source common.sh): stub gate_level() { :; } (a crashed subshell) and
assert gate_blocks succeeds and approval_current fails; off and warn still pass.

## Tasks
- [x] T-88.1 A failing test: gate_blocks and approval_current with an empty gate level, FR-88.1 (files: tests/t_frontmatter.sh; test: SRC=$PWD SH=dash dash tests/t_frontmatter.sh; expect: fail; size: S)
- [x] T-88.2 Read empty or unknown levels as block at the three places, FR-88.1 (files: .sdd/core/lib/common.sh, .sdd/core/cmd/task.sh, .sdd/core/cmd/ship.sh; test: SRC=$PWD SH=dash dash tests/t_frontmatter.sh; size: S)

## Built
- FR-88.1: common.sh gate_blocks (after gate_level): true unless off or warn, so an empty level blocks;
  approval_current and task.sh use it; ship.sh gate() is a case with fail as the default.
  Tests: t_frontmatter.sh (stubbed empty gate_level: gate_blocks blocks, approval_current refuses; off,
  warn pass), t_task.sh and t_ship.sh (an unknown approved level: task done refuses and its test does
  not run; ship fails "not approved"). Reverting task.sh or ship.sh to main fails those tests.
- No extra process: gate_blocks is a function with the same one gate_level call.
- Verifier fixes: the task done and ship parts had no test (now t_task, t_ship).
- Follow-up (nit, outside the plan's three places): approve.sh:42 the analyzed gate still warns on an
  empty level; low risk, the human sees the problems printed.
- Security: approval gates a task's test command (FR-68.8); it now fails closed.
- Verified by: Opus 5.5 at 468d1af: 0 of 1 FRs proven; FR-88.1 task done and ship gate() parts work when run by hand but no test fails when they are reverted (should-fix); approve.sh:42 analyzed gate still fails open (nit)

## Review (optional)
<!-- What to change, one per line (the agent writes what the human asks). The agent works through them
and says under "## Built" what it changed for each. -->

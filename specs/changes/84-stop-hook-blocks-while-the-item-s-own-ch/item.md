---
id: 84
type: fix
title: Stop hook blocks while the item's own check is still running
status: open
created: 2026-11-22
---
# 84 Stop hook blocks while the item's own check is still running

## Current behaviour
An agent that starts `sdd check` in the background (it takes minutes) and ends its turn to wait is blocked by the stop hook: "has changes no check has passed. Run sdd check." It then spends a turn on a large context saying it is waiting, and is blocked again. In NarrowBot's sessions about 11 of 16 stop-hook refusals came while the agent waited on its own check or verifier (items 14, 16, 20, 21, 23, 30, 38).

## Expected behaviour
FR-84.1 WHEN the stop hook would block AND a `sdd check` for this item is still running in this clone THE SYSTEM SHALL warn instead, naming the running check.
  e.g. check running with pid 4242 → stop allowed with `sdd: the check for item 3 is still running (pid 4242); run sdd next when it ends`
FR-84.2 WHEN a check ended without cleaning up (killed, crashed) THE SYSTEM SHALL ignore its leftover mark.
  e.g. mark names a pid that is gone → the hook blocks as before

## Must not change
- With no check running, the stop hook blocks exactly as today.
- Planning and review phases, and role runs, are judged as today.

## How
```
run_check   echo $$ >"$ST/checks/<id>.running"  …  rm -f it when the commands are done (pass or fail)
hook stop   [ level = block ] && pid=$(cat <id>.running) && kill -0 "$pid"  →  level=warn, msg names it
```
D-84.1 A pid file per item, checked with `kill -0`, not a lock: the hook only needs "is it alive", and a stale file costs nothing.
D-84.2 Only sdd's own check: subagents (verifier, security pass) are not tracked. Seeing them needs a hook on every subagent, and only Claude Code has one; the agent's background-task notice already wakes it when they end.

## Security
Standards: none
none: a pid file under .git/sdd; `kill -0` sends no signal.

## Test
t_agents.sh (stop hook cases): a live `.running` pid (the test's own background `sleep`) turns the block into a warning; a dead pid blocks as before.

## Tasks
- [ ] T-84.1 Failing test: live pid warns, dead pid blocks, FR-84.1 FR-84.2 (files: tests/t_agents.sh; test: SRC=$PWD SH=dash dash tests/t_agents.sh; expect: fail; size: S)
- [ ] T-84.2 run_check writes and removes the mark; the stop hook reads it, FR-84.1 FR-84.2 (files: .sdd/core/lib/common.sh, .sdd/core/cmd/hook.sh; test: for t in agents check verified; do SRC=$PWD SH=dash dash tests/t_$t.sh || exit 1; done; size: S)

## Built
<!-- Written by the agent at the end of the build, for the review: per requirement what
changed (file:line) and which test proves it; deviations from the plan and why; follow-ups. -->

## Review (optional)
<!-- What to change, one per line (the agent writes what the human asks). The agent works through them
and says under "## Built" what it changed for each. -->

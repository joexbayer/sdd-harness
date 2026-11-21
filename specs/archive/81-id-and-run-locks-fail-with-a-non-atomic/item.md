---
id: 81
type: fix
title: ID and run locks fail with a non-atomic mkdir (uutils)
status: shipped
created: 2026-11-21
approved: 69bdd42606966b7e04c8d995bbeaade3f7f24007 2026-11-21 joexbayer
shipped: 2026-11-21
---
# 81 ID and run locks fail with a non-atomic mkdir (uutils)

## Current behaviour
sdd locks by `mkdir`: the id lock (`next_id`, `.git/sdd/lock`) and the run folder (`run_slot`, `.git/sdd/runs/<n>`). Ubuntu 26.04 (GitHub's ubuntu-latest) ships uutils coreutils 0.10.0, whose `mkdir` is not atomic: two processes creating one directory both succeed (278 of 300 tries in an ubuntu:26.04 container). Two parallel `sdd new` then take the same id: t_new fails on CI with "expected [4 5], got [4]", and the loser dies with "could not create worktree …/.worktrees/4". Two parallel `sdd run` can share a run folder.

## Expected behaviour
FR-81.1 WHEN two `sdd new` run at once THE SYSTEM SHALL give them different ids, also where `mkdir` succeeds on an existing directory.
  e.g. lock held while `new` starts, then released after another process took id 7 → `new` waits, then takes 8
FR-81.2 WHEN two `sdd run` start at once THE SYSTEM SHALL give each its own run folder, also where `mkdir` succeeds on an existing directory.
  e.g. `.git/sdd/runs/1/` already exists → the next run gets `runs/2/`

## Must not change
- Run folders from before keep their numbers; none is reused.
- The busy message after about 10 s: `id lock busy: <path> (remove it if no sdd is running)`.

## How
```
next_id    until (set -C; : >"$_lock") 2>/dev/null; do … done   …   rm -f "$_lock"      (was mkdir/rmdir)
run_slot   while ! { [ ! -e "$d" ] && mkdir -p "$d" && (set -C; : >"$d/.claim") 2>/dev/null; }; do RUN=$((RUN + 1)); done
```
D-81.1 The shell's noclobber redirect is the lock: the shell opens with O_EXCL itself, so it does not depend on which coreutils is installed (0 of 300 double claims under dash and busybox in ubuntu:26.04).
D-81.2 A run folder that exists is skipped before the claim, so folders from before this fix (no `.claim`) are never reused.

## Security
Standards: none
none: local lock files under .git/sdd; no input crosses a trust boundary.

## Test
t_new.sh and t_run.sh (or t_agent_usage.sh, wherever run folders are tested), with a `mkdir` on PATH that succeeds on an existing directory (`exec /bin/mkdir -p "$@"`, as uutils behaves): FR-81.1 holds the lock as a directory, starts `new`, writes next-id 7 after 2 s, releases, and expects id 8; FR-81.2 pre-creates `runs/1/` and expects `runs/2/`.

## Tasks
- [x] T-81.1 Failing tests with the non-atomic mkdir shim, FR-81.1 FR-81.2 (files: tests/t_new.sh, tests/t_run.sh, tests/t_agent_usage.sh; test: for t in new run agent_usage; do SRC=$PWD SH=dash dash tests/t_$t.sh || exit 1; done; expect: fail; size: S)
- [x] T-81.2 next_id and run_slot claim with noclobber, FR-81.1 FR-81.2 (files: .sdd/core/lib/common.sh; test: for t in new run agent_usage; do SRC=$PWD SH=dash dash tests/t_$t.sh || exit 1; done; size: S)

## Built
FR-81.1 `next_id` locks with a noclobber file: .sdd/core/lib/common.sh:926 (until), :939 (rm -f). Proved by tests/t_new.sh "FR-81.1" (fake uutils mkdir on PATH, lock held, next-id set to 70 after 2 s, `new` takes 71).
FR-81.2 `run_slot` skips an existing run folder, then claims with `.claim`: .sdd/core/lib/common.sh:1272. Proved by tests/t_run.sh "FR-81.2" (runs/2 pre-created, fake mkdir; the next run is 3).

Deviations
- Test ids differ from the plan's example: 70 then 71 (not 7 then 8), as the repo is already at id 15 by then.
- FR-81.2 extends the existing failed-planner run in t_run.sh (expects run 3 instead of 2); t_agent_usage.sh is unchanged.
- The first full check failed only on server tests (no node_modules in the worktree); after `npm ci` in server/, all pass.
- Nothing lists or cleans run folders, so `.claim` trips nothing (the usage-off folder is a temp dir without it).

Follow-ups: none.

Verified by: claude-opus-5-5: 2 of 2 FRs proven; should-fix: no test of two parallel runs (fixed); nit on the FR-81.1 fixture (no change: the parallel test in t_new catches a missing set -C)
Verifier fix: t_run.sh starts three runs at once with the uutils-like mkdir and expects three different run numbers; dropping the `.claim` fails it (3 of 3 tries). Also checked in an ubuntu:26.04 container (uutils mkdir 0.10.0): 15 pairs of parallel `new --worktree`, 0 duplicate ids. Pre-existing, not changed: run_slot loops without end if mkdir fails for another reason (no permission, disk full), as before.

## Review (optional)
<!-- What to change, one per line (the agent writes what the human asks). The agent works through them
and says under "## Built" what it changed for each. -->

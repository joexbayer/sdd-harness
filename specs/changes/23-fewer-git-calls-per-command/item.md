---
id: 23
type: refactor
title: Fewer git calls per command
status: open
created: 2026-10-28
---
# 23 Fewer git calls per command

## Goal
`sdd hook stop` runs every time an agent stops, and `next`/`status` run constantly. Each git
call costs 15-28 ms on a loaded machine; hook stop makes 9 (plus jq twice), so it measures
0.20-0.26 s against its 0.2 s budget and fails the check whenever other sessions load the
machine (all of 2026-10-28). Cut the git calls on these paths, so hook stop has headroom and
every command gets faster:
- one `git rev-parse` per command, not two (the entry script's and find_repo's), and it also
  gives the worktree's git dir;
- the parsed config (CFG_TAB, today two `git config --list` calls per command) cached per
  worktree in `<git dir>/sdd-config`, rebuilt when any config file is newer than it or the set
  of config paths changed;
- the current branch read from `<git dir>/HEAD` instead of `git symbolic-ref`;
- code_changed: `git diff --name-only --merge-base <base>` (one call instead of merge-base +
  diff; falls back to the two calls on git older than 2.30), and the untracked-files listing
  only when the diff shows no code change;
- the plan hash (approval) cached per worktree in `<git dir>/sdd-plan`, keyed by the item path,
  reused while the cache file is newer than the item file;
- the entry script's `dirname` replaced by parameter expansion.

## Invariants
Every command prints and exits as before; the existing tests stay as they are and prove it
(they edit config and plans many times a second, so they exercise the cache rebuilds).
- A config edit or plan edit is seen by the very next command, even in the same second: a
  cache counts only when it is strictly newer than the file (`test -nt`), so an edit in the
  second the cache was written rebuilds it.
- Detached HEAD, a worktree, and a repo whose HEAD file does not name a branch (reftable)
  behave as now (the last falls back to `git symbolic-ref`).
- Accepted risk: a config or item file replaced by an older copy with its old mtime kept
  (`cp -p`, `touch -d`) is not noticed until it changes again. git checkout, editors and sdd
  itself always write the current time.

## How
D-23.1 Caches live in the worktree's own git dir, not `.git/sdd` (shared by all worktrees),
because each worktree has its own `.sdd/config` and item file.
D-23.2 The config cache is a file the shell sources (`CFG_TAB='…'`), so a hit runs no process.
D-23.3 A test counts git calls (a `git` wrapper first on PATH that logs each call): hook stop
mid-build makes at most 3, and `next` and `status` fewer than today. Counts do not depend on
machine load, so they catch a regression the timing test misses.

## Security
none: caches in the repo's own git dir hold what sdd already reads from files there; an agent
that can write them can already edit the config and the approval line in the item itself.

## Done when
DOD-23.1 `sdd check` passes under /bin/sh and dash with the unchanged suite plus the git-count
test.
DOD-23.2 hook stop in the t_perf repo measures under 0.12 s on this machine at load ~10.

## Built
<!-- Written by the agent at the end of the build, for the review: per requirement what
changed (file:line) and which test proves it; deviations from the plan and why; follow-ups. -->

## Review (optional)
<!-- The human's review notes: what to change, one per line. The agent works through them
and says under "## Built" what it changed for each. -->

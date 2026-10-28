---
id: 23
type: refactor
title: Fewer git calls per command
status: shipped
created: 2026-10-28
approved: 9d43500160e0f00618d8a41bd7cf31ee74e1f9ed 2026-10-28 joexbayer
shipped: 2026-10-28
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
Git processes per command (tests/t_gitcalls.sh, a logging `git` first on PATH): hook stop
mid-build 9 → 2 (rev-parse, one diff), next 6 → 1, status 6 → 1. Time in the t_perf repo (100
items, load average ~12, best of 5, dash): hook stop 0.16 → 0.07 s, next 0.12 → 0.05 s, status
0.09 → 0.03 s (DOD-23.2).
- One rev-parse: .sdd/bin/sdd:22 asks for root, common dir and git dir at once (RP);
  find_repo (common.sh:40) reuses it while PWD is the same and sets GD. `dirname` became
  parameter expansion (bin/sdd:12).
- Config cache: cfg_load (common.sh:85) sources `<git dir>/sdd-config` while cfg_fresh finds it
  strictly newer than every config file and CFG_KEY (the three paths, each marked present or
  absent) matches; else it reads as before and rewrites the cache (temp file + mv, values
  single-quote escaped). `$(user_config)` subshells became a variable.
- current_branch (common.sh:436) reads `<git dir>/HEAD` while PWD = ROOT; detached is no branch;
  `refs/heads/.invalid` (reftable) and other refs fall back to `git symbolic-ref`.
- code_changed (common.sh:526): `git diff --name-only --merge-base <base>`, falling back to
  merge-base + diff; the untracked listing runs only when no tracked file outside specs/ changed.
- plan_hash (common.sh:327): `<git dir>/sdd-plan` holds "<file> <hash>" for one item, used while
  strictly newer than the file; paths with spaces are not cached.
Tests: the unchanged suite, plus tests/t_gitcalls.sh: the limits above, and that a config edit,
a user config appearing and going, a plan edit, a branch switch and a detached HEAD are each seen
by the very next command. Breaking either freshness test (cache always fresh) fails it.
Reftable: checked by hand (`git init --ref-format=reftable`: HEAD reads `refs/heads/.invalid`,
next finds the item on its branch and none on main), not in the suite (needs git 2.45+).
Deviation: none from the plan. Not done: the review-phase fingerprint (temp index, 4 git calls)
still runs when a check was recorded; hook stop in review costs ~6 git calls.
Accepted risks (as planned): a file replaced by an older copy keeping its mtime; a config edit
landing in the milliseconds between another sdd process reading the config and writing its cache.
security pass: a fresh Sonnet verifier put single quotes, `$(…)`, backticks, backslashes and a
multi-line `'; touch …; '` value in the config and in the XDG path; nothing ran, under sh and dash.
Verified by: claude-sonnet-5-5: 3 of 4 invariants proven (the 4th is the accepted risk; reftable checked by hand); no findings
Check: `.sdd/bin/sdd check` passed (shellcheck and the suite under /bin/sh and dash), no slack.

## Review (optional)
<!-- The human's review notes: what to change, one per line. The agent works through them
and says under "## Built" what it changed for each. -->

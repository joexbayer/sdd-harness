---
id: 18
type: refactor
title: Performance: parallel check, cached item state
status: open
created: 2026-10-27
approved: 1c2f27c2f272f101e892f9b4060b87509f2c3789 2026-10-28 joexbayer
---
# 18 Performance: parallel check, cached item state

## Goal
Agents call sdd constantly (`next`, `status`, `task done`, a hook at every session start and
stop), and the check runs before every ship and in `task done`. Measured on this repo
(2026-10-27, 17 items): `ls` 5.0s, `summary` 3.4s, `review` 2.7s, `status`/`next`/hooks
0.5-0.75s, and a full `sdd check` about 7 minutes (the suite twice, sh then dash; 83s when all
test files run at once). Lists grow about 0.3s per item, archived ones included.
- The check runs test files in parallel, and the sh and dash passes at the same time.
- Derived item state is cached under the hash of the item file's exact content plus everything
  else the answer depends on (the code fingerprint for check results, the sdd version, the
  config), in `.git/sdd/cache/`, never committed: an archived item is computed once.
- Each command reads an item once, not two or three times (`parse_item` is the hot spot).
- Budgets, as a test in the check (on a generated repo with 100 items, with a slack factor for
  slow machines, `SDD_PERF_SLACK`): `next`, `status`, `hook stop` and `hook session-start` under
  0.2s; `ls`, `ls --json` and `summary` under 1s.

## Invariants
Every command prints exactly what it prints today, and every existing test passes unchanged. A
cached answer is never used once anything it was derived from changed (C-2: the cache is a
memo of a derivation, never a source of truth; deleting `.git/sdd/cache/` changes nothing but
speed). Parallel tests stay independent (each has its own temp folder) and the check still
fails when any test fails under either shell.

## Security
No new input or dependency. Risk: a cache read as truth → keys include the content hash, the
sdd version and the config, and a test edits each input to prove the cache misses; the cache
lives in `.git/`, so a branch cannot ship one.

## Tasks (optional)
- [x] T-18.1 Run test files in parallel, sh and dash at the same time (files: tests/run.sh, .sdd/config; test: sh tests/run.sh)
- [x] T-18.2 A perf test with the budgets on a generated 100-item repo (files: tests/t_perf.sh; test: SH=/bin/sh SRC=$PWD sh tests/t_perf.sh; expect: fail)
- [ ] T-18.3 Cache derived item rows by content hash (files: .sdd/core/lib/common.sh, tests/t_cache.sh; test: SH=/bin/sh SRC=$PWD sh tests/t_cache.sh)
- [ ] T-18.4 One read per item in next, status, hooks and review until the perf test passes (files: .sdd/core/lib/common.sh, .sdd/core/cmd/*.sh; test: SH=/bin/sh SRC=$PWD sh tests/t_perf.sh)

## Built
<!-- Written by the agent at the end of the build, for the review: per requirement what
changed (file:line) and which test proves it; deviations from the plan and why; follow-ups. -->

## Review (optional)
<!-- The human's review notes: what to change, one per line. The agent works through them
and says under "## Built" what it changed for each. -->

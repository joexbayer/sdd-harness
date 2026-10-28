---
id: 18
type: refactor
title: Performance: parallel check, cached item state
status: shipped
created: 2026-10-27
approved: 1c2f27c2f272f101e892f9b4060b87509f2c3789 2026-10-28 joexbayer
shipped: 2026-10-28
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
- [x] T-18.3 Cache derived item rows by content hash (files: .sdd/core/lib/common.sh, tests/t_cache.sh; test: SH=/bin/sh SRC=$PWD sh tests/t_cache.sh)
- [x] T-18.4 One read per item in next, status, hooks and review until the perf test passes (files: .sdd/core/lib/common.sh, .sdd/core/cmd/*.sh; test: SH=/bin/sh SRC=$PWD sh tests/t_perf.sh)

## Built
<!-- Written by the agent at the end of the build, for the review: per requirement what
changed (file:line) and which test proves it; deviations from the plan and why; follow-ups. -->

**Parallel check** (T-18.1). `tests/run.sh:14-34` starts every test file under every given shell
at once (each test keeps its own temp dir from tests/lib.sh), then prints results per shell in
file order (`tests/run.sh:36-54`); it exits 1 when any file fails under any shell. `.sdd/config`
runs both shells in one check line: `sh tests/run.sh /bin/sh dash`. Proof: the suite passes
under both shells; a scratch copy with a test failing only under dash printed `FAIL` and exited 1.
Check wall time: about 7 min → 2 min 8 s on this machine.

**Cached item state** (T-18.3). `item_rows` (`.sdd/core/lib/common.sh:871`) builds every row for
ls, summary and status (`cmd/ls.sh:17`, `cmd/summary.sh:29`, `cmd/status.sh:8`). The facts an item
file decides (`item_facts`, :831) are cached in `.git/sdd/cache/facts.<hash>` (`cache_file`, :950).
The hash covers VERSION, lib/common.sh, the command path and the config table. Each line is keyed
by the file's blob hash, origin and path; `item_sources` (:764) now also prints the blob. A row
whose phase read a check result (reason check, built or ready) or the working tree is never
cached. Branch, opened_by and active come fresh from git, one `git log` per ref
(`item_rows_finish` :910, `open_authors` :941). Proof: `tests/t_cache.sh` poisons the cache to
show a hit, then shows a miss after each input changes: the item file, the config, VERSION,
common.sh, the same file under another id's folder, a check result going stale, an edit in the
working tree. Deleting the cache gives identical `ls --json`.

**One read per item** (T-18.4). `item_read` (:1005) reads the item in one awk pass, using the
same grammar as parse_item and task_rows (shared `AWK_PARSE` :974 and `AWK_TASK` :514).
`item_phase` (:447) uses it, and next, status and review take the title, the approval and the
current task from its `IR_*` values (`cmd/next.sh:22-53`, `cmd/status.sh:13`, `cmd/review.sh:11,15`).
The config is read once per process: `cfg_load` (:60) runs from `need_repo`, and lookups go
through `AWK_CFG` (:76), including `gate_level` in one awk (:164). Also: one `git rev-parse` in
`find_repo` (:27); the check fingerprint for a branch item is computed only when a check was
recorded (`phase_check_passed` :433); `render` reads date and base once (:183); `plan_hash` is
one awk (:277). The hook makes one jq call (`cmd/hook.sh:20`), and session-start runs status in
the same process (`cmd/hook.sh:48`). Proof: `tests/t_perf.sh` (100 items: 95 shipped, 5 open on
branches, one checked out mid-build). Best of 3 runs after a warm-up, budget in brackets:

| command | before | after sh | after dash |
|---|---|---|---|
| next (0.2 s) | 0.22 | 0.10 | 0.09 |
| status (0.2 s) | 0.17 | 0.09 | 0.07 |
| hook stop (0.2 s) | 0.32 | 0.15 | 0.13 |
| hook session-start (0.2 s) | 0.25 | 0.09 | 0.09 |
| ls (1 s) | 7.8 | 0.43 | 0.42 |
| ls --json (1 s) | 7.9 | 0.46 | 0.43 |
| summary (1 s) | 7.9 | 0.47 | 0.44 |

On this repo (19 items, with the GitHub forge): next 0.57 → 0.11, status 0.42 → 0.08,
ls 4.6 → 1.26 (most of that is the `gh` PR call), summary 3.7 → 0.37, review 1.57 → 1.03,
hook stop 0.63 → 0.14, hook session-start 0.39 → 0.09.

**Same output.** No existing test changed. I ran every command with the old and the new `.sdd/`,
cold and warm cache, and diffed the output: ls (--all, --json), summary (--md, --since, --last),
status, next, review, task, show (--json) and both hooks, with and without an agent. Repos: the
100-item repo, a copy of this repo (on this branch and on main), and an edge repo. The edge repo
had an unclosed frontmatter, no frontmatter, comments and fences in the plan, a title with
`'$()`\` & " \\`, a CRLF item, open and decided questions, a plan changed after approval, a
dropped item and an archived item with no shipped date. Every output was identical under sh, and
the two runs repeated under dash were identical too.

Deviations
- T-18.1: run.sh runs `t_perf*.sh` alone after the other files, one shell at a time. Run in the
  middle of 40 other test processes, its timings would measure the load, not sdd.
- T-18.3 changed `cmd/ls.sh`, `summary.sh`, `status.sh`, `show.sh` and `open.sh` (the plan named
  only common.sh): they read item_sources, whose lines gained a blob column, or now call
  item_rows. The config table also landed in T-18.3, because the cache key needs the config.
- "Each command reads an item once": item_phase reads it once. `current_item`/`item_load`
  still peek at `type:` first (fm_get stops at that key). review still reads its Security,
  Built and Review sections and the FR list on its own, because it prints them; review has no
  budget.
- Edge cases that now print differently, and could not before give a sane row anyway: a
  frontmatter value or `## ` heading containing a tab (it already broke ls's TSV columns), and a
  config value with an escaped newline. A malformed config file's git error now prints once
  per command, not once per lookup.
- I updated `.claude/skills/sdd-dev/SKILL.md` (agent config, so review lists it as sensitive)
  with the new run.sh usage and these performance notes. Drop the commit if you'd rather not.

Follow-ups
- ls costs about 25 ms per item branch (one ls-tree and up to two git logs for each). A repo
  with 50 open branches would be near 1.5 s. Measure first if that matters.
- bin/sdd and need_repo each run `git rev-parse` (about 9 ms). Sharing the result would mean
  editing bin/, which this plan didn't name.
- t_perf adds about 20 s per shell to the check, most of it generating 100 commits.
- Not built, on purpose: locking for the cache file. Two commands filling it at once may append
  the same line twice (the first one wins, harmless). A line cut short by a kill is skipped
  (wrong field count). Likelihood is low and the cost is only a recompute.

Security pass: no findings. A fresh reviewer (a subagent given only the diff) looked for item text
run as code, cache poisoning, path writes outside .git/sdd, the config table, author lookup and
the hook changes. It confirmed no gate uses the cache: check, hook stop, run and next judge the
current item from its file.

## Review (optional)
<!-- The human's review notes: what to change, one per line. The agent works through them
and says under "## Built" what it changed for each. -->

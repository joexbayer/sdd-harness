---
id: 25
type: refactor
title: Fast dependency checks
status: open
created: 2026-10-29
approved: cc029dacc7312da537a78e5b6ba00ecc33bee6db 2026-10-29 joexbayer
---
# 25 Fast dependency checks

## Goal
<!-- What gets better (structure, readability, performance) and why it matters now. -->
Since item 24 (multi-item plans), an item with a `depends:` line makes `next`, `status` and the
session-start hook read every item row, with two git calls per branch (who opened it, its last
commit) that dependency state never uses, and `status` reads them twice. On the 100-item perf
repo that is 0.44 s for `next` and 0.65 s for `status`, against a 0.2 s budget. Most items opened
from a roadmap will have `depends:`, so this hits the next items directly.

D-25.1 Dependency state reads the item rows without opened_by and active (`dep_rows`), once
per command.
D-25.2 The list of item files (item_sources: one `ls-tree` per branch) is cached in
`.git/sdd/cache/sources` under the branch tips from one `for-each-ref`, so an unchanged repo
costs one git call for it. This speeds up ls and summary too.
D-25.3 t_perf gives item 100 a `depends:` (a shipped item, an open one, an entry), so the
budget covers it; t_gitcalls proves the new cache sees a new branch, a new commit and a
deleted branch at once.

## Invariants
<!-- Behaviour that must not change. Existing tests stay as they are; they prove it. -->
Every command prints what it printed before; the item list never shows a stale branch (C-2:
deleting the cache changes nothing but speed). Existing tests stay as they are, apart from the
two additions in D-25.3.

## Built
<!-- Written by the agent at the end of the build, for the review: per requirement what
changed (file:line) and which test proves it; deviations from the plan and why; follow-ups. -->
D-25.1: `dep_rows` in .sdd/core/lib/common.sh (item_rows with `_IR_LIGHT=1`, which skips
item_rows_finish's per-ref `git log` calls; once per process into `DEP_ROWS`), used by
`waits_for`, status.sh `open_items` and next.sh's ready entries.
D-25.2: `item_sources` in common.sh caches everything but the worktree row in
`.git/sdd/cache/sources`, keyed on `cksum` of base, SPECS and one `for-each-ref`; written to a
temp file and moved. The branch loop uses `[ ]` tests, not `case`, because macOS /bin/sh
(bash 3.2) cannot parse a `case` inside `$( )`.
D-25.3: tests/t_perf.sh item 100 has `depends: 5, 99, R-1.1`; tests/t_gitcalls.sh checks `ls`
after a new branch, a commit on it and its deletion.

Times on the 100-item perf repo, dash, load average 9 (best of 3):
next 0.44 → 0.15 s, status 0.65 → 0.10 s, session-start 0.38 → 0.10 s, ls 0.43 → 0.34 s,
summary 0.45 → 0.32 s; hook stop unchanged (0.07 → 0.06 s).

Verified: `sdd check` (shellcheck, all tests under /bin/sh and dash) passes, timing test with
no slack. t_roadmap, t_depends, t_query, t_open and t_cache pass unchanged.
Verified by: none (lite profile; refactor with existing tests as the proof)

## Review (optional)
<!-- The human's review notes: what to change, one per line. The agent works through them
and says under "## Built" what it changed for each. -->

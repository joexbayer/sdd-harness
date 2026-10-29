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

## Review (optional)
<!-- The human's review notes: what to change, one per line. The agent works through them
and says under "## Built" what it changed for each. -->

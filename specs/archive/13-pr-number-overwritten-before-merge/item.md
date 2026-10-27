---
id: 13
type: hotfix
title: PR number overwritten before merge
status: shipped
created: 2026-10-27
shipped: 2026-10-27
---
# 13 PR number overwritten before merge

## What is broken
`ship` cannot merge a PR in a repo with a constitution: the second ship asks GitHub to merge
the wrong PR number ("could not merge PR #4" for PR #1, 2026-10-27, on this repo's first real
PR). Nothing is changed: the merge is refused. Since item 10 (GitHub adapter).

## Built
- Cause: `pr_ship` kept the PR number in `_n`; `pr_gates` then calls `check_articles`, which
  counts articles in its own `_n` (sh has no local variables), so the number became 4.
- Fix: `.sdd/core/cmd/ship.sh` `pr_push`/`pr_ship` keep PR facts in `pr_*` names (a rename, no
  logic change), with a comment on why.
- Verified: tests/t_forge.sh now has a three-article constitution; it failed first ("could
  not merge PR #3", committed as test(13)) and passes with the fix; `sdd check` passes.
- Dev skill: a gotcha on helper variable names. No follow-up item needed: the regression test
  is in.

## Review (optional)
<!-- The human's review notes: what to change, one per line. The agent works through them
and says under "## Built" what it changed for each. -->

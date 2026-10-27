---
id: 8
type: amendment
title: C-4: tidy may delete remote branches of shipped items
status: open
created: 2026-10-27
# 8 C-4: tidy may delete remote branches of shipped items

## Articles affected
C-4 (changed).

## Current text
C-4 Only new, approve and ship create commits, and no verb pushes.
  Why: the human decides what lands and what leaves the machine.
  Enforced: check sh tests/constitution/c4-commits.sh

## Proposed text
C-4 Only new, approve and ship create commits. No verb pushes, except `tidy --remote`, which
  only deletes remote branches of items already shipped or dropped on the base branch.
  Why: the human decides what lands and what leaves the machine; `tidy --remote` is
  human-only (an ask rule) and removes only work the base already holds.
  Enforced: check sh tests/constitution/c4-commits.sh

## Why now
Remote branches of shipped items pile up (items 2-6 on GitHub today), and deleting them by
hand is git an agent improvises or a human forgets. Item 7 (git forge: worktrees, landing and
cleanup) decided to let `sdd tidy --remote` do it (Q-7.4, Q-7.5), which today's C-4 forbids.

## Impact
- Item 7 (git forge) builds `cmd/tidy.sh` with `--remote`, adds its ask rule, and changes
  `tests/constitution/c4-commits.sh` to allow `git push` in `cmd/tidy.sh` only. Until then the
  check stays stricter than the text, so it still passes.
- Item 7 updates the C-4 example in README.md (outside specs/, so not in this item).
- Here: specs/design.md §8 ("No verb pushes, except `ship` in team PR mode") becomes "except
  `tidy --remote`"; pushing for PRs is item 9's (GitHub adapter) own amendment.

## Alternatives (optional)
- Print `git push origin --delete …` for the human (no amendment): rejected in Q-7.4.
- "A verb pushes only when the human runs it" (covers item 9 too): rejected in Q-7.5, because
  the GitHub design is not planned yet.

## Built
<!-- The constitution diff as applied, and confirmation that every check article passes. -->

## Review (optional)
<!-- The human's review notes: what to change, one per line. The agent works through them
and says under "## Built" what it changed for each. -->

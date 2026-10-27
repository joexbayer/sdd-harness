---
id: 11
type: amendment
title: C-4: ship may push its branch and merge its PR
status: open
created: 2026-10-27
approved: 3ff7bd2dbe1eb71998aa7b922fabd51bd0f9417a 2026-10-27 joexbayer
---
# 11 C-4: ship may push its branch and merge its PR

## Articles affected
C-4 (changed).

## Current text
C-4 Only new, approve and ship create commits. No verb pushes, except `tidy --remote`, which
  only deletes remote branches of items already shipped or dropped on the base branch.
  Why: the human decides what lands and what leaves the machine; `tidy --remote` is
  human-only (an ask rule) and removes only work the base already holds.
  Enforced: check sh tests/constitution/c4-commits.sh

## Proposed text
C-4 Only new, approve and ship create commits. No verb pushes, except two human-only ones:
  `tidy --remote` deletes remote branches of items already shipped or dropped on the base, and
  `ship` with `forge = github` pushes its own item branch and merges that branch's PR. No verb
  pushes the base branch.
  Why: the human decides what lands and what leaves the machine; both run behind an ask rule,
  and the base changes only through a merge the human started.
  Enforced: check sh tests/constitution/c4-commits.sh

## Why now
Item 10 (GitHub adapter) decided that `ship` opens a PR and, run again, merges it (Q-10.2,
Q-10.3), because on the GitHub free plan nothing else enforces the gates before a merge. Today's
C-4 allows only `tidy --remote` to push.

## Impact
- Item 10 (GitHub adapter) builds `core/forges/github.sh` and the ship changes, and extends
  `tests/constitution/c4-commits.sh`: scan `core/forges/` too, allow only lines marked
  `# C-4: …`, and flag any `gh` call outside `core/forges/`. Until then the check stays
  stricter than the text, so it still passes.
- Item 10 updates the C-4 example in README.md (outside specs/).
- Here: specs/design.md §8 names both exceptions.

## Alternatives (optional)
- Ship opens the PR and a human merges with the GitHub button: rejected in Q-10.3, because
  nothing checks the gates at merge time without branch protection.
- "Any verb may push when the human runs it": broader than the two cases planned.

## Built
- specs/constitution.md C-4: replaced with the Proposed text, word for word.
- specs/design.md §8: names both exceptions (`tidy --remote`, `ship` with `forge = github`).
- `tests/constitution/c4-commits.sh` is unchanged and stricter than the new text (only
  tidy's marked delete may push); item 10 (GitHub adapter) extends it.
## Review (optional)
<!-- The human's review notes: what to change, one per line. The agent works through them
and says under "## Built" what it changed for each. -->

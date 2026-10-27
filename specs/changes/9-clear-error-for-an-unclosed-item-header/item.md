---
id: 9
type: fix
title: Clear error for an unclosed item header
status: open
created: 2026-10-27
approved: fe5d615f0b4d18da5144322c552e0106444c482a 2026-10-27 joexbayer
---
# 9 Clear error for an unclosed item header

## Current behaviour
When an item's frontmatter (the `---` block at the top) has no closing `---`, `fm_set`
updates keys that already exist but silently drops new ones. So `approve` cannot add
`approved:` and fails with "could not commit <file>", and `ship` archives the item without its
`shipped:` date (reproduced in a scratch repo, 2026-10-27). `next`, `status` and `ls` say
nothing is wrong. Hit while planning items 7 and 8, when a rewrite cut line 7.

## Expected behaviour
FR-9.1 WHEN an item's frontmatter has no closing `---` THE SYSTEM SHALL keep it in the plan
phase with that as the reason (reason code `frontmatter`), in `next`, `status`, `ls` and `show`.
  e.g. `Phase: plan (item.md: the --- block at the top is not closed; add --- after its last key)`
FR-9.2 WHEN `approve` or `ship` runs on such an item THE SYSTEM SHALL refuse with the same
message (exit 1), before changing anything.
  e.g. `sdd approve` → `sdd: item 9: the --- block at the top is not closed; …`
FR-9.3 WHEN `fm_set` finds no closing `---` THE SYSTEM SHALL fail and leave the file as it was,
so no caller can silently write nothing.

## Must not change
Items with a valid frontmatter: the same phases, reasons and `ls --json` output as today; every
existing test passes unchanged.

## Test
`tests/t_frontmatter.sh`: an item with its closing `---` removed. `next` and `ls --json` show
the reason (FR-9.1); `approve` and `ship` exit 1 with the message and leave the branch and file
as they were (FR-9.2); `fm_set` on it fails and leaves the file unchanged (FR-9.3). Fails today:
`next` shows no such reason and `approve` says "could not commit".
How: a helper `fm_closed <file>` in `lib/common.sh`, checked first in `item_phase`, `approve`
and `ship`; `fm_set` exits non-zero from awk when the block never closes.
## Built
<!-- Written by the agent at the end of the build, for the review: per requirement what
changed (file:line) and which test proves it; deviations from the plan and why; follow-ups. -->

## Review (optional)
<!-- The human's review notes: what to change, one per line. The agent works through them
and says under "## Built" what it changed for each. -->

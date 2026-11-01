---
id: 47
type: fix
title: Review counts FR names only in the item's files
status: open
created: 2026-11-01
approved: c824cd5a54c5f4a6adce6cd48551b920cfee914f 2026-11-01 joexbayer
---
# 47 Review counts FR names only in the item's files

## Current behaviour
`sdd review` lists, per FR, where it is named outside `specs/`, by grepping the whole repo
(`.sdd/core/cmd/review.sh:86`). In a repo that adopted sdd, item numbers restart at 1, so text
from before sdd that says `FR-1.3` counts as naming item 1's FR-1.3. narrow's item 1 review
(2026-11-01) listed FR-1.1 at `docs/eval/2026-10-29-sdd-spot-run.md:23` and FR-1.3 at that file and
`internal/core/plugins_test.go:51`, all from before sdd. The list is how the human checks that every
FR has a test naming it, so a stale match can hide a missing test.

## Expected behaviour
FR-47.1 WHEN `sdd review` lists where each FR is named THE SYSTEM SHALL count only files this item
changed: those in `git diff --name-only --relative <merge-base>` (committed and uncommitted
changes since the branch left the base) and untracked files (`git ls-files --others
--exclude-standard`), still outside `specs/`.
  e.g. `old.md` committed on main before the item says `FR-1.2`, and the item names FR-1.1 in a
  committed `in_item.txt` and an untracked `code.txt` → `FR-1.1     code.txt:1 in_item.txt:1` and
  `FR-1.2     ✗ not named in this item's changes`
FR-47.2 WHEN an FR is named in none of those files THE SYSTEM SHALL print
`✗ not named in this item's changes` for it, under the heading
`Requirements → where this item's changes name them outside specs/ (tests should name the FR they prove)`.
  e.g. FR-1.2 above

How: in `.sdd/core/cmd/review.sh`, before the loop, `changed=$( { git diff --name-only --relative
"$mb"; git ls-files --others --exclude-standard; } | sort -u )` (`mb` is already the merge-base);
in the loop, the existing `git grep` output is filtered with awk to lines whose file (field 1,
`-F:`) is in `$changed` (passed via `ENVIRON`), then cut, head and paste as today. Heading and ✗
text change as in FR-47.2.

D-47.1 Files the item changed, not "matches outside the diff marked elsewhere": an FR's test has
to be added or edited by its item, so nothing true is lost, and a shorter list is easier to
read than one with a second category.
D-47.2 Uncommitted tracked changes count too (`git diff` against the merge-base, not
`<mb>..HEAD`), like the untracked files: agents often leave tests uncommitted until the human
ships (the existing `--untracked` comment).

## Must not change
- The rest of `sdd review` (plan, check, verify, commits, sensitive files, constitution, Built).
- Ship still does not check FR names.

## Security
none: a narrower read-only listing in review; no input, secrets or new dependency.

## Test
`tests/t_phase.sh`: before the item starts, commit `old.md` saying `FR-1.2` on main; during the
build, commit `in_item.txt` naming FR-1.1 next to the existing untracked `code.txt`. The review
asserts `FR-1.1     code.txt:1 in_item.txt:1` (committed and untracked both count) and
`FR-1.2     ✗ not named in this item's changes` (the pre-item file does not). Fails now: FR-1.2
is listed at `old.md:1`.

## Built
<!-- Written by the agent at the end of the build, for the review: per requirement what
changed (file:line) and which test proves it; deviations from the plan and why; follow-ups. -->

## Review (optional)
<!-- The human's review notes: what to change, one per line. The agent works through them
and says under "## Built" what it changed for each. -->

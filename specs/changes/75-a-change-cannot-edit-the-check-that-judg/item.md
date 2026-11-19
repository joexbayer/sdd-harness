---
id: 75
type: fix
title: A change cannot edit the check that judges it
status: open
created: 2026-11-18
approved: 3d9384e04c953eec348f7be9b0f1b820b3dc1034 2026-11-19 joexbayer
---
# 75 A change cannot edit the check that judges it

## Current behaviour
`check` and `ship` read the check commands (`[check]` in `.sdd/config`) from the item's own branch. A branch that deletes a `run` line, or adds a `no-tests` pattern, ships with "check passed". `review` only lists `.sdd/config` among sensitive files.
Repro: on an item branch, `git config -f .sdd/config --replace-all check.run true`, commit, build, ship: it lands.

## Expected behaviour
FR-75.1 WHEN an item that is not a chore changes any `check.*` value in `.sdd/config` from the base THE SYSTEM SHALL refuse to ship it, in every profile, naming the keys and saying a chore changes the check.
  e.g. `check.run` `sh tests/run.sh` → `true` on a fix → `item 9: changes the check that judges it (check.run): change [check] in a chore`
FR-75.2 WHEN `review` shows such an item THE SYSTEM SHALL print the same line as a warning.
  e.g. `⚠ item 9: changes the check that judges it (check.run): change [check] in a chore`

## Must not change
- A chore changes `[check]` and ships as today.
- An item that leaves `[check]` alone, or changes only other sections (`[sdd]`, `[review]`), ships as today.
- A base with no `.sdd/config` yet (adoption) is not refused: nothing to compare.
- The developer's own `~/.config/sdd/config` still overrides (not on the branch).

## Security
- The check is the main gate; a branch weakening it is the risk this closes → FR-75.1 refuses at ship, FR-75.2 shows it at review.
- Known limit, accept: a branch can still edit the test files or scripts the check runs (`tests/run.sh`). Planner-written tests are guarded (item 58); the diff shows the rest at review.

## Test
`t_ship.sh`: a fix changing `check.run` is refused and names the key; a chore changing it ships; a change to `[sdd]` only ships. `t_review.sh` or nearest: the warning line.

## Tasks
- [ ] T-75.1 Failing tests: a fix editing [check] is refused at ship and warned at review, a chore is not, FR-75.1 FR-75.2 (files: tests/t_ship.sh, tests/t_reviewed.sh; test: for t in ship reviewed; do SRC=$PWD SH=dash dash tests/t_$t.sh || exit 1; done; expect: fail; size: S)
- [ ] T-75.2 `check_edited` in common.sh (compares `git config --blob <base>:.sdd/config --get-regexp '^check\.'` with HEAD's), used by ship next to the planner-test guard and by review, FR-75.1 FR-75.2 (files: .sdd/core/lib/common.sh, .sdd/core/cmd/ship.sh, .sdd/core/cmd/review.sh; test: for t in ship reviewed forge; do SRC=$PWD SH=dash dash tests/t_$t.sh || exit 1; done; size: S)

## Built
<!-- Written by the agent at the end of the build, for the review: per requirement what
changed (file:line) and which test proves it; deviations from the plan and why; follow-ups. -->

## Review (optional)
<!-- What to change, one per line (the agent writes what the human asks). The agent works through them
and says under "## Built" what it changed for each. -->

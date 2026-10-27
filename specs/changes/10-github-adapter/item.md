---
id: 10
type: feature
title: GitHub adapter
status: open
created: 2026-10-27
approved: fb71ec60ff933829311d0e8ba7ecd0a49f1cc336 2026-10-27 joexbayer
---
# 10 GitHub adapter

## Why
Teams review and merge in pull requests, but `ship` lands an item on the local base and leaves
the push to the human: no PR, no CI, nothing a teammate sees until it is on main. On the
GitHub free plan for private repos there is no branch protection (checked: HTTP 403 on this
repo), so nothing on GitHub enforces checks before a merge; sdd's gates are the only ones.

## What changes
US-10.1 As a developer I ship through a PR with one command, so that teammates and CI see the
change before it lands, and the gates still hold.
FR-10.1 WHEN `ship` runs with `forge = github` THE SYSTEM SHALL run the gates as today, commit
the archive move on the item's branch, push that branch and open a PR into the base titled
`<type>(<id>): <title>` with the item as its body.
  e.g. `✓ PR #12 opened for item 4: https://github.com/acme/app/pull/12`
FR-10.2 WHEN `ship` runs again with local commits the PR lacks THE SYSTEM SHALL push them and
update the PR body, instead of opening another PR.
FR-10.3 WHEN `ship` runs again and the PR head is exactly this commit THE SYSTEM SHALL merge it
with a merge commit (`gh pr merge --merge --match-head-commit`), fast-forward the local base
from the remote, and delete the item branch locally and on the remote.
  e.g. `✓ merged PR #12; main is at 3f2c1aa`
FR-10.4 WHEN CI has failing or pending checks, or the PR is closed THE SYSTEM SHALL refuse to
merge, name the checks or the state, and change nothing (exit 1).
FR-10.5 WHEN `status`, `ls` or `review` shows an item that has a PR THE SYSTEM SHALL show its
number, state, review decision and CI result, read live from GitHub, and `--json` SHALL carry
`pr` (number, state, review, ci, url).
  e.g. `4 feature · Faster search · in PR #12: approved, CI passing`
FR-10.6 WHEN `gh` is missing or not logged in THE SYSTEM SHALL stop `ship` with how to fix it
(exit 1), while `status`, `ls` and `review` show `PR state unknown (gh not logged in)`.
FR-10.7 WHEN `forge` is unset THE SYSTEM SHALL ship exactly as today; WHEN `init` runs in a repo
whose origin is on github.com THE SYSTEM SHALL suggest `forge = github`.

## Not in scope (optional)
PR review as plan approval in team mode (Q-0.1): the next item. Squash and rebase merges, GitLab.

## How
```
 ship ──gates──▶ archive commit on branch ──git push──▶ gh pr create|edit ──▶ "PR #12 opened"
 ship again ──▶ gh pr view: head == HEAD? CI ok? ──▶ gh pr merge --merge --match-head-commit
                                                    ──▶ git fetch; ff base; delete branches
 status/ls/review ──▶ one gh pr list --state all --json … ──▶ "in PR #12: approved, CI passing"
```
- New `core/forges/github.sh` (the only file that calls `gh`): `forge_pr_open`, `forge_pr_state`,
  `forge_pr_merge`; `cmd/ship.sh` calls it when `cfg sdd.forge` is set. `current_item` also finds
  an item archived on its own branch (after the first ship), so the second ship knows it.
- Tests use a stub `gh` on PATH (a script answering from files, logging its calls) and a bare
  origin; nothing in the suite talks to GitHub.
D-10.1 Merge commits only, because a squash or rebase merge rewrites commits: `tidy` and ship's
branch cleanup (item 7) prove "landed" by ancestry, and squash also hides who wrote what.
D-10.2 PR state is read live and never stored (C-2), with one `gh pr list` call per command,
not one per item.
D-10.3 Pushing the item branch and merging its PR needs a C-4 amendment (item 11), shipped
first; the base branch is never pushed directly.
D-10.4 Tests stub `gh`, because CI and the suite must not need network or credentials.

## Questions (optional)
Q-10.1 Split the GitHub adapter? → recommend: split; item 10 is PR on ship, PR review as
approval is the next item. → decided: split (joexbayer, 2026-10-27)
Q-10.2 With a PR, when does the item move to the archive? → recommend: inside the PR, so main
shows it shipped only once merged. → decided: inside the PR (joexbayer, 2026-10-27)
Q-10.3 Who merges the PR? → recommend: `sdd ship` run again, so the gates hold without branch
protection. → decided: sdd ship, run again (joexbayer, 2026-10-27)
Q-10.4 How is PR mode switched on? → recommend: `forge = github` in the project config, so the
whole team ships the same way. → decided: project config (joexbayer, 2026-10-27)

## Done when
DOD-10.1 `sdd check` passes, with a test naming each FR, under /bin/sh and dash.
DOD-10.2 On this repo, with `forge = github`, the next item ships as a real PR (body = item),
and a second `ship` merges it after CI; `git log main` shows the merge commit.

## Built
<!-- Written by the agent at the end of the build, for the review: per requirement what
changed (file:line) and which test proves it; deviations from the plan and why; follow-ups. -->

## Review (optional)
<!-- The human's review notes: what to change, one per line. The agent works through them
and says under "## Built" what it changed for each. -->

---
id: 54
type: fix
title: Pull requests reference the item file instead of copying it
status: open
created: 2026-11-01
approved: b36066837b14c90c4674c5600db1378ba7944768 2026-11-01 joexbayer
---
# 54 Pull requests reference the item file instead of copying it

## Current behaviour
`sdd ship` with `forge = github` opens the pull request with the whole item file as its body
(`.sdd/core/cmd/ship.sh:118`, `forge_pr_create … "$IFILE"`) and, on later ships, replaces the body
with it again (`ship.sh:115`, `forge_pr_edit`). Item 53's file is about 1,000 lines, so GitHub
refused it: "Body is too long (maximum is 65536 characters)". The user (2026-11-01): the PR "should
just reference the file".

## Expected behaviour
FR-54.1 WHEN `sdd ship` opens a pull request THE SYSTEM SHALL give it a short body that names the
item and the path of its file on the branch, instead of the file's text.
  e.g. item 1 "Faster search" → body
  `Item 1 (feature): Faster search` / (blank line) /
  `The plan, its requirements and the build notes: \`specs/archive/1-faster-search/item.md\` on this branch.`
FR-54.2 WHEN `sdd ship` pushes new commits to an open pull request THE SYSTEM SHALL leave its body as
it is (the path does not change).
  e.g. the second ship of item 1 → no `gh pr edit` call; still one PR

How: `forge_pr_create <branch> <base> <title> <body text>` passes `--body` instead of
`--body-file`; `ship.sh` builds the two lines. `forge_pr_edit` and its call in `pr_push` are
removed (nothing else uses them). `specs/design.md` §11 "a PR whose body is the brief" → "a PR
whose body points at the item file".

D-54.1 No summary in the body: the user asked for a reference only, and a copy goes stale when the
branch gets new commits; GitHub shows the file under "Files changed".

## Must not change
- The PR's title (`<type>(<id>): <title>`), the push, the gates and the merge flow (FR-10.x).
- Items without a forge ship as today.

## Security
none: less text sent to the forge; no input or dependency.

## Test
`tests/t_forge.sh`: FR-10.1's body assertion becomes the FR-54.1 two lines (fails now: the body is
the item file); after FR-10.2's second ship, the stub gh's log has no `pr edit` (FR-54.2). The stub's
`pr create` takes `--body`.

## Built
<!-- Written by the agent at the end of the build, for the review: per requirement what
changed (file:line) and which test proves it; deviations from the plan and why; follow-ups. -->

## Review (optional)
<!-- The human's review notes: what to change, one per line. The agent works through them
and says under "## Built" what it changed for each. -->

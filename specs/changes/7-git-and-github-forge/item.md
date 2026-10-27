---
id: 7
type: feature
title: Git forge: worktrees, landing and cleanup
status: open
created: 2026-10-27
approved: 18b946634dc1500b48ad086aa9ca0614d87c27de 2026-10-27 joexbayer
---
# 7 Git forge: worktrees, landing and cleanup

## Why
Every ship leaves git litter, and agents improvise the cleanup. `ship` deletes the branch with
`git branch -d`, which refuses whenever the branch was pushed before ship rebased it, so items
2-6 all left branches behind (kb/git-cleanup.md). Worktrees are never removed, nothing tidies
leftovers, and picking up a teammate's item means hand-typed git.

## What changes
US-7.1 As a developer I open, land and clean up any item with one sdd command each, so that no
one (human or agent) improvises git.
FR-7.1 WHEN `sdd open <id>` runs THE SYSTEM SHALL switch to the item's branch, creating a local
branch that tracks the remote one when only a teammate's remote branch exists.
  e.g. `sdd open 3` → `switched to feature/3-karis-thing (tracking origin/feature/3-karis-thing)`
FR-7.2 WHEN `sdd open <id> --worktree` runs THE SYSTEM SHALL add a worktree at
`../<repo>.<id>` on that branch and sync agents into it as `new --worktree` does; if the
branch is already checked out somewhere, it SHALL print that path instead.
  e.g. `sdd open 3 --worktree` → `worktree ../swe-harness.3`
FR-7.3 WHEN the id is unknown, the item is shipped or dropped, or `open` would switch a working
tree with uncommitted changes THE SYSTEM SHALL refuse with the reason (exit 1).
  e.g. `sdd open 2` → `item 2 is shipped (specs/archive/2-…)`
FR-7.4 WHEN `ship` lands an item from the main checkout THE SYSTEM SHALL delete the local branch
whenever all its commits are on the base, even if its pushed copy differs.
  e.g. `✓ shipped 5 into main (local); branch feature/5-… deleted`
FR-7.5 WHEN `ship` runs in a linked worktree THE SYSTEM SHALL keep that worktree and branch and
print `cd <main checkout> && sdd tidy`.
FR-7.6 WHEN `sdd tidy` runs THE SYSTEM SHALL remove each worktree and local branch whose item is
shipped or dropped on the base, when the branch is fully on the base and the worktree is clean,
and list what it removed; `--dry-run` only lists.
  e.g. `removed  branch feature/2-spec-query-…  (item 2, shipped)`
FR-7.7 WHEN a leftover is not provably safe THE SYSTEM SHALL keep it and say why, with the exact
command to remove it: a spike's code branch, a dirty worktree, commits not on the base, or the
worktree the command runs in.
  e.g. `kept     worktree ../swe-harness.9  (uncommitted changes)  · git worktree remove --force …`
FR-7.8 WHEN shipped or dropped items still have remote branches THE SYSTEM SHALL list them under
tidy with `next    sdd tidy --remote`.
FR-7.9 WHEN `sdd tidy --remote` runs THE SYSTEM SHALL delete those remote branches
(`git push <remote> --delete …`), skipping and listing any that carry commits whose changes are
not on the base (`git cherry`).
FR-7.10 WHEN `sync claude` runs THE SYSTEM SHALL add an ask rule for `tidy --remote`, so the
human confirms it as they do approve and ship; `--remote` is accepted only as tidy's first
argument, so the rule's prefix always matches.
FR-7.11 WHEN `--remote` is given anywhere else, or an unknown flag, THE SYSTEM SHALL refuse with
usage (exit 2).

## Not in scope (optional)
GitHub (PRs, CI state, review as approval): item 9. Pushing the base branch stays with the human.

## How
```
 sdd open <id> ──▶ item_sources (item 2) ──▶ local branch? switch : track remote
                                          └─ --worktree ─▶ git worktree add ../<repo>.<id>
 sdd ship ──▶ (as today) ──▶ main checkout: switch base; merge-base --is-ancestor → branch -D
                         └─▶ linked worktree: keep, print "cd … && sdd tidy"
 sdd tidy ──▶ shipped/dropped ids (archive on base)
              × git worktree list --porcelain, refs/heads, refs/remotes
              ──▶ safe? remove : keep + reason + command ──▶ --remote: git push --delete
```
- New `cmd/open.sh`, `cmd/tidy.sh`; `cmd/ship.sh` cleanup tail; `agents/claude.sh` ask rule;
  AGENTS.md block and the ship skill name `tidy --remote` as human-only; help and design §8.
- `tests/constitution/c4-commits.sh` allows `git push` in `cmd/tidy.sh` only (new C-4).
- Tests: `tests/t_open.sh`, `tests/t_tidy.sh` (bare origin, teammate clone, spike, dirty
  worktree), `tests/t_ship.sh` gains the pushed-then-rebased branch case.
D-7.1 "Safe" is ancestry against the base (`merge-base --is-ancestor`), not `branch -d`, because
`-d` compares with the upstream (kb/git-cleanup.md).
D-7.2 Remote deletion checks `git cherry` first, because a remote branch is gone for good once
deleted, and a teammate may have pushed to it after the ship.
D-7.3 Item 8 (amendment of C-4) ships first: today C-4 forbids any push, and its check fails on
`git push` in a verb. Item 7 is built after it lands.
D-7.4 Worktree path stays `../<repo>.<id>`, as `new --worktree` already does.
D-7.5 The GitHub adapter is item 9, not 8 (Q-7.1): item 8 is the C-4 amendment.

## Questions (optional)
Q-7.1 One item for git cleanup and the GitHub adapter, or split? → recommend: split; item 7
is git only (worktrees, landing, cleanup), item 8 the GitHub adapter. → decided: split
(joexbayer, 2026-10-27)
Q-7.2 When ship runs inside an item's worktree, remove it or leave it? → recommend: leave it for
`tidy`, so nothing vanishes under a running agent. → decided: leave it for tidy (joexbayer,
2026-10-27)
Q-7.3 Tidy: delete safe ones at once, preview by default, or ask per entry? → recommend: safe
ones at once, `--dry-run` to preview. → decided: safe ones at once (joexbayer, 2026-10-27)
Q-7.4 Remote branches: print the push command, amend C-4 now, or ignore? → recommend: print the
command. → decided: amend C-4 now (joexbayer, 2026-10-27)
Q-7.5 How wide is the C-4 amendment? → recommend: narrow, only `tidy --remote` for shipped items,
human-only. → decided: narrow (joexbayer, 2026-10-27)

## Done when
DOD-7.1 `sdd check` passes, with a test naming each FR, under /bin/sh and dash.
DOD-7.2 On this repo, `sdd tidy` removes the leftover local branches of items 2-6 and
`sdd tidy --remote` (confirmed by the human) deletes their GitHub copies.

## Built
- FR-7.1 (open switches, tracking a teammate's remote branch): `.sdd/core/cmd/open.sh:29,56`,
  using `item_sources` from item 2. Test: tests/t_open.sh (local branch; `origin/feature/2-…`
  of a teammate's clone becomes a tracking branch).
- FR-7.2 (`open --worktree`): `open.sh:39`; the path comes from the new `worktree_path`
  (`lib/common.sh:192`), next to the main checkout even when run from another worktree;
  `sync_here` (`common.sh:195`) syncs agents as `new --worktree` does. An already checked out
  branch prints its folder (`open.sh:32`). Test: t_open.sh.
- FR-7.3 (refusals): unknown id, shipped or dropped, dirty tree, bad usage (`open.sh:19,25`).
  Test: t_open.sh.
- FR-7.4 (ship deletes a fully landed branch): `.sdd/core/cmd/ship.sh:128`, ancestry against
  the base instead of `git branch -d`. Test: tests/t_ship.sh (pushed, then rebased by ship).
- FR-7.5 (ship in a worktree keeps it): `ship.sh:118-122`. Tests: t_ship.sh, tests/t_tidy.sh.
- FR-7.6, FR-7.7 (tidy removes the safe, keeps the rest with reason and command):
  `.sdd/core/cmd/tidy.sh:59-79`, reasons in `keep_reason` (`tidy.sh:38`). Kept: the main checkout's branch, the worktree you are in, a
  spike's code, commits not on the base, uncommitted changes. Test: t_tidy.sh (two worktrees,
  a spike, an open item that is never touched, `--dry-run`).
- FR-7.8, FR-7.9 (remote branches listed; `--remote` deletes, unless `git cherry` finds changes
  the base lacks): `tidy.sh:81-105`. Test: t_tidy.sh (a teammate pushes to a shipped item's
  branch after the ship: kept; the other one is gone from the bare origin).
- FR-7.10 (ask rule): `.sdd/core/agents/claude.sh:33` adds `tidy --remote` for every spelling
  (18 rules now). Test: tests/t_agents.sh. FR-7.11 (`--remote` first only): `tidy.sh:8,12`.
  Test: t_tidy.sh.
- C-4 enforcement: `tests/constitution/c4-commits.sh` now catches `git push` anywhere in code
  (it only caught lines starting with it, so `if git push` slipped by), except messages and
  tidy's `--delete`. Verified it flags an `if git push origin main` in a verb.
- Also: AGENTS.md block, the ship skill, help, README and design §8/§16 name `open`, `tidy` and
  `tidy --remote` as human-only; kb note specs/kb/git-cleanup.md; dev skill gotchas.

Deviations:
- `new --worktree` now uses `worktree_path` too: from inside a worktree it used to create
  `../app.7.9`; now `../app.9`, as `open` does.
- The old t_ship.sh assertion on the printed `git worktree remove` hint now asserts the FR-7.5
  message instead: the hint was replaced on purpose.
- The knowledge step's planned `tidy` (stale kb notes) is renamed `kb tidy` in design §8/§12,
  so the names do not clash.
- When `ship` runs in the main checkout while the base is checked out in a worktree, the branch
  is kept and it prints `git switch --detach && sdd tidy` (the plan did not cover this case).

Fresh-context review (2 blockers, 2 warnings, 7 nits) and what changed:
- Blocker fixed: `tidy --remote` judged a remote branch by the last fetch, then deleted
  whatever the remote had now. The delete is now leased (`--force-with-lease=<branch>:<sha>`,
  `tidy.sh:100`), so a branch a teammate moved since the fetch is refused. Test: t_tidy.sh
  (teammate pushes, no fetch: "origin refused").
- Blocker fixed: "done" for remote branches meant the local base, so running
  `tidy --remote` before `git push origin main` deleted branches whose work only this laptop
  had. Remote branches are now judged against `<remote>/<base>` (`tidy.sh:87`). Test: t_tidy.sh
  (before main is pushed, no remote branch is listed).
- Fixed: worktrees synced by `new`/`open --worktree` got ask rules naming the original
  checkout's absolute path; `sync_here` now syncs with `ROOT` set to the new worktree. Test:
  t_open.sh. Added tests for the dropped case, "has commits not on main" and "checked out in
  the main checkout".
- Fixed nits: a branch matches a done item by `<id>-<slug>`, not the id alone (a `fix/1-typo`
  is not item 1's); a worktree folder deleted by hand is pruned without an error; a failed
  removal is reported and tidy carries on; one `keep_reason` decides, one path removes.
- Fixed nit: the C-4 check strips quoted text and comments, then allows `git push` only on
  tidy.sh's line marked `# C-4: tidy --remote`; `echo ok && git push …` is caught now.
- Accepted: `git worktree remove` deletes ignored files (an `.env`) in a clean worktree, as
  git does. Suggested commands can fail in unusual layouts (base checked out in another
  worktree; bare repo plus worktrees, which sdd does not support yet).

Follow-ups:
- Commands printed by tidy do not quote paths; a checkout path with spaces needs hand quoting.
- On this repo `tidy --remote --dry-run` would delete the remote branches of items 1, 2, 4, 5
  and 6, and keeps item 3's: a rebase conflict was resolved at its ship, so one commit's
  change differs (b44dc7d). Delete it by hand with the printed command once you agree.
- The missing-frontmatter trap (approve says "could not commit"): a fix item.

## Review (optional)
<!-- The human's review notes: what to change, one per line. The agent works through them
and says under "## Built" what it changed for each. -->

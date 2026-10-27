---
type: research
status: active
review_by: 2027-04-27
sources:
  - https://git-scm.com/docs/git-branch (local git help branch, 2.5x; read 2026-10-27)
  - https://git-scm.com/docs/git-worktree (local git help worktree; read 2026-10-27)
  - this repo: branches of items 2-6 after ship (git branch -vv, 2026-10-27)
trust: reviewed
---
# Cleaning up branches and worktrees after a ship

- **`git branch -d` compares with the upstream, not the base.** "The branch must be fully
  merged in its upstream branch, or in HEAD if no upstream was set." A branch that was pushed,
  then rebased by `ship`, differs from its pushed copy, so `-d` refuses even though the base
  contains every commit. Seen on items 2-6 here: `[origin/…: ahead 19, behind 5]`.
- **The safe test is ancestry against the base:** `git merge-base --is-ancestor <branch> <base>`.
  If true, every commit on the branch is on the base, and `git branch -D` loses nothing.
- **A spike's branch never passes that test** (its code never lands), so it must be kept or
  deleted by the human on purpose.
- **Worktrees:** `git worktree remove <path>` refuses a worktree with uncommitted or untracked
  changes unless forced; `git worktree list --porcelain` gives `worktree`, `branch` and
  `prunable` lines to script against. Removing the worktree a shell or agent session is
  standing in leaves that session in a deleted directory.
- **Remote branches:** deleting one is a push (`git push origin --delete <branch>`).

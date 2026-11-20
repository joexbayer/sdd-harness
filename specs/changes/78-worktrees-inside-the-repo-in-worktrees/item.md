---
id: 78
type: feature
title: Worktrees inside the repo, in .worktrees/
status: open
created: 2026-11-19
approved: 490455bc4fac9ddd64de15f00203e8fa53bfe5f3 2026-11-19 joexbayer
---
# 78 Worktrees inside the repo, in .worktrees/

## Why
`new --worktree` and `open --worktree` put an item at `../<repo>.<id>`, outside the repo folder. Agents are often allowed only inside the folder they started in, so in a sibling worktree every command needs a prompt or is blocked. Claude Code keeps its own worktrees inside the repo for this reason.

## What changes
US-78.1 As a developer with an agent I open an item in a worktree the agent may already work in.
FR-78.1 WHEN `new --worktree` or `open --worktree` makes a worktree THE SYSTEM SHALL put it at `<main checkout>/.worktrees/<id>`, also when run from inside another worktree.
  e.g. repo `~/src/app`, `sdd new feature "Beta" --worktree` → `~/src/app/.worktrees/2`; `sdd open 3 --worktree` from `.worktrees/2` → `~/src/app/.worktrees/3`
FR-78.2 WHEN it makes such a worktree THE SYSTEM SHALL make sure `/.worktrees/` is in the clone's `.git/info/exclude`, once.
  e.g. after two `new --worktree` → `git status` in the main checkout is clean, and `.git/info/exclude` holds one `/.worktrees/` line
FR-78.3 WHEN `init` writes `.gitleaks.toml` THE SYSTEM SHALL skip `^\.worktrees/` as it skips `^\.claude/worktrees/`, and the tip for a team's own file SHALL name both.
  e.g. fresh init with gitleaks → `.gitleaks.toml` paths hold `^\.worktrees/`
FR-78.4 WHEN `init` looks for Python tests THE SYSTEM SHALL not look in `.worktrees/`.
  e.g. `.worktrees/2/test_x.py` only → no pytest/unittest guess

## Not in scope
- Excludes for other tools that walk the tree (jest, tsc, IDEs, Docker): the project's job; README says so in one line.
- Moving existing sibling worktrees: they keep working, and `tidy` removes them as today.

## How
```
worktree_path <id>   main_root/.worktrees/<id>      (was: dirname(main_root)/basename.<id>)
new.sh / open.sh     worktree add, then exclude_worktrees: grep -qx '/.worktrees/' || echo >> "$(git rev-parse --git-common-dir)/info/exclude"
init.sh              .gitleaks.toml paths + '^\.worktrees/'; find -not -path './.worktrees/*'
```
D-78.1 `.git/info/exclude`, not `.gitignore`, because it needs no commit and covers repos that adopted sdd before this; every clone that makes a worktree writes its own.
D-78.2 One fixed folder name, no setting: the user asked for no worktree setting.
D-78.3 `tidy` keeps finding worktrees through `git worktree list`, so old sibling ones need no code.

## Security
none: a path change and one line in the clone's own exclude file; no input crosses a trust boundary. gitleaks keeps scanning the main checkout (FR-78.3 only skips the copies).

## Done when
DOD-78.1 In this repo, `sdd new … --worktree` makes `.worktrees/<id>`, an agent works there without leaving the repo folder, and `git status` in the main checkout stays clean.

## Tasks
- [x] T-78.1 Failing tests: the new path from main and from a worktree, the exclude line once and a clean status, FR-78.1 FR-78.2 (files: tests/t_new.sh, tests/t_open.sh; test: for t in new open; do SRC=$PWD SH=dash dash tests/t_$t.sh || exit 1; done; expect: fail; size: S)
- [x] T-78.2 `worktree_path` and the exclude line; update tests that name `app.<id>` (t_new, t_open, t_roadmap, t_tidy and any other), FR-78.1 FR-78.2 (files: .sdd/core/lib/common.sh, .sdd/core/cmd/new.sh, .sdd/core/cmd/open.sh, tests/; test: for t in new open roadmap tidy ship agents expect; do SRC=$PWD SH=dash dash tests/t_$t.sh || exit 1; done; size: M)
- [ ] T-78.3 init: gitleaks skip, tip and Python search; README, design.md and the sdd-dev skill name the new path, FR-78.3 FR-78.4 (files: .sdd/core/cmd/init.sh, tests/t_security.sh, tests/t_init.sh, README.md, specs/design.md, .claude/skills/sdd-dev/SKILL.md; test: for t in security init; do SRC=$PWD SH=dash dash tests/t_$t.sh || exit 1; done; size: S)

## Built
<!-- Written by the agent at the end of the build, for the review: per requirement what
changed (file:line) and which test proves it; deviations from the plan and why; follow-ups. -->

## Review (optional)
<!-- What to change, one per line (the agent writes what the human asks). The agent works through them
and says under "## Built" what it changed for each. -->

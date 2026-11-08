---
id: 66
type: fix
title: Adoption: worktree setup, gate prompt, smaller scan, staging by name
status: open
created: 2026-11-08
approved: 3995176ed930f390ec04cbb8aa77f76a1be1dca8 2026-11-08 joexbayer
---
# 66 Adoption: worktree setup, gate prompt, smaller scan, staging by name

## Current behaviour
From the Lith adoption:
1. `sdd new --worktree` leaves a worktree that can't build (nothing seeds it), and `task done`'s throwaway checkout has the same problem, so a test can go red for that alone.
2. `init` picked `make check`, which was not Lith's real per-change gate, and only mentioned it in passing.
3. `gitleaks dir` read everything git ignores (5.7 GB of `build/`).
4. `ship` refused on an untracked `.DS_Store`.
5. README and MIGRATE say `git add -A`, which swept in unrelated work.

## Expected behaviour
FR-66.1 WHEN `[worktree] setup` is set THE SYSTEM SHALL run it in a worktree made by `sdd new --worktree` and in `task done`'s throwaway checkout before the test.
  e.g. `setup = make seed` → the new worktree builds; a failing setup in `new` warns and keeps the item; in `task done` it stops with the reason and never counts as red
FR-66.2 WHEN `init` picks a gate THE SYSTEM SHALL say it runs before every ship and ask the human to confirm it is the real one.
  e.g. `gate    make check runs before every ship. Your real per-change gate? If not, edit [check] run in .sdd/config`
FR-66.3 WHEN `init` writes `.gitleaks.toml` THE SYSTEM SHALL skip the directories git ignores at that moment; ignored files are still scanned.
  e.g. `build/` ignored → `^build/` in the allowlist; a key in `.env` is still found
FR-66.4 WHEN `sdd sync` runs THE SYSTEM SHALL keep `.DS_Store` out of git for that clone.
  e.g. `.DS_Store` in `.git/info/exclude`; `ship` no longer refuses
FR-66.5 WHEN the docs show the adoption commit THE SYSTEM SHALL stage what init made by name.
  e.g. `git add .sdd AGENTS.md` and `.gitleaks.toml` if written

How: `new.sh` after `sync_here`; `task.sh` `red_without_code` after the worktree add; `init.sh` from `git ls-files --others --ignored --exclude-standard --directory`, directories only, regex-escaped; `sync.sh` one line (per clone, unlike init; `exclude` anchors to the root, so a plain pattern).
D-66.1 Scan skip listed at init, in a file the team can read and edit. gitleaks has no "respect .gitignore" for `dir`; tried: a `paths` allowlist skips the directory. Ceiling: a directory ignored later is scanned until added (a tip in MIGRATE).
D-66.2 No warn-only tier for `[check]`, and no change for `sdd-builder` mid-session: one report each, and the second is Claude Code behaviour.

## Must not change
- `.claude/worktrees/` stays skipped; a team's own `.gitleaks.toml` is left alone; `new` without `--worktree` and an unset `setup` behave as today.

## Security
`setup` is a command from the project's config, the same trust as `[check] run`, and `task done` still runs only for an approved plan. The scan skips only directories git will not commit; ignored files such as `.env` stay scanned.

## Test
`tests/t_task.sh` or `t_worktree` cases (FR-66.1: runs in both places, failure paths), `tests/t_init.sh` (FR-66.2), `tests/t_security.sh` (FR-66.3, real gitleaks when installed), `tests/t_agents.sh` (FR-66.4), grep in `t_prompts_tests.sh` (FR-66.5). Written first, seen to fail.

## Built
- FR-66.1: `.sdd/core/cmd/new.sh` runs `worktree.setup` in the new worktree after `sync_here` (failure warns, item kept); `.sdd/core/cmd/task.sh` runs it in `red_without_code`'s checkout before the test (failure dies with the reason, cleanup by the trap, never red); commented `[worktree]` entry in `.sdd/core/config`. Tests: `tests/t_new.sh` (runs in worktree; failing setup warns), `tests/t_expect.sh` (failing setup stops, unticked, cleaned; good setup lets the red run).
- FR-66.2: `init.sh` prints the `gate    ... runs before every ship. Your real per-change gate? ...` line. Test: `tests/t_init.sh`.
- FR-66.3: `init.sh` appends each ignored directory (`git ls-files --others --ignored --exclude-standard --directory`, `/`-ending, not `.claude/worktrees/`) as a regex-escaped `^dir/` to `paths`. Test: `tests/t_security.sh` with real gitleaks: `build/` and `out\.dir/` skipped, `.env` and `src/` still reported, a repo's own file untouched. MIGRATE.md secret-scan bullet has the tip.
- FR-66.4: `sync.sh` adds a plain `.DS_Store` line to `info/exclude` once. Test: `tests/t_agents.sh` (one line, `sub/.DS_Store` not in status). Did not run ship itself.
- FR-66.5: README.md and MIGRATE.md use `git add .sdd AGENTS.md` plus a comment naming `.gitleaks.toml`, then `git commit`. `init` makes only `.sdd/`, `AGENTS.md`, `.gitleaks.toml` (checked in a throwaway repo; `sync` files are excluded). Test: `tests/t_prompts_tests.sh` (grep).
- Deviations: none. Notes: the new-worktree setup log is a temp file in the worktree, removed after. `sdd check` passed (212 s, over the 150 s budget warning). `SDD_PERF=1` timing run not done.

## Review (optional)
<!-- The human's review notes: what to change, one per line. The agent works through them
and says under "## Built" what it changed for each. -->

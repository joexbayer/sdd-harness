---
id: 46
type: fix
title: Secret scan skips agent worktree copies
status: open
created: 2026-11-01
approved: cc5ee4a8da5a91107a8e568022ee8516d75bf982 2026-11-01 joexbayer
---
# 46 Secret scan skips agent worktree copies

## Current behaviour
Found in the narrow pilot (2026-10-31): the gitleaks check init adds, `gitleaks dir . --no-banner`,
scans every file on disk, ignored ones included (gitleaks 8.30.1 `dir` has no option to honour
`.gitignore`). Claude Code's `isolation: worktree` agents keep full copies of the repo under
`.claude/worktrees/agent-*` inside it, so narrow's 12 test-fixture keys became "leaks found: 144";
`.gitleaksignore` fingerprints include the path and do not match the copies. sdd's own item
worktrees live beside the repo (`worktree_path`), and gitleaks' default rules already skip
`node_modules/`, so agent worktrees are the case left.

## Expected behaviour
FR-46.1 WHEN `sdd init` runs, `[check] run` has a `gitleaks ` command, and the repo has no
`.gitleaks.toml` THE SYSTEM SHALL write the `.gitleaks.toml` below (gitleaks' default rules plus an
allowlist for `.claude/worktrees/`) and print
`wrote .gitleaks.toml (gitleaks' default rules; skips .claude/worktrees/, agents' copies of the repo)`
  e.g. a key in `.claude/worktrees/agent-1/f.go` and one in `real.go` → gitleaks reports only
  `real.go` (probed with gitleaks 8.30.1)

    # Written by sdd init. gitleaks' default rules, minus copies of the repo that git never commits.
    [extend]
    useDefault = true

    [allowlist]
    description = "agent worktrees (Claude Code isolation: worktree): copies git does not commit"
    paths = ['''^\.claude/worktrees/''']

FR-46.2 WHEN `.gitleaks.toml` exists and does not mention `.claude/worktrees` THE SYSTEM SHALL
leave it as it is and print
`tip     .gitleaks.toml: add '^\.claude/worktrees/' to its allowlist paths, or gitleaks also scans agents' worktree copies of the repo`
  e.g. an existing `.gitleaks.toml` with only `[extend]` → unchanged, that tip printed
FR-46.3 WHEN `.gitleaks.toml` already mentions `.claude/worktrees`, or `[check] run` has no gitleaks
command, THE SYSTEM SHALL write and print nothing about it.
  e.g. init run twice → the second run prints neither line; no gitleaks → no `.gitleaks.toml`
FR-46.4 WHEN a user reads the README's "Your gate." bullet THE SYSTEM SHALL say init writes
`.gitleaks.toml` to skip agent worktrees, and that fixtures are allowlisted there or in
`.gitleaksignore`.
  e.g. the bullet names `.gitleaks.toml` and `.claude/worktrees/`

How: `.sdd/core/cmd/init.sh`, after the config block (so a rerun on an existing install, the
upgrade path, also does it): `git config -f "$config" --get-all check.run | grep -q '^gitleaks '`
gates it; then `[ -f .gitleaks.toml ]` and `grep -qF '.claude/worktrees' .gitleaks.toml` pick
FR-46.1, FR-46.2 or FR-46.3. The file is written with a heredoc. README: the bullet's gitleaks
sentence.

D-46.1 An allowlist in `.gitleaks.toml`, not another scan mode: `gitleaks git <base>..HEAD` misses
uncommitted and untracked work and its fingerprints carry commit hashes that change on rebase;
`gitleaks dir` cannot take a file list (`git ls-files`).
D-46.2 The repo's own `.gitleaks.toml` (the standard place gitleaks reads, which the team owns
and commits), not `--config .sdd/…`: a `--config` flag would override a team's own file.
D-46.3 The single `[allowlist]` table, not `[[allowlists]]`: both work in 8.30.1 (probed); the
single form also works in older 8.x releases.
D-46.4 Only `.claude/worktrees/`: the one in-repo copy seen; other agents' folders can be added by
the team. No test runs real gitleaks (the suite fakes it, as `t_security.sh` does); the
skip itself was probed by hand.

## Must not change
- An existing `.gitleaks.toml` is never modified.
- The gitleaks `check.run` line and the "install gitleaks" tip stay as they are.
- init stays idempotent: a second run changes no files.

## Security
Allowlisting a path hides real secrets put there → only `.claude/worktrees/`, which git does not
commit (it is a copy of tracked files, and the originals are still scanned); the file is
written into the repo where the human sees and commits it. No new dependency.

## Test
`tests/t_security.sh`, extending the FR-12.6 case (fake gitleaks on PATH):
- `gl1`: after init, `.gitleaks.toml` equals the FR-46.1 text and the output has the FR-46.1
  line; a second init prints neither the FR-46.1 nor the FR-46.2 line (FR-46.1, FR-46.3).
- a new repo with its own `.gitleaks.toml` (`[extend]` only): after init it is unchanged and
  the output has the FR-46.2 tip (FR-46.2).
- `gl2` (no gitleaks): no `.gitleaks.toml` (FR-46.3).
Fails now: no file is written and no tip is printed.

## Built
<!-- Written by the agent at the end of the build, for the review: per requirement what
changed (file:line) and which test proves it; deviations from the plan and why; follow-ups. -->

## Review (optional)
<!-- The human's review notes: what to change, one per line. The agent works through them
and says under "## Built" what it changed for each. -->

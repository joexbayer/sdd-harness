---
id: 48
type: feature
title: Docs-only changes skip the code checks
status: open
created: 2026-11-01
approved: 5228f864afab91944aad69a92e06b7ef97e2a8bc 2026-11-01 joexbayer
---
# 48 Docs-only changes skip the code checks

## Why
narrow (pilot, 2026-11-01) item 2 changed only AGENTS.md, a skill and ROADMAP.md, yet `sdd check`
ran its whole ~200 s gate (Go tests) for code that cannot have changed. The user wants the loop
fast, and wants this as config (2026-11-01). The secret scan must keep running on docs: a key
pasted into a .md file is still a leak.

## What changes
FR-48.1 WHEN `sdd check` (or the check `ship` runs) finds that every path this item changed matches a
`[check] docs` glob THE SYSTEM SHALL run the `[check] run` commands and skip the `[check] code`
commands, saying so in the pass line.
  e.g. docs = `*.md`, run = `echo ok`, code = `echo CODE-RAN`, only README.md changed →
  `✓ check passed for item 1 (0 s; docs-only change: skipped echo CODE-RAN)` and the log has
  no `CODE-RAN`
FR-48.2 WHEN any changed path matches no `docs` glob, or nothing changed since the base, or no
`docs` glob is set THE SYSTEM SHALL run both `run` and `code` commands (run first).
  e.g. README.md and `notes.md.txt` changed → `CODE-RAN` is in the log (`*.md` does not match
  `notes.md.txt`); the same with no `docs` set; on the base branch with no change → it runs
FR-48.3 WHEN `[check]` has `code` commands but no `run` command THE SYSTEM SHALL accept it (the
"no check configured" error only when both are missing), and refuse a `code` command that hides
failures like it refuses such a `run` command.
  e.g. only `code = echo ok` → check passes; `code = false || true` → "refusing a check that
  hides failures: false || true"
FR-48.4 WHEN a user reads the README's "Your gate." bullet or `.sdd/core/config` THE SYSTEM SHALL
find `code` and `docs` explained, with narrow's case as the example.
  e.g. README: `run = gitleaks dir . --no-banner`, `code = scripts/check.sh`, `docs = *.md`

## Not in scope (optional)
- init does not write `code` or `docs` (the defaults stay: no globs, so nothing is skipped).
- No cached result from the base branch: a docs-only check still runs the `run` commands.

## How
- `.sdd/core/lib/common.sh`: new `changed_paths`: paths this branch changed outside `$SPECS/`
  since the merge-base with `sdd.base`, committed, uncommitted and untracked
  (`git -C "$ROOT" diff --name-only --merge-base "$base"` with the merge-base fallback that
  `code_changed` uses, plus `git -C "$ROOT" ls-files --others --exclude-standard`). New
  `docs_only`: true when `cfg_all check.docs` is non-empty, `changed_paths` is non-empty, and every
  path matches some glob in a POSIX `case "$p" in $g)` (in a case pattern `*` also matches `/`, so
  `*.md` covers every folder and `docs/*` all of docs/).
- `run_check`: `_cmds` = `cfg_all check.run`, then `cfg_all check.code` unless `docs_only`, in
  which case `CHECK_SKIPPED` holds the code commands joined with ", ". die "no check configured"
  only when both lists are empty; the masked check covers both lists.
- `.sdd/core/cmd/check.sh:16`: the pass line becomes
  `✓ check passed… ($CHECK_SECS s${CHECK_SKIPPED:+; docs-only change: skipped $CHECK_SKIPPED})`.
- `.sdd/core/config`: commented `code` and `docs` under `[check]`. README "Your gate." bullet.
Fixed names: config keys `check.code` and `check.docs`; shell functions `changed_paths`,
`docs_only`; variable `CHECK_SKIPPED`; the pass-line text above (pinned by T-48.1's test).

D-48.1 Split `run` (always) and `code` (skipped on docs-only), the user's choice (2026-11-01) over
special-casing gitleaks lines: explicit, and works for any scanner or linter.
D-48.2 `docs` has no default: what counts as docs is per repo (this repo's prompts are `.md`
and have tests; narrow's skills steer agents).
D-48.3 Shell case patterns, not regexes or `**`: POSIX, and `*` crossing `/` gives "any depth"
without a second syntax.

## Security
A wrong `docs` glob lets code skip `code` checks → only when every changed path matches; the
`run` commands (the secret scan) always run; the pass line names what was skipped, so the human
sees it in check output and review. No new dependency.

## Questions (optional)
<!-- Q-48.1 <question> → recommend: <answer>. Resolve before building. -->

## Done when
`tests/t_check_docs.sh` passes under sh and dash, and `sdd check` passes.

## Tasks (optional)
- [x] T-48.1 Docs-only skip in the check, FR-48.1, FR-48.2, FR-48.3 (files: .sdd/core/lib/common.sh, .sdd/core/cmd/check.sh, tests/t_check_docs.sh; test: SRC=$PWD SH=dash dash tests/t_check_docs.sh; size: S; expect: fail "docs-only change")
- [x] T-48.2 Document code and docs, FR-48.4 (files: README.md, .sdd/core/config; size: S)

## Built
- FR-48.1: `changed_paths` and `docs_only` at `.sdd/core/lib/common.sh:665-694`; `run_check`
  reads `check.code` and sets `CHECK_SKIPPED` (`:960-970`); the pass line at
  `.sdd/core/cmd/check.sh:16`. Proven by `tests/t_check_docs.sh` (README.md plus `docs/guide.txt`
  changed → the pass line names `echo CODE-RAN` as skipped, the log has `$ echo ok` and no
  `CODE-RAN`).
- FR-48.2: same functions; `tests/t_check_docs.sh` (`notes.md.txt` changed → code runs; no
  `docs` glob → code runs; on main with nothing changed → code runs).
- FR-48.3: `run_check` dies only when `run` and `code` are both empty, and the masked check
  covers both lists. `tests/t_check_docs.sh` (code-only passes; `code = false || true` refused).
- FR-48.4: `.sdd/core/config` `[check]` comment and the README "Your gate." bullet (docs).
- Deviation: T-48.1 had `expect: fail`, which sdd reads as "write the failing test": `sdd task
  done T-48.1` recorded the red run (failing on "docs-only change") and ticked it, so the code
  went in after it as a second commit under T-48.1's files (eb94e11). Plan T-48.1 as two tasks
  next time (test by planner, then code).
- Deviation in the test: the "on the base" case runs last, after reverting README.md and
  removing docs/, because uncommitted and untracked files follow a branch switch (so main
  really did have a docs-only change).
- Follow-up (narrow, problem 10): narrow's sdd upgrade (narrow eb16d34) copied this branch's work
  in progress, because init copies the source's working tree. Plan it as its own item.
- Security pass (fresh Sonnet reviewer, given only the diff): one finding, fixed. `git diff
  --name-only` lists only a rename's new path, so `git mv src/a.go docs/a.md` looked docs-only
  and skipped the code checks. `changed_paths` now passes `--no-renames` (both diff calls);
  `tests/t_check_docs.sh` moves `app.sh` to `docs/app.md` and expects the code checks to run
  (it fails without the flag). Quoted paths (newlines, non-ASCII) fail safe: they match no glob.
- Check: `sdd check` passed after the fix.
- The verifier ran on eb94e11, before the `--no-renames` fix (8213897); the fix's own test case was
  shown red without the flag (scratch copy) and green with it.
Verified by: claude-sonnet-5-5: 4 of 4 FRs proven; no findings

## Review (optional)
<!-- The human's review notes: what to change, one per line. The agent works through them
and says under "## Built" what it changed for each. -->

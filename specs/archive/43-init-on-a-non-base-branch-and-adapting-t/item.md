---
id: 43
type: fix
title: Init on a non-base branch, and adapting the gate
status: shipped
created: 2026-10-30
approved: c3d9232977d3590d7658b582fa64f5b2fe66bab6 2026-10-30 joexbayer
shipped: 2026-10-30
---
# 43 Init on a non-base branch, and adapting the gate

## Current behaviour
Found in the narrow pilot (a throwaway local clone, 2026-10-30). `sdd init` run on a feature
branch installs and commits nothing, and says nothing about the branch. If the install is then
committed there, `sdd new` branches the item from the base (`main`), which has no `.sdd/`, and
sdd vanishes from the working tree mid-command:
`.sdd/bin/sdd: line 16: …/.sdd/core/lib/common.sh: No such file or directory`.
Repro: `git switch -c wip; sdd init; git add -A; git commit -m sdd; sdd new chore x`.

The pilot also showed three settings every repo adapts, which the README's Customise section
does not mention: init guesses the gate per language (narrow's real gate is `scripts/check.sh`),
gitleaks fails on day one on test fixtures (12 fake keys in narrow's `_test.go` files), and the
30 s check budget warns on every run for a gate that takes about 3 minutes.

## Expected behaviour
FR-43.1 WHEN `sdd init` runs on a branch other than the base THE SYSTEM SHALL warn that new items
branch from the base, so the install must be committed on the base (or merged there) first.
  e.g. on `feature/wip` with base `main` → stderr has
  `sdd: warning: you are on feature/wip, not the base main: new items branch from main, so commit this install on main (or merge it there) before sdd new`
FR-43.2 WHEN `sdd init` runs on the base branch THE SYSTEM SHALL print no such warning.
  e.g. a fresh repo on `main` → no "not the base" line
FR-43.3 WHEN a user reads the README's Customise section THE SYSTEM SHALL tell them to adapt the
gate: point `[check] run` at the repo's own check script, allow test fixtures in gitleaks
(`.gitleaksignore` with the fingerprints gitleaks prints, or an allowlist in `.gitleaks.toml`),
and set `[check] budget` to the gate's real time (0 turns the warning off).
  e.g. README Customise has a "Your gate." bullet naming `run`, `.gitleaksignore` and `budget`

How: in `.sdd/core/cmd/init.sh`, after the config block, compare `current_branch` with
`sdd.base` from the written config and `warn` when they differ (one `if`). Detached HEAD
(`current_branch` empty) prints nothing. README: one bullet under "## Customise".

D-43.1 A warning, not a refusal: installing on a branch is right when main is protected and the
install goes in by pull request; the warning says what to do in both cases.
D-43.2 Not a check in `sdd new` (refuse when the base lacks `.sdd/`): on a fresh install people
run `sdd new` before committing `.sdd/`, and the untracked folder survives the switch, so such a
check would refuse a working flow.
D-43.3 FR-43.3 is docs; no test pins the README wording.

## Must not change
- Base detection (`detect_base`): a repo with `main` still gets base `main` from a feature branch.
- init stays idempotent: a second run changes no files (it may warn again).
- No new config keys or commands.

## Security
none: a warning line and a README bullet; no input, secrets or new dependency.

## Test
`tests/t_init.sh`: the existing "wip" case (init on `feature/wip`) asserts the FR-43.1 warning
text `not the base main`; the "go" case (init on `main`) asserts it is absent (FR-43.2). Both
together tell the right rule from "always warn" and "never warn". Fails now: no such warning.

## Built
- FR-43.1: `.sdd/core/cmd/init.sh:61-65` compares `current_branch` with the written `sdd.base` and
  warns when they differ; detached HEAD prints nothing (tried by hand). Proven by
  `tests/t_init.sh:47-49` (the existing init-on-`feature/wip` case asserts the example literally).
- FR-43.2: same `if`; `tests/t_init.sh:12` asserts no "not the base" line on `main`.
- FR-43.3: `README.md:245-249`, a "Your gate." bullet under Customise (no test, D-43.3). Checked in
  the narrow pilot clone: the 12 fingerprints from `gitleaks dir . -v` in `.gitleaksignore` turn
  gitleaks green (exit 0).
- Deviation: the bullet says `gitleaks dir . -v` prints the fingerprints, because plain
  `gitleaks dir .` prints only a count.
- Check: `sdd check` passed (138 s).
- Security pass (fresh Sonnet reviewer, given only the diff): no findings.
Verified by: claude-sonnet-5-5: 3 of 3 FRs proven; no findings

## Review (optional)
<!-- The human's review notes: what to change, one per line. The agent works through them
and says under "## Built" what it changed for each. -->

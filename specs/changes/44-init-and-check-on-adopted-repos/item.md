---
id: 44
type: fix
title: Init and check on adopted repos
status: open
created: 2026-10-31
approved: 2860705b6955d5a11f868c5a336b143af974bf74 2026-10-31 joexbayer
---
# 44 Init and check on adopted repos

## Current behaviour
Found when narrow moved over to sdd for real (2026-10-31, narrow fc4b190 and f23bc9e):
1. narrow's constitution is 14 prose articles (`### I. Mechanism in Go, policy in Lisp` plus
   bullets). `articles()` (`.sdd/core/lib/common.sh:1555`) finds none, and nothing says so:
   `next` and `review` show no rules and check enforces none, while the file is still guarded
   as the constitution.
2. narrow's `.gitignore` has `bin/` (Go build output), which also matches `.sdd/bin/`. init
   said nothing, `git add -A` committed sdd without its launcher, and a fresh checkout of main
   had no `.sdd/bin/sdd`.
3. init guessed `go vet ./...` and `go test ./...` although narrow has its own gate,
   `scripts/check.sh` (gofmt, vet, test, build size).
4. The README says nothing about moving a Spec Kit repo over (where the constitution goes, what
   happens to `.specify/`).
Also carried here: the experiment README listed `XP_FAKE_COST=8 … B --dry` as stopping on the
spend cap; the cap is $150, so it never does (commit b087293 drops the line; the A line at
$60 a run stops at "$180.00 > $150").

## Expected behaviour
FR-44.1 WHEN `specs/constitution.md` exists but has no `C-<n>` article THE SYSTEM SHALL print, in
`sdd check` (which still passes), in `sdd next` (plan and build) and in `sdd review`, one line:
`⚠ specs/constitution.md has no C-<n> articles, so no rule is shown or enforced: write each rule as "C-1 <rule>" with indented Why: and Enforced: lines (through an amendment item)`
  e.g. a constitution holding only `### I. Mechanism in Go` and a bullet → check exits 0 and
  prints that line; next and review print it too
FR-44.2 WHEN the constitution has at least one `C-<n>` article, or does not exist, THE SYSTEM SHALL
print no such line.
  e.g. the C-1/C-2 constitution in `tests/t_constitution.sh` → no "has no C-<n> articles"
FR-44.3 WHEN `sdd init` runs and git ignores `.sdd/bin/sdd` THE SYSTEM SHALL warn, naming the
ignore rule:
`sdd: warning: .sdd/bin/sdd is ignored by git (.gitignore:1:bin/): commit it with git add -f, or anchor the pattern to the root (/bin/)`
  e.g. `.gitignore` = `bin/` → that warning; no `.gitignore` → no warning
FR-44.4 WHEN `sdd init` writes a new config and the repo has an executable `scripts/check.sh` THE
SYSTEM SHALL set it as the only detected `[check] run` (gitleaks still joins when installed),
instead of the language guesses.
  e.g. `go.mod` + executable `scripts/check.sh` → `run = scripts/check.sh`, no `go vet`/`go test`
FR-44.5 WHEN there is no executable `scripts/check.sh` but a `Makefile` with a `check:` target
THE SYSTEM SHALL set `make check` instead of the language guesses.
  e.g. `go.mod` + Makefile `check:` → `run = make check`
FR-44.6 WHEN a user reads the README THE SYSTEM SHALL say how to move a Spec Kit repo over:
remove `.specify/`, its skills and its AGENTS.md block; move the constitution to
`specs/constitution.md` and rewrite its rules as `C-<n>` articles in an amendment item; old
`specs/NNN-*` folders can stay. The "Your gate." bullet says init prefers `scripts/check.sh`
and `make check`.
  e.g. README has a "Moving from Spec Kit" paragraph under "## Compared with Spec Kit"

How:
- `.sdd/core/lib/common.sh`: new `no_articles` after `articles()`: prints the FR-44.1 line
  (with `$CONST`) when `$CONST` exists and `articles` yields no `C-` line; otherwise nothing.
  Called once each in `.sdd/core/cmd/check.sh` (next to the budget warning, any exit),
  `.sdd/core/cmd/next.sh` (the `plan | build` constitution block) and
  `.sdd/core/cmd/review.sh` (before the "Constitution: confirm" block).
- `.sdd/core/cmd/init.sh`: in `detect_checks`, first `[ -x scripts/check.sh ]` → print it and
  return; else a Makefile matching `^check:` → `make check` and return; then the language
  guesses as today. After the install block: `git check-ignore -v "$DIRNAME/bin/sdd"`; when it
  matches, `warn` with its source field (`<file>:<line>:<pattern>`).
- `README.md`: the "Moving from Spec Kit" paragraph and the gate-bullet sentence.

D-44.1 A warning, not a failed check: a failure would block every item in an adopted repo
until its rules are rewritten; the line shows in every check, next and review, which the human
reads (the bug was the silence). The user agreed (2026-10-31).
D-44.2 No automatic constitution conversion: rewriting rules as articles is judgment work for an
amendment item, with the human.
D-44.3 init warns about the ignored launcher and does not edit `.gitignore` or force-add: the
ignore file is the repo's. `git check-ignore` stays quiet once the launcher is tracked, so the
warning goes away after `git add -f`.
D-44.4 `scripts/check.sh` must be executable (check.run runs it as a command); a non-executable
one falls back to today's guesses.
D-44.5 The budget warning under machine load (283 s vs about 190 s in narrow) is working as
designed: no change.
D-44.6 FR-44.6 is docs; no test pins the README wording. The experiment README fix (b087293) was
committed before approval, carried from its own branch.

## Must not change
- The language guesses for repos without `scripts/check.sh` or a `check:` target (t_init.sh's
  go, python, bare cases) and the `make test` fallback.
- A malformed `C-<n>` article still fails the check (FR-3.1).
- init stays idempotent and adds no config keys or commands.

## Security
none: two warnings and a detection rule. init now picks `scripts/check.sh` as the gate, a file
already in the repo the human installs into; the human reads the "checks:" line init prints and
the config, as with today's guesses.

## Test
- `tests/t_constitution.sh` (new section at the end, FR-44.1, FR-44.2): a fresh repo whose
  constitution is prose → check exits 0 with the FR-44.1 line, next (plan) and review show it;
  the existing C-1/C-2 constitution → check output has no "has no C-<n> articles".
- `tests/t_init.sh` (FR-44.3 to FR-44.5): a repo with `.gitignore` = `bin/` → the FR-44.3 warning
  text; the go case (no `.gitignore`) → absent. `go.mod` + executable `scripts/check.sh` →
  check.run (without gitleaks) is exactly `scripts/check.sh`; `go.mod` + Makefile `check:` →
  exactly `make check`; the go case still gets `go vet ./...|go test ./...`.
Each fails now: no such lines, and the guesses win.

## Built
<!-- Written by the agent at the end of the build, for the review: per requirement what
changed (file:line) and which test proves it; deviations from the plan and why; follow-ups. -->

## Review (optional)
<!-- The human's review notes: what to change, one per line. The agent works through them
and says under "## Built" what it changed for each. -->

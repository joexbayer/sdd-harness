---
id: 49
type: fix
title: Init names its source, and articles keep their whole rule
status: shipped
created: 2026-11-01
approved: 10c9c8de616bd9d96ac008d8b8ca3c07ea26b310 2026-11-01 joexbayer
shipped: 2026-11-01
---
# 49 Init names its source, and articles keep their whole rule

## Current behaviour
From the narrow pilot (2026-11-01):
1. Problem 10: `init` copies `.sdd/bin` and `.sdd/core` from the sdd it runs from as they are on
   disk. narrow upgraded (narrow eb16d34) while this checkout was on the item 48 branch, so it got
   unshipped work, and nothing said so. The installed `VERSION` says `0.1.0`, so no one can tell
   which sdd a repo has.
2. Problem 11: `articles()` (`.sdd/core/lib/common.sh`) keeps only the `C-<n>` line as the rule
   and drops the indented lines before `Why:`. `next` and `review` then show rules cut
   mid-sentence (narrow's C-2 "…validated against the snapshot the model saw,"; this repo's C-1
   and C-4 too), and review's checklist is what the human confirms.

## Expected behaviour
FR-49.1 WHEN `init` copies sdd into a repo (install or update) from an sdd folder inside a git
checkout THE SYSTEM SHALL write `<version> (<12-char commit>)` to the installed `.sdd/VERSION`,
with `, uncommitted changes` added when that folder has any.
  e.g. source at commit 1a2b3c4d5e6f…, clean → `.sdd/VERSION` = `0.1.0 (1a2b3c4d5e6f)`; init
  prints `installed sdd 0.1.0 (1a2b3c4d5e6f) into .sdd/`
FR-49.2 WHEN that source folder has uncommitted changes THE SYSTEM SHALL still copy, and warn
`sdd: warning: the sdd you install from (<source .sdd folder>) has uncommitted changes, and they are copied too: install from a clean checkout of its base branch`
  e.g. an uncommitted edit in the source's `core/cmd/help.sh` → that warning; VERSION ends
  `, uncommitted changes)`
FR-49.3 WHEN the source checkout is on a branch other than its own base (`sdd.base` in the
source's `config`, default main) THE SYSTEM SHALL warn
`sdd: warning: the sdd you install from (<source .sdd folder>) is on <branch>, not <base>: unshipped work is copied too`
  e.g. source on `feature/48-x` → that warning; on `main` → none
FR-49.4 WHEN the source folder is not in a git checkout THE SYSTEM SHALL copy as today, with the
plain version and no warning.
  e.g. an unpacked copy → `.sdd/VERSION` = `0.1.0`
FR-49.5 WHEN a constitution article has indented lines between its `C-<n>` line and `Why:` THE
SYSTEM SHALL join them (one space each) into the rule that `next`, `review` and `check` show.
  e.g. `C-2 Every edit goes through the buffer,` + `  validated against the snapshot.` →
  `[ ] C-2 Every edit goes through the buffer, validated against the snapshot.`

How:
- `.sdd/core/cmd/init.sh`: a `source_stamp` step before each copy (install and update, never
  when the target is the source itself). `git -C "$SDD_HOME" rev-parse --short=12 HEAD` (if it fails:
  not a checkout, FR-49.4), `git -C "$SDD_HOME" status --porcelain -- .` for dirt (FR-49.2),
  `git -C "$SDD_HOME" symbolic-ref --quiet --short HEAD` against
  `git config -f "$SDD_HOME/config" sdd.base` (default main) (FR-49.3). After `cp`, write the stamp
  to `$target/VERSION`.
- `.sdd/core/lib/common.sh` `articles()`: in the awk, an indented line that is not `Why:` or
  `Enforced:`, while an article is open and before its `Why:`, is appended to `rule` (leading
  spaces trimmed, joined by one space). Lines after `Why:` stay ignored.

D-49.1 Warn, not refuse: the test suite and sdd development install from a working checkout on
an item branch; the warning plus the stamped VERSION make an accidental unshipped copy visible
in the install output and in the repo's committed `.sdd/VERSION`.
D-49.2 The stamp is the source's commit, not a release number: sdd has no releases yet, and a
commit is exact. The VERSION file stays one line.
D-49.3 Continuation lines join only before `Why:`; a multi-line `Why:` stays as today (not shown).

## Must not change
- Running the repo's own `.sdd/bin/sdd init` copies nothing and stamps nothing.
- The update rules of item 45 (up to date, refuse on uncommitted target changes, replace).
- One-line articles, malformed-article errors (FR-3.1) and the article budget.

## Security
none: extra warnings and a stamp in VERSION; read-only git calls on the source; no input or dependency.

## Test
- `tests/t_init.sh` (FR-49.1 to FR-49.4): build a source sdd in `$T/src` (copy `$SRC/.sdd`, `git
  init`, commit on main) and run `$SH $T/src/.sdd/bin/sdd init` in fresh repos: clean on main →
  VERSION `<version> (<that commit>)`, no warning; after an uncommitted edit in the source → the
  FR-49.2 warning and `, uncommitted changes)`; source switched to `feature/x` → the FR-49.3
  warning; a source copy outside any checkout → plain VERSION, neither warning.
- `tests/t_constitution.sh` (FR-49.5): a two-line article shows joined in `next` and `review`.
Fails now: VERSION is plain, no warnings, the second rule line is missing.

## Built
- FR-49.1: `source_stamp` at `.sdd/core/cmd/init.sh:8-23`, called before each copy (install
  `:27`, update `:36`); the stamp is written to the installed VERSION after the copy (`:29`,
  `:39`). Proven by `tests/t_init.sh:107-116` (a source repo built in the test: VERSION and the
  "installed" line carry its commit).
- FR-49.2: same function, `git status --porcelain` on the source folder. `tests/t_init.sh:118-124`.
- FR-49.3: same function, branch against the source's `sdd.base`. `tests/t_init.sh:126-131`.
- FR-49.4: `rev-parse` fails outside a checkout and the plain version stays.
  `tests/t_init.sh:133-138`.
- FR-49.5: `articles()` at `.sdd/core/lib/common.sh:1613-1614`. Proven by
  `tests/t_constitution.sh:144-151` (two-line rule whole in next and review). sdd's own C-1 now
  shows whole in `sdd next`.
- Security pass (the fresh verifier, Sonnet, read the diff for it): no findings; only read-only git
  calls on the source, and the one write is the installed `.sdd/VERSION`.
- Follow-up (noted by the verifier): the update path's stamp has no assertion of its own; it is
  the same `source_stamp` and the same two lines as install.
- Check: `sdd check` passed (130 s).
Verified by: claude-sonnet-5-5: 5 of 5 FRs proven; no findings

## Review (optional)
<!-- The human's review notes: what to change, one per line. The agent works through them
and says under "## Built" what it changed for each. -->

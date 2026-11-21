---
id: 79
type: feature
title: Team standards: rules with IDs, checked by the verifier
status: shipped
created: 2026-11-21
approved: 1e2fdc33075f62668774378fcb32c9fc2d113dbd 2026-11-21 joexbayer
shipped: 2026-11-21
---
# 79 Team standards: rules with IDs, checked by the verifier

## Why
A team's conventions (API errors, logging, naming a linter can't check) live nowhere an agent reads. ADRs record a decision once and pile up; agents don't read them, and nothing checks the code against them. Item 77 gave security a baseline the plan answers to, but the verifier never checks the code against it, and other conventions have no place at all.

## What changes
US-79.1 As a team lead I write our conventions once as short rules with IDs, and every item's builder follows them and its verifier checks them.
FR-79.1 WHEN `[standards] use` names a standard THE SYSTEM SHALL read it from `specs/standards/<name>.md`, else the built-in of that name; a name that is not `[A-Za-z0-9_-]+` or has no file is reported.
  e.g. `use = asvs-l2 api-errors`, only the built-in asvs-l2 exists → `✗ Standards: unknown standard api-errors (add specs/standards/api-errors.md)`
FR-79.2 WHEN `check` runs THE SYSTEM SHALL fail on a used standard that is malformed: front matter must give `status: advisory` or `status: enforced`; after a one-line summary every non-empty line is a rule `<ID> MUST|SHOULD <text>`; IDs are unique across all used standards.
  e.g. `api-errors.md` holds `Errors use problem+json.` as a rule line → `✗ standard api-errors:4: not a rule (<ID> MUST|SHOULD <text>)`
FR-79.3 WHEN `next` gives plan instructions and `[standards] use` is set THE SYSTEM SHALL list each standard on one line (name, status, rule count, summary, path), not its rules.
  e.g. `asvs-l2   advisory  9 rules  OWASP ASVS 5.0.0, level 2: most apps  (built-in .sdd/core/standards/asvs-l2.md)`
FR-79.4 WHEN the plan of a type with a Security section is checked (analyze, next, approve) and `[standards] use` is set THE SYSTEM SHALL need a line `Standards: <name> [(<note>)], …` or `Standards: none`, each name one of `[standards] use`; standard blocks, lite warns, as item 77 did.
  e.g. `Standards: asvs-l2 (V16 logging), gdpr` with gdpr not in use → `✗ Standards: gdpr is not in [standards] use (asvs-l2 api-errors)`
FR-79.5 WHEN `next` gives build instructions and the plan names standards THE SYSTEM SHALL print their rule lines, with each standard's status.
  e.g. `Standards (follow these rules): api-errors enforced` then `API-1 MUST error bodies use problem+json.`
FR-79.6 WHEN `review` runs THE SYSTEM SHALL print the named standards' rules for the verifier and the human, and a change to `specs/standards/` in full; the verifier prompt SHALL check the diff against each rule and cite its ID: an enforced MUST broken is must-fix, anything else broken is should-fix.
  e.g. verifier finding `must-fix API-1 (api-errors, enforced): src/api.ts:40 returns a plain-text 500`
FR-79.7 WHEN `init` runs THE SYSTEM SHALL write `[standards] use = asvs-l2`, and the built-ins (asvs-l1, asvs-l2, asvs-l3, masvs, llm-top10) SHALL be standards in this format, status advisory.
  e.g. fresh init → `git config -f .sdd/config standards.use` prints `asvs-l2`

## Not in scope
- Per-rule linters: a rule a tool can check goes in `check.run`, as today.
- Domain owners: CODEOWNERS on `specs/standards/` (README says so in one line).
- Pinning a standard's text at approval: the plan's `Standards:` line is pinned with the plan; the rules are read when used.
- Cloudflare's incident-report reviewer and stage tags.

## How
```
.sdd/config        [standards] use = asvs-l2 api-errors      (replaces [security] use)
specs/standards/api-errors.md            .sdd/core/standards/asvs-l2.md (moved from core/security/)
  ---
  status: enforced
  ---
  API errors: what every HTTP error returns.
  API-1 MUST error bodies use problem+json.
  API-2 SHOULD put a trace id in every error body.

common.sh  standard_file <name>   team file, else built-in (was security_file)
           standard_lint          check: front matter, rule lines, unique IDs        FR-79.2
           plan_extra             Standards: line → names, each in use               FR-79.4
next.sh    plan: catalog, one line each (was: whole files)                           FR-79.3
           build: rule lines of the named standards                                  FR-79.5
review.sh  named standards' rules; git diff of specs/standards/                      FR-79.6
role-verifier.md  one step: check each printed rule, cite the ID, tag by status
```
D-79.1 One mechanism for security baselines and team conventions: `[security] use` and `core/security/` are renamed, no shim; MIGRATE.md says how to move.
D-79.2 Status per file, not per rule: promoting a standard is one word. A built-in is promoted by copying it into `specs/standards/` (a team file replaces a built-in of that name, as in item 77).
D-79.3 Decisions stay `D-n` lines in their item (history); a decision that binds later work becomes a standard rule, or a constitution article when it is a ground truth. design.md says this in one line, instead of ADRs.
D-79.4 Any item may change a standard; review shows the diff in full. No amendment-only gate: it would make teams route every convention change through a special item.
D-79.5 The `Standards:` line names files (`asvs-l2`), not prose (`ASVS L2`), so sdd can check and print them; notes go in parentheses. It is in the plan text, so approval pins it.

## Security
Standards: asvs-l2 (V1 encoding: standard names become paths)
- names from config and the plan become file paths → FR-79.1 allows only `[A-Za-z0-9_-]+`, loops run under `set -f`.
- a builder could drop an inconvenient standard from the `Standards:` line → the line is in the plan, so approval pins it.

## Done when
DOD-79.1 In a scratch repo, `use = asvs-l2 api-errors` with an enforced api-errors rule: next lists both at plan, approve refuses a plan without the Standards line, the build prompt shows API-1, and review prints it for the verifier.

## Tasks
- [x] T-79.1 Failing tests for FR-79.1–79.6: rename tests/t_security.sh to tests/t_standards.sh and rewrite it (files: tests/t_standards.sh, tests/t_security.sh, tests/lib.sh; test: SRC=$PWD SH=dash dash tests/t_standards.sh; expect: fail; size: M)
- [x] T-79.2 Lib and check: standard_file, standard_lint, plan_extra's Standards line, `[standards] use`; move and rewrite the built-ins as rules, FR-79.1 FR-79.2 FR-79.4 FR-79.7 (files: .sdd/core/lib/common.sh, .sdd/core/cmd/check.sh, .sdd/core/standards/, .sdd/core/security/; test: SRC=$PWD SH=dash dash tests/t_standards.sh; size: M)
- [x] T-79.3 next, review and the verifier prompt, FR-79.3 FR-79.5 FR-79.6 (files: .sdd/core/cmd/next.sh, .sdd/core/cmd/review.sh, .sdd/core/prompts/role-verifier.md; test: for t in standards reviewed verified prompts_tests; do SRC=$PWD SH=dash dash tests/t_$t.sh || exit 1; done; size: M)
- [x] T-79.4 init, templates, README, MIGRATE, design.md (D-79.3 line, §13), sdd-dev skill, FR-79.7 (files: .sdd/core/cmd/init.sh, .sdd/core/templates/, README.md, MIGRATE.md, specs/design.md, .claude/skills/sdd-dev/SKILL.md; test: for t in standards init; do SRC=$PWD SH=dash dash tests/t_$t.sh || exit 1; done; size: S)

## Built
- FR-79.1: `standard_file` (.sdd/core/lib/common.sh:524; team file, else built-in; refuses names outside `[A-Za-z0-9_-]+`); `plan_extra` (:612) reports unknown and bad names. Test: tests/t_standards.sh (hipaa, `../x`).
- FR-79.2: `standard_lint` (common.sh:544), run by `run_check` (:1330), printed by check.sh:43 as `✗ standard <name>:<line>: …`. Test: t_standards.sh (not a rule, bad status, duplicate ID, no front matter; the five built-ins pass together).
- FR-79.3: `standard_line` (common.sh:578), called in next.sh:136-146. Test: t_standards.sh (exact catalog line for api-errors, built-in path, no rules printed).
- FR-79.4: `plan_std_line`, `std_names` (common.sh:600-607) and `plan_extra`. Test: t_standards.sh (no line, `gdpr` not in use, `none`, note with a colon, refactor not asked, and DOD-79.1 in a fresh init repo).
- FR-79.5: `standard_block` (common.sh:585) from next.sh:126-129. Test: t_standards.sh (heading with statuses, API-1, API-2).
- FR-79.6: review.sh:127-134 (rules block, `Standards diff` in full); role-verifier.md step 4. Test: t_standards.sh (`+API-3` in the diff, prompt keywords).
- FR-79.7: init.sh:90 and :112; built-ins in .sdd/core/standards/ (git mv from core/security/, rewritten as rules, IDs ASVS1-/ASVS2-/ASVS3-, MASVS-, LLM-). Test: t_standards.sh (init config and message, status line of each built-in).
- Also: tests/lib.sh unsets `standards.use`; templates, README, MIGRATE.md, design.md (§13, D-79.3) and the sdd-dev skill updated.

Deviations:
- T-79.1: tests/t_security.sh was not renamed. Its FR-12/46/66 tests (sensitive files, gitleaks) have nothing to do with standards, so only the FR-77 part moved into the new tests/t_standards.sh and t_security.sh keeps the rest.
- T-79.2's test (the whole t_standards.sh) also covers next, review and init, so it could not pass before T-79.3 and T-79.4's code. I wrote all the code first, ticked each task in order, and committed each task's own files.
- Catalog and rule text: rule counts print as "N rules" even for 1; the path of a built-in is `$DIRNAME/core/standards/<n>.md` even when a `.sdd/local/` copy overrides it.
- Test example: the FR-79.2 example says line 4; the test's file has a 3-line front matter and a summary, so its bad line is 7 and the assertion says so.

Follow-ups (not built):
- Notes with nested parentheses in a `Standards:` line (`(V1 (a))`) split wrongly. Failure: a false "not in use" finding; likelihood low; cost: a small parser.
- A "none" among other names is dropped silently. Failure: none visible; likelihood low.

Verified by: claude-opus-5-5: 7 of 7 FRs proven; should-fix: standard_file's name check untested (fixed); 4 nits
Verifier fixes: t_standards.sh tests a plan naming `../x` reads nothing outside specs/standards/ (breaking standard_file's check now fails it). `std_use` (common.sh:530) reads each use name once, so a repeated name is not its own duplicate; tested. check prints malformed standards also when it exits 3 (check.sh). The catalog says "1 rule". Left: a Standards: line outside Security still counts (it is pinned with the plan either way); the plan-step word ceiling is measured with standards unset (the default is now shorter than before).
<!-- Written by the agent at the end of the build, for the review: per requirement what
changed (file:line) and which test proves it; deviations from the plan and why; follow-ups. -->

## Review (optional)
<!-- What to change, one per line (the agent writes what the human asks). The agent works through them
and says under "## Built" what it changed for each. -->

---
id: 77
type: feature
title: Security baseline: OWASP standards built in, team regimes added
status: open
created: 2026-11-19
approved: a32f1c25df981c9ab6574cf4d34a9053c9237b8a 2026-11-19 joexbayer
---
# 77 Security baseline: OWASP standards built in, team regimes added

## Why
Each item's Security section asks generic questions, but a project has no stated baseline: no "we build to ASVS L2", no place for the laws that apply to it (GDPR, NIS2, a national rule). So nobody asks per change which of them adds work, and a team's regimes live outside the plan.

## What changes
US-77.1 As a team I name the security standards we build to once, in `.sdd/config`, so that every plan says which of them this change touches.
FR-77.1 WHEN `[security] use` names standards THE SYSTEM SHALL, in `next` at the plan phase of a type with a Security section, print each one's file: `specs/security/<name>.md` if it exists, else the built-in `.sdd/core/security/<name>.md`.
  e.g. `use = asvs-l2 gdpr`, `specs/security/gdpr.md` exists → next prints "Security baseline ([security] use): asvs-l2 gdpr", then both files' text
FR-77.2 WHEN `[security] use` is set and the item's type has a Security section THE SYSTEM SHALL report a plan problem (analyze, next, and approve at the type's analyzed gate) if that section has no line starting `Standards:`.
  e.g. Security holds only "none: docs" → `✗ Security: no "Standards:" line (baseline: asvs-l2 gdpr): say which add work here, or none`
FR-77.3 WHEN a name in `[security] use` has neither file THE SYSTEM SHALL report it as a plan problem naming both paths.
  e.g. `use = asvs-l2 hipaa`, no hipaa file → `✗ Security: unknown standard hipaa (add specs/security/hipaa.md)`
FR-77.4 WHEN `init` writes a new config THE SYSTEM SHALL set `[security] use = asvs-l2` and say how to add a team regime.
  e.g. init → config has `use = asvs-l2`; output line "security asvs-l2 (OWASP ASVS level 2). Your laws and policies: specs/security/<name>.md, then add the name to [security] use"
FR-77.5 THE SYSTEM SHALL ship built-in files `asvs-l1`, `asvs-l2`, `asvs-l3`, `masvs` and `llm-top10`, each at most 15 lines: what it covers, its source (OWASP ASVS 5.0, MASVS 2, Top 10 for LLM Applications 2025) and the triggers that add work, by chapter or item.
  e.g. asvs-l2 names V6 Authentication, V8 Authorization, V16 Security Logging and Error Handling, … with one line each on what changes add work
US-77.2 As a planner I get one line per item, like "Standards: ASVS L2 (V16 logging). Regimes: NIS2, CRA; only logging for detection adds work here."

## Not in scope
- No built-in regimes (GDPR, NIS2, CRA, DORA, national rules): they depend on country and sector; teams add them as files.
- No compliance reports, evidence collection or per-control traceability.
- sdd's own repo sets no baseline: a CLI is not what ASVS targets.

## How
```
.sdd/config [security] use = asvs-l2 gdpr
        |
        v  security_files: each name -> specs/security/<n>.md, else .sdd/core/security/<n>.md
next (plan phase)  -> prints the baseline after the rules        FR-77.1
plan_extra         -> "Standards:" line missing / unknown name   FR-77.2, FR-77.3
                      (so analyze, next and approve report it at the analyzed gate)
init               -> security.use asvs-l2                       FR-77.4
```
D-77.1 One list, `use`, for standards and regimes alike, because both are just files of triggers; a team file with a built-in's name replaces it.
D-77.2 The missing line is a plan problem, not a new gate, because the analyzed gate already scales per type and profile (lite warns, standard blocks).
D-77.3 Levels are separate files (asvs-l1/l2/l3), because a name maps to one file with no parsing.
D-77.4 Built-in files are short trigger lists, not the standard's text, because agents know the standards; the file says what to look for.
D-77.5 Existing repos are not changed: no `use` means no baseline, as today.

## Security
Standards: ASVS L2 does not apply (a CLI with no web surface); this item adds no input, secrets or network.
- A team file is read from the repo into the agent's prompt → same trust as AGENTS.md and the item; accept: it is committed and reviewed like code.
- Built-in files could misstate a standard → FR-77.5 names the source version; the verifier checks chapter names against it.

## Done when
DOD-77.1 A new repo from init plans a feature, `next` shows the ASVS L2 triggers, and approve refuses until the Security section has a Standards line.

## Tasks
- [x] T-77.1 Failing tests: baseline printed with a team file replacing a built-in, missing Standards line and unknown name reported, init writes asvs-l2, the five built-in files exist and are at most 15 lines, FR-77.1 FR-77.2 FR-77.3 FR-77.4 FR-77.5 (files: tests/t_security.sh; test: SRC=$PWD SH=dash dash tests/t_security.sh; expect: fail; size: S)
- [x] T-77.2 `security_files` in common.sh; next.sh prints the baseline at the plan phase; plan_extra reports the missing line and unknown names, FR-77.1 FR-77.2 FR-77.3 (files: .sdd/core/lib/common.sh, .sdd/core/cmd/next.sh; test: for t in security analyze; do SRC=$PWD SH=dash dash tests/t_$t.sh || exit 1; done; size: M)
- [x] T-77.3 The five built-in files; the Security comment in feature, fix, chore and contract templates asks for the Standards line; init writes `use = asvs-l2` and the hint; design.md §13 and README note it, FR-77.4 FR-77.5 (files: .sdd/core/security/, .sdd/core/templates/, .sdd/core/cmd/init.sh, specs/design.md, README.md; test: for t in security init; do SRC=$PWD SH=dash dash tests/t_$t.sh || exit 1; done; size: M)

## Built
- FR-77.1: `security_file` (`.sdd/core/lib/common.sh`, above `plan_extra`) picks `specs/security/<n>.md`, else the built-in (through `sdd_path`, so `.sdd/local/security/` also works); `next.sh` prints `Security baseline ([security] use): …` and each file at the plan phase, only for types with a Security section. Test: `t_security.sh` (team gdpr file replaces a built-in; nothing when unset; a refactor shows none).
- FR-77.2, FR-77.3: `plan_extra` reports a Security section without a `Standards:` line and an unknown name, so analyze, next and approve show them at the analyzed gate (standard blocks, lite warns). Test: `t_security.sh`.
- FR-77.4: `init` writes `security.use asvs-l2` and the hint. Test: `t_security.sh`, incl. DOD-77.1 end to end (init repo: next shows V16, approve refuses until the Standards line exists).
- FR-77.5: `.sdd/core/security/` asvs-l1/l2/l3, masvs, llm-top10 (9–11 lines, source and version named; l1–l3 share triggers, D-77.4). Templates (feature, fix, chore, contract) ask for the Standards line. README and design.md §13 note it.
- Deviation: T-77.2 and T-77.3 in one commit: T-77.2's test file also asserts T-77.3 work (the plan's split was wrong).
- Deviation: `tests/lib.sh` `new_repo` unsets `security.use` next to the lite pin, so existing tests keep their meaning; t_security sets it.
- Deviation: the baseline prints before the plan prompt (next to Contracts), not after the rules; no prompt word ceiling moved.
- `use` loops run under `set -f` (no globbing); `type_facts` runs only when `use` is set.
- Known: `t_perf` over budget under load, on main too. Check 308 s (budget 150 s).
- Security pass (the verifier, on the diff): nothing exploitable; names read only `.md` files from config the repo commits.

Verified by: claude-opus-5-5: PASS; OWASP ASVS 5.0 / MASVS v2 / LLM Top 10 2025 names correct; mutants on team lookup and the Standards check caught; refactor exemption and init end to end were untested: added; glob and README nits fixed

## Review (optional)
<!-- What to change, one per line (the agent writes what the human asks). The agent works through them
and says under "## Built" what it changed for each. -->

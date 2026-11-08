---
id: 64
type: feature
title: /sdd-audit-states: find the state bugs the code can reach
status: open
created: 2026-11-08
---
# 64 /sdd-audit-states: find the state bugs the code can reach

## Why
A state-machine hunt on sdd-server (2026-11-08) found 5 reproduced bugs in code that had passed its tests, a verifier and a security
pass: bugs between features over time, which per-item checks cannot see. The user wants it repeatable. The prompt is a sweep, so it runs on demand.

## What changes
FR-64.1 WHEN `sdd sync <agent>` installs skills THE SYSTEM SHALL install `/sdd-audit-states`.
  e.g. `sdd sync claude` → `.claude/skills/sdd-audit-states/SKILL.md`
FR-64.2 WHEN the skill runs THE SYSTEM SHALL tell the agent to: take one area (ask if none is named); open a chore item; have a fresh subagent, read-only on the repo, find explicit and implicit state machines and the invalid states or moves the code can reach, through retries, concurrency, restarts and half-done failures, each CONFIRMED by a script or test that shows it, or PLAUSIBLE; keep `specs/kb/state-machines.md` short (machines with a confirmed bug or an invariant that matters, each invariant saying what enforces it); present a ranked list in chat; open one fix item per group the human picks, its regression test first.
  e.g. `/sdd-audit-states billing` → the ranked list in chat, `CONFIRMED` findings with the sequence and smallest fix

## Not in scope (optional)
- Running it automatically or per item; new commands, config or gates. A whole-repo mode: one area at a time keeps findings deep and tokens down.

## How
One text file, `.sdd/core/agents/skills/audit-states.md`, installed by the existing `install_skills`. The sync messages in `agents/claude.sh` and `codex.sh` name it; README's commands get a line.
D-64.1 A chore, not a spike: a spike's files don't land, and the findings note should.
D-64.2 Fixes are ordinary `fix` items: the same plan, approval and review; the audit fixes nothing itself.
Verification: the skill is text, so a test proves it is installed and says the rules. Whether it finds bugs was shown by the sdd-server hunt, whose prompt it reuses.

## Security
none: a text file; the hunt runs read-only on the repo and writes scripts to a temp folder.

## Questions (optional)
<!-- Q-64.1 <question> → recommend: <answer>. Resolve before building. -->

## Done when
`tests/t_agents.sh` passes under sh and dash; `sdd check` passes.

## Tasks (optional)
- [ ] T-64.1 The skill, sync messages and README, FR-64.1, FR-64.2 (files: .sdd/core/agents/skills/audit-states.md, .sdd/core/agents/claude.sh, .sdd/core/agents/codex.sh, README.md, tests/t_agents.sh; test: SRC=$PWD SH=dash dash tests/t_agents.sh; size: S)

## Built
<!-- Written by the agent at the end of the build, for the review: per requirement what
changed (file:line) and which test proves it; deviations from the plan and why; follow-ups. -->

## Review (optional)
<!-- The human's review notes: what to change, one per line. The agent works through them
and says under "## Built" what it changed for each. -->

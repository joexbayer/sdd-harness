---
id: 60
type: fix
title: Waiting for the human never blocks the stop hook; approve shows the plan diff
status: open
created: 2026-11-02
approved: a68c1123f7b7124db3bc16bf52671736fa627ff2 2026-11-02 joexbayer
---
# 60 Waiting for the human never blocks the stop hook; approve shows the plan diff

## Current behaviour
NarrowBot pilot, problem 12 (2026-11-02). A one-word fix in a task's `files:` voided the approval, so
the agent had to wait for the human, but `hook stop` (plan phase with code changes,
`.sdd/core/cmd/hook.sh:57`) kept blocking: "Do not build before the human approves". NarrowBot has
no block-once, so it could not end its turn: a deadlock. Claude Code blocks once, then lets go.
And re-approving gives the human nothing to judge: what changed in the plan is not shown.

## Expected behaviour
FR-60.1 WHEN the agent stops in the plan phase with code changes THE SYSTEM SHALL warn and let it stop
(exit 0): the next step is the human's. It still blocks in the build phase.
  e.g. plan changed after approval → stderr `sdd: item 1 has code changes but the plan is not ready (…). The next step is the human's: stop and ask them.`, exit 0; `--agent claude` gets a systemMessage, no `decision: block`
FR-60.2 WHEN the plan changed after an approval THE SYSTEM SHALL print what changed since that approval
(a unified diff of the plan part), in `sdd next` while waiting and in `sdd approve`.
  e.g. `files: a.sh` → `files: b.sh` in a task → lines `-… (files: a.sh…` and `+… (files: b.sh…` under `Plan changes since the last approval:`
FR-60.3 WHEN the plan was never approved THE SYSTEM SHALL print no such diff.
  e.g. a first `sdd approve` → no "Plan changes" line

How: `hook.sh` plan case: new message, `level=warn` (not the type's finish level).
`common.sh`: new `plan_changes`: the last commit whose subject is `docs(<id>): approve plan`, its item
file's `plan_part` against the current one, `diff -u` minus its two header lines, ticks normalised
as `plan_hash` does; prints the heading and diff, or nothing. Called in `next.sh` when WHYCODE is
`changed`, and in `approve.sh` before it pins.
D-60.1 Task details stay part of the approval (no metadata exemption): they are the contract; the
diff makes a one-word re-approval quick.

## Must not change
- The build-phase block (t_agents.sh, t_verified.sh); ship's refusal of code committed before approval.
- `next`'s git-call budget mid-build: `plan_changes` runs only while the plan changed.

## Security
none: a softer message in the plan phase (ship still refuses unapproved plans) and a read-only diff.

## Test
`tests/t_agents.sh`: code before approval → systemMessage with "The next step is the human's", no
`decision` (FR-60.1). `tests/t_roles.sh`: narrowbot plan phase exits 0; after approval with code
changed, exits 2 (build still blocks). `tests/t_phase.sh`: approve, change a word in the plan → `sdd
next` and `sdd approve` show `Plan changes since the last approval:` with the -/+ lines; the first
approve shows none (FR-60.2, FR-60.3). Fails now: blocks, and no diff.

## Built
- FR-60.1: `.sdd/core/cmd/hook.sh`: the plan-phase message says the next step is the human's, and
  a block level becomes warn (a finish level of off stays off). Tests: `tests/t_agents.sh`
  (systemMessage, no decision), `tests/t_roles.sh` (narrowbot: exit 0 waiting, exit 2 building).
- FR-60.2, FR-60.3: `plan_changes` in `.sdd/core/lib/common.sh`, called in `next.sh` (WHYCODE
  changed) and `approve.sh`. Test: `tests/t_phase.sh` (-/+ lines after a plan edit, none on a first
  approve).
- Check passed. Security: read-only git calls; ship still refuses unapproved plans.

## Review (optional)
<!-- The human's review notes: what to change, one per line. The agent works through them
and says under "## Built" what it changed for each. -->

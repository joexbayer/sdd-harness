---
id: 28
type: fix
title: Cheap builders stop after their tasks
status: open
created: 2026-10-29
approved: 322264bfa8bfe429c271ff2b8ca0ea734821a74c 2026-10-29 joexbayer
---
# 28 Cheap builders stop after their tasks

## Current behaviour
<!-- What happens now, and how to reproduce it. -->
Item 22's trial (qwen via narrow as the builder role): after the last task, a `sdd run builder`
gets the finish steps (security pass, verifier, Built), which qwen ignored; the stop hook then
holds it ("not finished: Built is not written"). narrow exits 3 ("unverified") after red-first
batches, and `sdd run` reports that as a failed run. And the reviewed gate never applies to a
contract item: review records only changes outside specs/, and a contract lives in specs/.

## Expected behaviour
<!-- FR-28.1 WHEN <trigger> THE SYSTEM SHALL <response>.
  e.g. <input> → <output> -->
FR-28.1 WHEN `sdd run builder <id>` runs on an item with no open task THE SYSTEM SHALL refuse and
say the finishing steps belong to the session orchestrating the build.
  e.g. all tasks ticked → "item 7 has no open task: finishing (check, security pass, verifier, Built) is the orchestrating session's: sdd next", exit 2
FR-28.2 WHEN a role run's builder (SDD_RUN set) stops after its batch's tasks are ticked THE
SYSTEM SHALL let it stop: the finish gate holds it only while a task of the item is open.
  e.g. last task ticked, Built empty, SDD_RUN=3 → hook stop allows; without SDD_RUN → blocks as today
FR-28.3 WHEN narrow exits 3 THE SYSTEM SHALL log the run with exit 3, warn that narrow could not
verify its own work, and exit 0, since sdd's task tests and check decide.
  e.g. → "⚠ narrow could not verify its own work (exit 3); sdd's task tests and check decide"; other non-zero exits fail as today
FR-28.4 WHEN `sdd review` runs on a contract item THE SYSTEM SHALL record the specs/contracts/ change,
so the reviewed gate warns or blocks when a contract changes after review.
  e.g. review item 30, edit specs/contracts/orders-api.yaml, ship → "code changed since your review (specs/contracts/orders-api.yaml) (gate reviewed)"

## Must not change
<!-- Behaviour that has to stay exactly as it is (so the fix breaks nothing else). -->
Interactive builders (Claude Code sessions, the sdd-build skill) still get the finish steps from
`next` and are held by the finish gate. Other roles (verifier) and other exit codes as today.
Non-contract items' review records as today.
D-28.1 A cheap builder does tasks only; finishing needs judgment and goes to the orchestrator
(the Opus session in the experiment), not to a prompt the small model ignores.
D-28.2 The exit-3 meaning lives in the narrow adapter (`agent_exit_note <rc>`), so run.sh stays
agent-neutral; an adapter without it changes nothing.

## Security
<!-- Does this touch untrusted input, login or permissions, secrets or personal data, a new
dependency, files/network/shell, or CI/agent config? If not: "none: <why>". Otherwise, per risk:
what can go wrong → what we do (an FR with a test, a D line, or "accept: <why>").
    e.g. uploads are untrusted → FR-28.4 rejects non-images and files over 5 MB -->
none: no new input; FR-28.2 only loosens the stop hook for runs sdd itself started (SDD_RUN,
which approve and ship already refuse), and ship's gates are unchanged.

## Test
<!-- The regression test (name and file) that fails now and passes after the fix. -->
tests/t_run.sh (FR-28.1, FR-28.3, with a fake narrow exiting 3), tests/t_verified.sh or
t_role_guard.sh (FR-28.2, hook stop with and without SDD_RUN), tests/t_contracts.sh (FR-28.4).
Each fails before the fix.

## Built
<!-- Written by the agent at the end of the build, for the review: per requirement what
changed (file:line) and which test proves it; deviations from the plan and why; follow-ups. -->

## Review (optional)
<!-- The human's review notes: what to change, one per line. The agent works through them
and says under "## Built" what it changed for each. -->

---
id: 28
type: fix
title: Cheap builders stop after their tasks
status: shipped
created: 2026-10-29
approved: 322264bfa8bfe429c271ff2b8ca0ea734821a74c 2026-10-29 joexbayer
shipped: 2026-10-29
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
- FR-28.1 (builder run refused with no open task): .sdd/core/cmd/run.sh:39-42 refuses with
  exit 2 when the role is builder, the phase is build and WHYCODE is not `task`. Nothing is logged.
  Test: tests/t_run.sh:104 (also: a verifier run on the same item still runs).
- FR-28.2 (a role run's builder may stop once no task is open): .sdd/core/cmd/hook.sh:60-62.
  With SDD_RUN set, the build-phase hold applies only while WHYCODE is `task`. Test:
  tests/t_role_guard.sh:62 (blocks while a task is open) and :70 (allowed once all are ticked;
  without SDD_RUN it still blocks).
- FR-28.3 (narrow exit 3 is a warning): .sdd/core/agents/narrow.sh:24 `agent_exit_note`, and
  .sdd/core/cmd/run.sh:75-78, which calls it only if the adapter defines it; run_log still
  records the real rc. Test: tests/t_run.sh:89 (exit 3 is logged as 3, warns and exits 0; exit 4
  still fails; claude's exit 3 still fails).
- FR-28.4 (contract review records specs/contracts/): .sdd/core/lib/common.sh:434-446
  `review_print` diffs `$CONTRACTS` for ITYPE contract. ship.sh's reviewed gate needs no change,
  because a contract item's patch is no longer empty. Test: tests/t_contracts.sh:149 (a contract
  edited after review shows "code changed since your review (specs/contracts/orders-api.yaml)").
- Docs: README (roles), specs/design.md (build loop, reviewed record), sdd-dev skill.

Deviations:
- FR-28.1 is applied as written: an item with no tasks at all (e.g. a fix without tasks) has no
  open task, so `sdd run builder` refuses it too. Before, a builder run there got the whole build.
  If task-less items should still go to a builder run, the rule needs to become "the item has
  tasks and none is open" (a one-line change).
- FR-28.2 loosens only the build-phase hold. The plan-phase hold ("code before approval") and the
  pr-phase hold still apply to a role run's builder. run.sh already refuses role runs in plan.
- I left the sdd-build skill and the role-verifier prompt as they were: the skill already has the
  orchestrator run `next` after the loop.

Security pass (fresh Sonnet subagent, diff only): no findings.

Verified by: none (builder self-checked; the orchestrator verifies)

## Review (optional)
<!-- The human's review notes: what to change, one per line. The agent works through them
and says under "## Built" what it changed for each. -->

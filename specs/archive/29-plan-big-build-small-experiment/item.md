---
id: 29
type: roadmap
title: Plan big, build small experiment
status: shipped
created: 2026-10-29
approved: b554c9f3cdc7e83323f6a44d609e198440ab7d05 2026-10-29 joexbayer
shipped: 2026-10-29
---
# 29 Plan big, build small experiment

## Goal
<!-- The system these items build, and for whom. 2-4 lines. -->
Prove "plan big, build small" with numbers: the same product brief is built twice through sdd,
Opus planning in both, with qwen (via narrow) building the tasks in arm A and Opus in arm B. Same
planner, same scripted human (Sonnet, answers Q- lines from the brief), same hidden end-to-end
suite; only the builder differs. App: a small issue tracker in Python (stdlib + pytest): an HTTP
API with SQLite and token auth, and a CLI client; brief fixes the external interface so the
suite can judge it. One run per arm first (the human's call, 2026-10-29), then decide.

## Items
<!-- The items, in the order they ship, one per line, ID first:
    - R-29.1 feature: Auth API
    - R-29.2 feature: Login page (after: R-29.1)
<type> is one of sdd's types. `after:` names earlier entries only: that item ships first.
Once this roadmap ships, `.sdd/bin/sdd next` offers the ready entries and
`.sdd/bin/sdd new --from R-29.1` opens one. IDs never change; leave gaps. -->
- R-29.1 chore: Experiment harness: brief, hidden acceptance suite, driver script, tiers
- R-29.2 spike: Pilot run: one run per arm, compared (after: R-29.1)

## Done when
<!-- DOD-29.1 <observable outcome of the whole system>. -->
DOD-29.1 Both arms ran to the end (or a recorded stop) from one command each, and a findings table
compares acceptance pass rate, tokens and cost per role, wall-clock, failed checks and human
interventions; it says whether to run more repeats.

## Built
<!-- Nothing to build: say what the plan settled for the review (the order and why), e.g.
"Auth first: the page calls it". Only this file reaches the base branch. -->
Harness first: the pilot needs the brief, the hidden suite and the driver. One run per arm,
then the human decides on repeats from the findings.

## Review (optional)
<!-- The human's review notes: what to change, one per line. The agent works through them
and says under "## Built" what it changed for each. -->

---
id: 27
type: feature
title: Fewer forge calls
status: shipped
created: 2026-10-29
approved: 0bcfcd2c5f06fd7411c8eb068754c3fefa3d0d72 2026-10-29 joexbayer
shipped: 2026-10-29
---
# 27 Fewer forge calls

## Why
<!-- The problem in plain words: who hurts, and how. 2-4 lines. -->
`sdd ls` asks GitHub for every PR on each run: 1.2 of its 1.45 s in this repo, too slow for
narrow's item view. `review` asks too, even before any PR exists. sdd should rarely need gh
(the human, 2026-10-29): git and the item files hold the state.

## What changes
<!-- User-visible behaviour. One requirement per entry, each with a concrete example:
    US-27.1 As a <role> I <action>, so that <outcome>.
    FR-27.1 WHEN <trigger> THE SYSTEM SHALL <response>.
      e.g. <input> → <output>
Start each entry at the beginning of its line, ID first. IDs never change; leave gaps. -->
FR-27.1 WHEN `sdd ls` runs without `--pr` THE SYSTEM SHALL make no forge call; WITH `--pr` it SHALL
add each item's PR as today (text and JSON).
  e.g. `sdd ls --json` → rows without "pr", gh not run; `sdd ls --pr --json` → rows with "pr"
FR-27.2 WHEN `sdd review` runs on an item not yet shipped into a pull request THE SYSTEM SHALL make
no forge call; in the pr phase it SHALL show the PR as today.
  e.g. review before the first ship → no "pr" line, gh not run

## Not in scope (optional)
<!-- What this deliberately leaves out, and where it went. -->
ship (it acts on the PR) and status in the pr phase keep their calls.

## How
<!-- What a reviewer needs: an ASCII sketch of the moving parts, key types or signatures,
and the decisions they would question, each at the start of its line:
    D-27.1 <decision>, because <reason>. -->
D-27.1 PR state is opt-in on listing paths (`--pr`), not opt-out: read paths that agents and UIs
call constantly make no network call by default.
D-27.2 review asks only in the pr phase, as status does: before the first ship sdd has opened no PR.

## Security
<!-- Does this touch untrusted input, login or permissions, secrets or personal data, a new
dependency, files/network/shell, or CI/agent config? If not: "none: <why>". Otherwise, per risk:
what can go wrong → what we do (an FR with a test, a D line, or "accept: <why>").
    e.g. uploads are untrusted → FR-27.4 rejects non-images and files over 5 MB -->
none: removes network calls; no new input.

## Questions (optional)
<!-- Q-27.1 <question> → recommend: <answer>. Resolve before building. -->

## Done when
<!-- DOD-27.1 <observable outcome>, e.g. "works against staging". -->
DOD-27.1 `sdd check` passes; t_forge proves both FRs with the gh stub's call log.

## Tasks (optional)
<!-- Small, ordered steps the builder does one at a time, each in one sitting, each with a test
of its own (so it can pass before the next task exists):
    - [ ] T-27.1 Page the orders query, FR-27.1 (files: src/orders.js; test: npm test -- orders; size: S)
Size each task `S`, `M` or `L` (none is M): consecutive S tasks go to one builder together, M and
L ones alone. Add `; expect: fail` for a test written first (it must fail), or
`; expect: fail "<text>"` (it must fail with that text in its output); without `test:` the
full check runs. `.sdd/bin/sdd task done T-27.1` ticks a task when its test passes. -->
- [x] T-27.1 ls --pr and review only in the pr phase, FR-27.1, FR-27.2 (files: .sdd/core/cmd/ls.sh, .sdd/core/cmd/review.sh, .sdd/core/cmd/help.sh, README.md, tests/t_forge.sh; test: SRC=$PWD SH=dash dash tests/t_forge.sh; size: S)

## Built
<!-- Written by the agent at the end of the build, for the review: per requirement what
changed (file:line) and which test proves it; deviations from the plan and why; follow-ups. -->
FR-27.1: .sdd/core/cmd/ls.sh (`--pr` flag; `forge_load`/`pr_table` only with it); help, README,
design and the sdd-dev notes updated. FR-27.2: .sdd/core/cmd/review.sh calls `pr_note` only in the
pr phase. tests/t_forge.sh proves both with the gh stub's call log (ls, ls --json and review before
the first ship add no gh calls; ls without --pr shows no PR; ls --pr and --pr --json show it).
Verified: `sdd check` passes. Verified by: none (lite; the forge test is the proof)

## Review (optional)
<!-- The human's review notes: what to change, one per line. The agent works through them
and says under "## Built" what it changed for each. -->

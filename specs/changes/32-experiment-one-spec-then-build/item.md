---
id: 32
type: chore
title: Experiment: one spec, then build
status: open
created: 2026-10-29
approved: 6ddc882bbe1442d46963d51783846bf285bad0f0 2026-10-29 joexbayer
---
# 32 Experiment: one spec, then build

## What and why
<!-- 1-3 lines: what changes (dependencies, config, CI, ...) and why now. No behaviour change. -->
Arm B's first run (2026-10-29) planned 11 roadmap items one at a time: Opus 4-5 min and ~$1.3
per plan, re-reading brief and contract each time, so the $20 cap ends it halfway. The human wants
the spec workflow: plan a feature whole once, build it intensively in small tasks, review once;
the next feature is the next spec. Also fixes the pilot's measurement gaps.

experiment/run.sh (driver), experiment/human.md, experiment/prompts/, experiment/README.md:
- One spec per arm: the driver opens one feature item "track v1" for the whole brief; the planner
  writes every requirement, decision and task (small, each with its own test) in one session.
- Scripted human checks before approving: every FR has an e.g. example and its error cases, every
  task is small and names a test, every Q- line is answered; else VERDICT: REVISE (max 3 rounds).
- Build: builder runs per batch until no task is open (3 runs per task cap, as now).
- Review: the verifier always runs once after the tasks, whoever wrote Built; then the finisher
  writes or completes Built with the verifier's "Verified by:" line; then review and ship.
- Cap: $150 per arm, notional (claude runs on the human's subscription, not the API).
- Subscription usage limit: a claude run that ends with the usage-limit message makes the driver
  wait until the reset it names (or 15 min if none), log a wait, and retry; not a failure.
- Results: "interventions" counts only stops and manual fixes; approve, commit, review and ship by
  the driver are listed as routine steps. Plus totals per phase (plan, build, review).
.sdd/core/prompts/plan.md: "Keep it to about a screen…" becomes: one item is one spec, a feature
planned whole; long is fine when every task is small; split into a roadmap only for features
that ship separately.

D-32.1 The roadmap path is dropped from the driver (no flag kept): the pilot's arm B run is the
data point for planning per piece.
D-32.2 Verifier always runs, so both arms get the same checking whatever the builder writes.

## Security
<!-- Does this touch untrusted input, login or permissions, secrets or personal data, a new
dependency, files/network/shell, or CI/agent config? If not: "none: <why>". Otherwise, per risk:
what can go wrong → what we do (an FR with a test, a D line, or "accept: <why>").
    e.g. uploads are untrusted → FR-32.4 rejects non-images and files over 5 MB -->
No change to confinement: same allowlists, isolation (--setting-sources project) and key stripping.
The usage-limit wait only sleeps and retries the same command.

## Built
<!-- Written by the agent at the end of the build, for the review: per requirement what
changed (file:line) and which test proves it; deviations from the plan and why; follow-ups. -->

## Review (optional)
<!-- The human's review notes: what to change, one per line. The agent works through them
and says under "## Built" what it changed for each. -->

---
id: 32
type: chore
title: Experiment: one spec, then build
status: shipped
created: 2026-10-29
approved: 6ddc882bbe1442d46963d51783846bf285bad0f0 2026-10-29 joexbayer
shipped: 2026-10-29
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
What changed:
- experiment/run.sh: one spec per arm. The roadmap path is gone (D-32.1); the driver runs
  `item feature "track v1"`, then the acceptance suite. Build: builder batches while a task is
  open (3 runs per task), then the verifier always once, even when the item is already at
  `ready` (D-32.2), then the finisher until Built is complete with its line. CAP=150. Usage
  limit: `limit_wait` after each claude run (direct and `sdd run`, not narrow); waits are
  logged in waits.tsv and the same run starts again; 12 waits in a row stop the arm. approve,
  review, ship and commits are `routine` (routine.tsv); `intervene` is left for stops. Phase
  marks (plan_start, build_start, review_start, land_end) go to meta.tsv.
- experiment/lib/xp.py: `limit <exit> <out> <stderr>` (only for a run that failed or says
  is_error; matches "usage limit", "limit reached", "hit your limit", case-insensitive; reset
  from "|<epoch>" or "resets 3pm / 4:30pm (Europe/Oslo)", next occurrence, plus a 60 s margin,
  at most 6 h; none named: 15 min). Results: interventions (stops and manual fixes), routine
  steps by kind, usage-limit waits, per-phase totals (plan = planner + human, build = builder,
  review = verifier + finisher; runs, tokens, cost, agent time, wall-clock from the marks);
  failed runs per role leave out runs that ended on the limit.
- experiment/prompts/planner.md: the whole brief in this one item, no roadmap; every FR with an
  e.g. and its error cases as FRs; every task S or M, with files, FRs and its own test.
- experiment/human.md: a checklist (brief covered, FR examples and errors, small tasks with
  tests, every FR served, every Q answered); any failure → `VERDICT: REVISE: <checks, IDs>`.
- experiment/fake/fake_agent.py: plans one feature with two M tasks (two builder runs);
  `XP_FAKE_LIMIT=<role>` makes that role's first claude run end on "Claude AI usage limit
  reached|<now+2>".
- experiment/README.md and the sdd-dev skill updated.
- .sdd/core/prompts/plan.md: "Keep it to about a screen…" became: one item is one spec, a
  feature planned whole; long is fine when every task is small; a roadmap only for features
  that ship separately. No test asserted the old text.

How verified (--dry, fake agents, no real runs):
- B and A each ran end to end: two builder runs, each committed from sdd run's "commit with:"
  message, verifier, finisher, review, ship; results 1 item shipped, 0 interventions, 5
  routine steps (approve 1, commit 2, review 1, ship 1).
- XP_FAKE_COST=60 (A) stopped at "spend cap: $180.00 > $150"; XP_FAKE_REVISE=1 (B) stopped at
  "no approval after 3 plan rounds".
- XP_FAKE_LIMIT=planner (B) and XP_FAKE_LIMIT=verifier (A): one wait each ("usage limit on run
  n: waiting 3s, then the same run again"), the retry went on and the arm shipped; the limited
  run is not counted as failed, and the verifier report came from the retry.
- limit_seconds checked on the three wordings at a fixed time: "|epoch" in 1 h → 3660 s,
  "resets 3pm" at 13:00 → 7260 s, "resets 4:30pm (Europe/Oslo)" → 12660 s, no time → 900 s.
- `shellcheck -s sh experiment/run.sh` clean. `.sdd/bin/sdd check` passes with
  SDD_PERF_SLACK=1.5: the first run failed only t_perf (`next` 0.21 s against 0.2 s) at load
  average 18 with arm B's real run going; the plan.md change is one prompt line.

Deviations:
- experiment/brief.md: the preference "Order: agree the HTTP interface first (a contract …),
  then the server in a few items" contradicted one spec (the stricter human would REVISE on
  it); it now says the whole brief is one feature, built in small tasks, in order. The
  interface and the hidden suite are unchanged.
- The usage-limit wording is from what I know of Claude Code ("Claude AI usage limit
  reached|<epoch>" in older builds, "… limit reached ∙ resets 3pm" / "You've hit your limit ·
  resets …" in newer); it is checked only on runs that failed, so an agent writing "limit
  reached" in a successful answer does not trigger a wait. Unknown wordings fall to 15 min.
- The 12-waits stop is mine: without it, a weekly limit (a reset date the parser cannot read)
  would retry every 15 min forever. Three lines, no spend.
- The fake builder plans two M tasks instead of one, so the dry run shows batches.

security pass: only I looked. No change to confinement (allowlists, --setting-sources project,
the key-stripping wrapper, narrow's allowlist config). The wait only sleeps and reruns the
same command; the sleep length comes from xp.py as an integer between 1 s and 6 h. Agent text
still reaches git and python only as quoted arguments.

Verified by: none (builder self-checked; the orchestrator verifies)

## Review (optional)
<!-- The human's review notes: what to change, one per line. The agent works through them
and says under "## Built" what it changed for each. -->

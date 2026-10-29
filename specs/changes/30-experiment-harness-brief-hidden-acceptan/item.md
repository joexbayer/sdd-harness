---
id: 30
type: chore
title: Experiment harness: brief, hidden acceptance suite, driver script, tiers
status: open
created: 2026-10-29
roadmap: R-29.1
approved: e8ffc317f267cff3ad781432d60b3d7ba7ec2763 2026-10-29 joexbayer
---
# 30 Experiment harness: brief, hidden acceptance suite, driver script, tiers

## What and why
<!-- 1-3 lines: what changes (dependencies, config, CI, ...) and why now. No behaviour change. -->
The harness for roadmap 29 (plan big, build small experiment), in experiment/; sdd itself does not
change. One command runs one arm end to end in a fresh repo: arm A has qwen build the tasks (via
narrow), arm B has Opus build them; planner, scripted human, brief and hidden suite are the same.

- experiment/brief.md: the product, "track", a small issue tracker. Python 3 stdlib + pytest only.
  It fixes the external interface exactly (HTTP endpoints, JSON bodies, status codes, token auth,
  SQLite file from `--db`, the CLI's commands, output and exit codes, how to start both) and says
  nothing of the internals. It ends with the human's preferences, for answering questions.
- experiment/acceptance/: the hidden end-to-end suite (pytest, ~30-40 tests over every feature),
  run against a finished repo from outside it; never copied into the run repo. Starts the server
  on 127.0.0.1 and a free port, drives HTTP and the CLI, writes a JSON pass/fail summary.
- experiment/reference/: a small reference build of the brief, so the suite is proven against the
  brief before any run (every test passes on it). Never shown to the agents.
- experiment/human.md: the scripted human's prompt: answer each open Q- line from the brief by
  appending `→ decided: <answer> (scripted-human, <date>)`, choose the recommendation where the
  brief is silent, change nothing else, then end with `VERDICT: APPROVE` or `VERDICT: REVISE: <why>`.
- experiment/run.sh <A|B> [dir]: POSIX sh driver. Makes a fresh repo outside any checkout
  (default ~/experiments/<arm>-<date-time>): git init, sdd installed from this checkout,
  profile standard, no forge, usage tracking on, check = `python3 -m pytest -q`, brief committed as
  docs/brief.md, the arm's tiers. Then: roadmap → per ready entry: `new --from`, planner ↔ human
  rounds until APPROVE, approve, `sdd run builder` per batch, finisher, verifier, review, ship;
  until no entry is ready. Finally the acceptance suite and a results file.
- experiment/README.md: how to run, read results and compare arms.

D-30.1 Roles: planner = Opus (claude), human = Sonnet (claude), builder = qwen3-coder (narrow) in
A or Opus in B, finisher = Opus (security pass, Built), verifier = Sonnet. Only the builder
differs between arms.
D-30.2 Confinement (the human's call, 2026-10-29): no permission-skipping flags (D-16.1). claude
gets `--permission-mode acceptEdits` and an allowlist (python3, pytest, git, .sdd/bin/sdd, Read,
Grep, Glob, Edit, Write); narrow its own permission profile, if it has one without --yolo, else
the builder stops and tells the human. A run that stalls on a refused command is recorded.
D-30.3 Spend cap $20 per arm (the human's call): after each role run the driver totals
`sdd usage` and stops the arm past $20, recorded as a stop. Also stops after 3 planner ↔ human
rounds on one item, 2 failed runs in a row of one role, or 3 builder runs per open task.
D-30.4 approve and ship are run by the driver, the human's own script, after the scripted human's
APPROVE (they refuse role runs). Each stop and each manual step counts as a human intervention.
D-30.5 results.json + results.md per run: acceptance passed/total, per role tokens in/out, cost,
runs and seconds (from `sdd usage`), items shipped, failed checks, failed task tests,
interventions and stops, wall-clock.
D-30.6 The agents (and I) cannot start run.sh: a headless agent launch needs the human
(`! sh experiment/run.sh A`). A `--dry` mode with fake agent binaries tests the driver's setup,
caps and results without spending money.

## Security
<!-- Does this touch untrusted input, login or permissions, secrets or personal data, a new
dependency, files/network/shell, or CI/agent config? If not: "none: <why>". Otherwise, per risk:
what can go wrong → what we do (an FR with a test, a D line, or "accept: <why>").
    e.g. uploads are untrusted → FR-30.4 rejects non-images and files over 5 MB -->
Agent-written code runs on this machine → D-30.2's allowlist, runs in fresh dirs outside any
checkout, the acceptance suite binds 127.0.0.1 only. The gateway key stays in its env var / key
file (narrow reads it); the driver never reads, logs or passes a key. No new dependency (pytest
is already the check's runner).

## Built
<!-- Written by the agent at the end of the build, for the review: per requirement what
changed (file:line) and which test proves it; deviations from the plan and why; follow-ups. -->

## Review (optional)
<!-- The human's review notes: what to change, one per line. The agent works through them
and says under "## Built" what it changed for each. -->

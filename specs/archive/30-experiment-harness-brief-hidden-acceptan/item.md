---
id: 30
type: chore
title: Experiment harness: brief, hidden acceptance suite, driver script, tiers
status: shipped
created: 2026-10-29
roadmap: R-29.1
approved: e8ffc317f267cff3ad781432d60b3d7ba7ec2763 2026-10-29 joexbayer
shipped: 2026-10-29
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
What each file is (all new, under experiment/; sdd itself is unchanged):
- brief.md: "track", Python 3.9+ stdlib + pytest. Fixes start commands (`python3 -m track.server
  --port N --db F [--host]`, the "track listening on" line), every endpoint (users, tokens, /me,
  logout, projects, members, issues with state/assignee/labels, PATCH, filters, cross-project
  search, comments), JSON shapes, the error body and status table (with precedence), and the
  CLI: config file (`TRACK_CONFIG`, `TRACK_URL`, mode 0600), 17 commands with exact output, exit
  codes 0-4. Ends with "The human's preferences" (contract first, pbkdf2, hashed tokens, no
  pagination, choose and record a D line rather than ask). Sized for a contract + 3-5 items.
- reference/track/: server.py (ThreadingHTTPServer + sqlite3, parameterised SQL) and cli.py.
- acceptance/: conftest.py (`--repo`, `--summary`; starts the server from <repo> on 127.0.0.1
  and a free port, CLI as a subprocess with its own HOME/TRACK_CONFIG; writes passed, total,
  failed names), test_api.py (28 tests), test_cli.py (17 tests).
- human.md: the scripted human prompt (answer open Q- lines with `→ decided: … (scripted-human,
  <date>)`, recommendation where the brief is silent, change nothing else, last line
  `VERDICT: APPROVE` or `VERDICT: REVISE: <why>`).
- prompts/planner.md (added after `sdd next` for headless planning), prompts/role-finisher.md
  (installed as the run repo's .sdd/local/prompts/role-finisher.md).
- narrow/provider.lisp (the gateway, as narrow-sdd.sh) and narrow/allow.lisp (the builder's
  allowlist); run.sh joins them into the run's own NARROW_CONFIG_DIR for arm A.
- run.sh: the driver (D-30.1..5); lib/xp.py: its JSON helpers (show --json state, claude
  usage/result/verdict/denials, results.json/.md); fake/fake_agent.py: fake claude and narrow.
- README.md: how to run, read and compare. .claude/skills/sdd-dev/SKILL.md: experiment section.

How verified:
- Reference passes the suite 45/45 (`python3 -m pytest -q -p no:cacheprovider
  experiment/acceptance --repo experiment/reference`); an empty repo gets 0/45 and a summary.
- `shellcheck -s sh experiment/run.sh`: clean; parses under /bin/sh and dash.
- --dry, all with fake agents, after rebasing on main (item 31): B and A each ran to the end
  (roadmap + one feature entry shipped; the builder's tick committed by the driver with sdd
  run's "commit with:" message; results written); XP_FAKE_COST=8 (B) stopped at "spend cap:
  $24.00 > $20"; XP_FAKE_REVISE=1 (A) stopped at "no approval after 3 plan rounds" (the REVISE
  reason reached the next planner prompt); XP_FAKE_FAIL=builder (B) stopped at "2 failed
  builder runs in a row". Not exercised: the 3-builder-runs-per-task cap.
- narrow allowlist, on narrow-13b380e with only allow.lisp as init.lisp (no provider, so no key
  is loaded): `permission-for` gives :allow for `python3 -m pytest -q`, `pytest -q tests`,
  `git commit -qm x`, `git add -A && git commit -m x`, `.sdd/bin/sdd task done T-1.1`, and :ask
  for `curl`, `rm -rf build`, `python3 -m pytest > out`, `echo $(cat /etc/passwd)`,
  `sh -c '…'`, `bash .sdd/bin/sdd check`; `seal-verify` restores nothing (the advice stays).
  Without the config, the same commands are :ask, which headless means refused.
- The claude wrapper drops AI_API_KEY (checked with the same wrapper around env).
- `.sdd/bin/sdd check` passes.

Deviations and choices:
- `sdd run` refuses every role while a plan waits for approval (reason approval/changed), so
  the planner and human rounds are run by the driver (`claude -p` on the role's tier, same
  args) and appended to `.git/sdd/runs.tsv` in run_log's columns; `sdd usage` totals them.
- Order verifier, then finisher: the finisher reads the verifier's report from
  `.git/experiment/verify-<id>.md` and writes its Verified by line, so one finisher run
  finishes. No verifier for items without tasks (roadmap, contract).
- Item 31: `sdd run builder` ticks the batch and commits nothing; the driver commits with the
  "commit with:" message it prints (not counted as an intervention), or commits leftovers as an
  intervention when there is none. After a finisher run it commits leftovers as
  `docs(<id>): Built` (an intervention). The fake builder now neither ticks nor commits.
- The human's calls after the first build: arm A uses the allowlist config instead of --yolo;
  every claude tier (and so the driver's own planner/human runs) has `--setting-sources
  project`; every claude run goes through `<run>/bin/claude-xp`, which unsets
  AI_API_KEY (set as `[agent "claude"] bin`, so sdd run uses it too).
- Run folder layout: `<dir>/repo` is the project, the driver's files sit beside it.
- Tiers are named `xp-opus`, `xp-human`, `xp-verifier`, `xp-builder`, because a developer's own
  `[tier]` wins over the project's. Human: Read/Grep/Glob/Edit only. Verifier: no Edit/Write,
  no acceptEdits.
- Failed checks are counted from the driver's own `sdd check` after each builder and finisher
  run (sdd keeps only the last result); "failed task tests" is reported as builder runs after
  which the same task was still open.
- Interventions are logged by kind: stop, approve, review, ship, commit, so the comparison can
  count either all of them or only stops.
- The suite has 45 tests (plan said ~30-40): every CLI command and API endpoint got one.
- No `sdd sync claude` in the run repo: role runs are headless `-p`, and human_only (SDD_RUN)
  already refuses approve/ship from agents.

Narrow finding (D-30.2): narrow has no headless profile without --yolo. With the default
permission-rules, `:exec` is `:ask`, and a headless ask is refused; only read-only commands
pass. The human chose an allowlist: experiment/narrow/allow.lisp wraps `permission-for` (advice
from an init file, which narrow allows for the user) to allow simple commands of python3,
pytest, git and .sdd/bin/sdd, with narrow's own rules and floor otherwise in force. The key
file is not hidden by the separate config dir: provider.lisp names it explicitly, as
narrow-sdd.sh does, and narrow reads it itself.

security pass: only I looked (no fresh reviewer). run.sh quotes every expansion; the tier args
are split on purpose under `set -f`; `eval` only ever sees the fixed role names; agent text
(verdict reasons, commit messages from sdd run, item text) reaches git and python only as
quoted arguments, never as shell code. The driver never reads, logs or passes a key; claude runs and the
agent-written server and CLI under the suite get no AI_API_KEY; only narrow sees it. The
reference uses parameterised SQL (PATCH builds SET from fixed column names) and binds
127.0.0.1. Accepted, as in the plan: claude's `Bash(python3:*)` lets a role run any code as
you, so agents could read files outside the run repo (this checkout's hidden suite and
reference, ~/.config/narrow/api.key); the same holds for narrow's python3 in arm A. Nothing
points them there; the run repo is outside this checkout.

Unlikely edge cases left alone (failure mode · likelihood · cost to fix):
- interventions.tsv breaks if a stop reason has a tab or newline (only `sdd new` errors can) ·
  rare · a sanitising step.
- free_port() race: another process takes the port between probe and bind · very rare on a
  laptop · a retry loop in conftest.
- A fixed username in test_register_and_login collides only if the suite shares a database
  across sessions, which it never does.

Open questions for the human before the first real run: none left from this build (arm A's
confinement, claude isolation, the key and the model IDs were decided 2026-10-29). The first
real arm A run is also the first real test of allow.lisp inside a headless narrow run.

Verified by: none (builder self-checked; the orchestrator verifies)

## Review (optional)
<!-- The human's review notes: what to change, one per line. The agent works through them
and says under "## Built" what it changed for each. -->

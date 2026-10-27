---
id: 16
type: feature
title: Model roles and usage tracking
status: open
created: 2026-10-27
---
# 16 Model roles and usage tracking

## Why
The experiment runs Opus as planner and a small coder model as builder, unattended, and must
measure what each role costs and delivers. Today every agent run is typed by hand, with
whatever model is at hand, and nothing records tokens or results, so runs are neither
repeatable nor comparable.

## What changes
US-16.1 As someone running the experiment I run each step with one command on the model its
role is set to, so that runs are repeatable and every run's tokens and result are logged.
FR-16.1 WHEN `sdd run <role> <id>` runs THE SYSTEM SHALL find the role's tier in the project
config and the tier's agent, model and args in the user config (else the project config), and
refuse with the exact lines to add when any is missing (exit 2).
  e.g. `[role "builder"] tier = small` and `[tier "small"] agent = narrow` / `model = qwen3-coder-30b`
FR-16.2 WHEN the run starts THE SYSTEM SHALL require the item's branch to be checked out, and
give the agent the item's `sdd next` text (for a builder in build, the current task first),
plus `prompts/role-<role>.md` when one exists, once, headless, in the repo.
FR-16.3 WHEN the run ends THE SYSTEM SHALL append one line to this clone's `.git/sdd/runs.tsv`:
time, item, role, agent, model, phase and task at the start, tokens in and out, cost (the
agent's own figure, else empty), seconds, exit code and the agent's verdict, and print it; the
agent's full output stays in `.git/sdd/runs/<n>/`.
  e.g. `run 3 · builder · narrow qwen3-coder-30b · T-16.2 · 41k in / 3k out · 95s · exit 0 · passed`
FR-16.4 WHEN `sdd usage [<id>] [--md]` runs THE SYSTEM SHALL sum the runs per item and role (per
task too for one item): runs, tokens in and out, cost, seconds.
FR-16.5 WHEN an agent adapter runs a step THE SYSTEM SHALL build that agent's headless command
(`claude -p --output-format json --model …`; `narrow --json -m … -p …`) and read tokens, cost
and verdict from its final JSON line with sed and awk.
FR-16.6 WHEN the agent is missing or exits non-zero THE SYSTEM SHALL still log the run with its
exit code and say what failed (exit 1).

## Not in scope (optional)
Looping over tasks (a script, or a later `--until review`), a price table, a committed usage
log, codex and other agents' run adapters, the scripted human (the experiment sets it up as a
role with its own `prompts/role-human.md`).

## How
```
 sdd run builder 16 ─▶ role.builder.tier ─▶ tier.small.{agent,model,args} ─▶ agents/narrow.sh
       │ prompt = sdd next (+ prompts/role-builder.md)        agent_run → .git/sdd/runs/<n>/out
       └─▶ agent_usage(out) ─▶ tokens, cost, verdict ─▶ .git/sdd/runs.tsv ─▶ sdd usage
```
- New `cmd/run.sh`, `cmd/usage.sh`, `agents/narrow.sh`; `agents/claude.sh` gains `agent_run` and
  `agent_usage`. Tests use stub `claude` and `narrow` on PATH that print a final JSON line.
D-16.1 sdd adds no permission-skipping flags: `args` in the tier config is where a developer puts
`--yolo` or `--permission-mode`, explicitly (design §13).
D-16.2 The log is per clone and never committed (Q-16.3); `usage --md` is how numbers are shared.
D-16.3 A role only picks the model; what to do comes from `sdd next` for the item's phase, so a
role never sees instructions for another phase.

## Security
Runs an agent unattended on the developer's machine. Risks: an agent run with more power than
intended → sdd passes only the tier's explicit `args` (D-16.1), and approve, ship and
`tidy --remote` stay behind ask rules in Claude Code (headless, they are refused); a key leaking
into the log → only numbers and the verdict are logged, the agent's own output stays in
`.git/sdd/runs/` (never committed), and sdd never reads or passes keys (agents use their own
config). No new dependency.

## Questions (optional)
Q-16.1 How are roles mapped to models? → recommend: two levels, team roles to tiers, each
developer's tiers to agent and model. → decided: two levels (joexbayer, 2026-10-27)
Q-16.2 What does one run do? → recommend: one step, then log. → decided: one step, then log
(joexbayer, 2026-10-27)
Q-16.3 Where is the usage log? → recommend: committed with the item. → decided: this clone only
(joexbayer, 2026-10-27)
Q-16.4 Where does the cost come from? → recommend: the agent's figure, else a price table. →
decided: just the agent's figure; cost is for testing, not a feature (joexbayer, 2026-10-27)

## Done when
DOD-16.1 `sdd check` passes, with a test naming each FR, under /bin/sh and dash.
DOD-16.2 On a scratch repo, one real builder run (narrow + qwen) and one real planner run
(`claude -p`, Opus) show up in `sdd usage` with tokens and a verdict.

## Tasks (optional)
- [ ] T-16.1 Read usage from claude's and narrow's final JSON lines, FR-16.5 (files: .sdd/core/agents/claude.sh, .sdd/core/agents/narrow.sh, tests/t_agent_usage.sh; test: SH=/bin/sh SRC=$PWD sh tests/t_agent_usage.sh)
- [ ] T-16.2 `sdd run`: resolve the role, run once, log, FR-16.1, FR-16.2, FR-16.3, FR-16.6 (files: .sdd/core/cmd/run.sh, tests/t_run.sh; test: SH=/bin/sh SRC=$PWD sh tests/t_run.sh)
- [ ] T-16.3 `sdd usage`, FR-16.4 (files: .sdd/core/cmd/usage.sh, tests/t_usage.sh; test: SH=/bin/sh SRC=$PWD sh tests/t_usage.sh)
- [ ] T-16.4 Help, design §8 and §10, README (files: .sdd/core/cmd/help.sh, specs/design.md, README.md)

## Built
<!-- Written by the agent at the end of the build, for the review: per requirement what
changed (file:line) and which test proves it; deviations from the plan and why; follow-ups. -->

## Review (optional)
<!-- The human's review notes: what to change, one per line. The agent works through them
and says under "## Built" what it changed for each. -->

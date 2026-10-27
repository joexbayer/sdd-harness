---
id: 16
type: feature
title: Model roles and usage tracking
status: open
created: 2026-10-27
approved: 04692f78716df8b7699a9cb4a114c4b29ee3c27f 2026-10-27 joexbayer
---
# 16 Model roles and usage tracking

## Why
The experiment runs Opus as planner and a small coder model as builder, unattended, and must
measure what each role costs and delivers. Today every agent run is typed by hand, with
whatever model is at hand, and nothing records tokens or results, so runs are neither
repeatable nor comparable. People work through their agent (item 14), so roles should be
something the agent runs, as subagents, not commands a person types.

## What changes
US-16.1 As someone running the experiment I ask my agent to run a role on an item, so that each
step runs on the model its role is set to and every run's tokens and result are logged.
FR-16.1 WHEN a role is run THE SYSTEM SHALL find the role's tier in the project config and the
tier's agent, model and args in the user config (else the project config), and refuse with the
exact lines to add when any is missing (exit 2).
  e.g. `[role "builder"] tier = small` and `[tier "small"] agent = narrow` / `model = qwen3-coder-30b`
FR-16.2 WHEN `sync claude` runs THE SYSTEM SHALL write, kept out of git, a subagent
`.claude/agents/sdd-<role>.md` for every role whose tier's agent is claude (its model from the
tier; its instructions: run `sdd next` for the item and follow it, plus `prompts/role-<role>.md`
when it exists), and an `sdd-run` skill.
FR-16.3 WHEN the agent is asked to run a role on an item (the `sdd-run` skill) THE SYSTEM SHALL
have it spawn that role's subagent, or, when the role's agent is not this agent, run
`sdd run <role> <id>`.
  e.g. "run the builder on item 16" → `.sdd/bin/sdd run builder 16` (narrow); "plan item 16" → the sdd-planner subagent
FR-16.4 WHEN `sdd run <role> <id>` runs THE SYSTEM SHALL require the item's branch, give the
role's agent the item's `sdd next` text (plus `prompts/role-<role>.md`) once, headless, through
its adapter (`claude -p --output-format json --model …`; `narrow --json -m … -p …`), with only
the tier's `args` added.
FR-16.5 WHEN a run ends, through `sdd run` or a subagent, and usage tracking is on (`[usage]
track = true`, in your config or the project's; off by default) THE SYSTEM SHALL append one line to this
clone's `.git/sdd/runs.tsv`: start time, item, role, agent, model, phase and task at the start,
tokens in and out, cost (the agent's own figure, else empty), seconds, exit code and verdict;
the agent's output stays in `.git/sdd/runs/<n>/`.
  e.g. `run 3 · builder · narrow qwen3-coder-30b · T-16.2 · 41k in / 3k out · 95s · exit 0 · passed`
FR-16.6 WHEN usage tracking is on and a subagent named `sdd-<role>` starts and stops THE SYSTEM
SHALL note its start
(SubagentStart hook) and, at its stop (SubagentStop hook), sum the tokens in its transcript,
each message once, and log the run as in FR-16.5. `sync claude` installs these hooks only while tracking is on.
FR-16.7 WHEN `sdd usage [<id>] [--md]` runs THE SYSTEM SHALL sum the runs per item and role (per
task too for one item): runs, tokens in and out, cost, seconds. With tracking off it says how to switch it on.
FR-16.8 WHEN an agent is missing or a run exits non-zero THE SYSTEM SHALL still log it with its
exit code and say what failed (exit 1).

## Not in scope (optional)
Task sizes, batches and the "now let's build" loop (item 17), building across items (the
multi-item plans item), a price table, a committed usage
log, subagents and run adapters for codex and others, the scripted human (the experiment adds a
role with its own `prompts/role-human.md`).

## How
```
 "run the builder on 16" ─▶ sdd-run skill ─┬─ role's agent = claude ─▶ subagent sdd-builder
                                           │     SubagentStart/Stop hooks ─▶ transcript tokens ─┐
                                           └─ else ─▶ sdd run builder 16 ─▶ agents/narrow.sh ──┤
                                                         agent_run, agent_usage (final JSON)   ▼
 tiers: [role] tier → [tier] agent, model, args                .git/sdd/runs.tsv ─▶ sdd usage
```
- New `cmd/run.sh`, `cmd/usage.sh`, `agents/narrow.sh`, `agents/skills/run.md`; `agents/claude.sh`
  gains `agent_run`, `agent_usage`, the subagent files and the two hooks; `cmd/hook.sh` handles
  `subagent-start` and `subagent-stop`.
- Tests use stub `claude` and `narrow` on PATH, and a sample subagent transcript.
D-16.1 sdd adds no permission-skipping flags: `args` in the tier config is where a developer puts
`--yolo` or a permission mode, explicitly (design §13).
D-16.2 The log is per clone, never committed (Q-16.3), and off until someone opts in (Q-16.7);
`usage --md` is how numbers are shared.
D-16.3 A role only picks the model; what to do comes from `sdd next` for the item's phase.
D-16.4 Subagent tokens come from its transcript, because no hook reports them; the transcript's
layout is Claude Code's internal format (kb/claude-subagents.md), so its reader lives in
`agents/claude.sh` (jq, hook JSON per C-1) and a test pins the shape.

## Security
Runs agents unattended. Risks: more power than intended → only the tier's explicit `args`
(D-16.1), subagents get no `permissionMode`, and approve, ship and `tidy --remote` stay behind
ask rules; a key in the log → only numbers and the verdict are logged, agent output stays in
`.git/sdd/runs/` (never committed), and sdd never reads or passes keys. No new dependency.

## Questions (optional)
Q-16.1 How are roles mapped to models? → recommend: two levels, team roles to tiers, each
developer's tiers to agent and model. → decided: two levels (joexbayer, 2026-10-27)
Q-16.2 What does one run do? → recommend: one step, then log. → decided: one step, then log
(joexbayer, 2026-10-27)
Q-16.3 Where is the usage log? → recommend: committed with the item. → decided: this clone only
(joexbayer, 2026-10-27)
Q-16.4 Where does the cost come from? → recommend: the agent's figure, else a price table. →
decided: just the agent's figure; cost is for testing, not a feature (joexbayer, 2026-10-27)
Q-16.5 How do roles run? → recommend: skills and subagents, `sdd run` for non-Claude models. →
decided: most should run as subagents (joexbayer, 2026-10-27)
Q-16.7 Is usage tracking on by default? → decided: no, off by default; switch it on with
`[usage] track = true` (joexbayer, 2026-10-27)

## Done when
DOD-16.1 `sdd check` passes, with a test naming each FR, under /bin/sh and dash.
DOD-16.2 On a scratch repo, a planner subagent (Opus) and a builder run through `sdd run` (narrow
+ qwen) both show up in `sdd usage` with tokens and a verdict.

## Tasks (optional)
- [x] T-16.1 Read usage from claude -p, narrow and a subagent transcript, FR-16.5 (files: .sdd/core/agents/claude.sh, .sdd/core/agents/narrow.sh, tests/t_agent_usage.sh; test: SH=/bin/sh SRC=$PWD sh tests/t_agent_usage.sh)
- [x] T-16.2 `sdd run`: resolve the role, run once, log, FR-16.1, FR-16.4, FR-16.5, FR-16.8 (files: .sdd/core/cmd/run.sh, tests/t_run.sh; test: SH=/bin/sh SRC=$PWD sh tests/t_run.sh)
- [x] T-16.3 Subagents, the sdd-run skill and the subagent hooks, FR-16.2, FR-16.3, FR-16.6 (files: .sdd/core/agents/claude.sh, .sdd/core/agents/skills/run.md, .sdd/core/cmd/hook.sh, tests/t_roles.sh; test: SH=/bin/sh SRC=$PWD sh tests/t_roles.sh)
- [x] T-16.6 `sdd usage`, FR-16.7 (files: .sdd/core/cmd/usage.sh, tests/t_usage.sh; test: SH=/bin/sh SRC=$PWD sh tests/t_usage.sh)
- [x] T-16.7 Help, design §8 and §10, README (files: .sdd/core/cmd/help.sh, specs/design.md, README.md)
- [x] T-16.8 Usage tracking off by default, FR-16.5, FR-16.6, FR-16.7 (files: .sdd/core/lib/common.sh, .sdd/core/agents/claude.sh, .sdd/core/cmd/usage.sh, tests/t_usage_off.sh; test: SH=/bin/sh SRC=$PWD sh tests/t_usage_off.sh)

## Built
- FR-16.1 (a role's tier, agent and model): `cfg_mine` (`lib/common.sh:71`) reads tier and agent
  settings from the developer's config first; `cmd/run.sh` refuses with the lines to add.
  Test: tests/t_run.sh.
- FR-16.2 (subagents): `install_subagents` (`agents/claude.sh:30`) writes
  `.claude/agents/sdd-<role>.md` for each role on a Claude tier (its model; "run `sdd next`, do
  that step"), kept out of git; a developer's own file stays, a role moved off Claude loses its
  file. Test: tests/t_roles.sh.
- FR-16.3 (the sdd-run skill): `agents/skills/run.md` (+ `run.claude.md`): a subagent when there
  is one, `sdd run` otherwise; never approve or ship. Test: t_roles.sh.
- FR-16.4 (`sdd run`): `cmd/run.sh`, `agent_run` in `agents/claude.sh:100` and
  `agents/narrow.sh:19`, the prompt = `sdd next` (+ `prompts/role-<role>.md`), only the tier's
  args. Test: t_run.sh (no yolo unless configured; the role prompt reaches the agent).
- FR-16.5 (one log line per run): `run_slot`, `run_log` (`common.sh:447,457`) write
  `.git/sdd/runs.tsv`; `agent_usage` reads claude's result line and narrow's finish event with
  `json_num`/`json_str` (sed, `common.sh:550`). Test: tests/t_agent_usage.sh, t_run.sh.
- FR-16.6 (subagent runs logged): `subagent_hooks` (`agents/claude.sh:111`) adds SubagentStart
  and SubagentStop hooks for `sdd-.*`; `cmd/hook.sh:29` notes the start and, at the stop, sums the
  transcript (`agent_transcript_usage`, `agents/claude.sh:87`, jq, each message once). Test:
  t_roles.sh, t_agent_usage.sh.
- FR-16.7 (`sdd usage`): `cmd/usage.sh`, plain or `--md`. Test: tests/t_usage.sh.
- FR-16.8 (failures logged): t_run.sh (an agent exiting 3 is logged, sdd exits 1).
- DOD-16.2, real runs on a scratch repo (2026-10-27): `sdd run builder 1` with narrow and
  qwen3-coder-30b: qwen wrote greet.sh and its test and ran `sdd task done` itself; logged
  150k in / 2k out, 18s, passed. A `claude -p` session (Sonnet, $0.52 in all) used the sdd-run
  skill, which spawned the sdd-planner subagent (Opus): it drafted item 2 with five questions and
  recommendations; the hooks logged 329k in / 8k out, 1m 23s, model claude-opus-5-5.

Deviations:
- The claude `agent_run` sends the prompt on stdin; narrow takes it as `-p` text.
- Tasks were built in order with a test each, ticked through `task done` (item 15's lesson).

Fresh-context review (no blockers, 4 warnings, 8 nits; security pass: no exploitable finding) and
what changed:
- Fixed: a tier's settings were read key by key, so a project's `args` for its Claude tier reached
  a developer who mapped that tier to narrow. A tier is now read whole from one file
  (`tier_file`, `tier_get`): the developer's if they define it. Test: t_run.sh.
- Fixed: `sdd run` ran a role in the human's turns (waiting for approval, review, a PR); it now
  refuses (exit 2). Test: t_run.sh.
- Fixed: a model value with a newline could add frontmatter (e.g. a permission mode) to a
  subagent; names are checked (`tier_ok`), bad roles are skipped with a warning. Tests:
  t_run.sh, t_roles.sh.
- Fixed by a real run: `sdd run planner` on claude -p (Haiku, $0.007) showed that `usage`
  repeats its keys in `iterations[]`, so reading the last match logged 38k in / 756 out instead
  of 107k / 1.7k. The readers take the first match now, and that real result line is a test
  fixture (tests/data/claude-p-result.json). Costs print with 4 decimals.
- Fixed nits: args are split on spaces without glob expansion (`set -f`); a role prompt's
  `{{id}}` reads "the given item" in a subagent; narrow's stop hook blocks the plain way again;
  the subagent logging moved to the Claude adapter (`agent_subagent_hook`) and `item_phase` sets
  TASK, so neither repeats the task lookup.
- Accepted: `run_log` takes 14 arguments (one writer, documented); FR-16.3 (the skill hands off)
  is shown by the real run, not by a test, since only Claude Code can spawn the subagent.

Found in the real runs, for later items:
- qwen ticked its task but did not commit: the builder role prompt should insist on the commit.
- The planner found a real dependency: item 2's branch lacks item 1's code while the check
  already tests it, so item 2 cannot pass its check until item 1 lands (multi-item plans).
- A task attribute sdd does not know (`size:` before item 17) is read as part of the previous
  value; item 17 should refuse unknown attributes.

## Review (optional)
<!-- The human's review notes: what to change, one per line. The agent works through them
and says under "## Built" what it changed for each. -->

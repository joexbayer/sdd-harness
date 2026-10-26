---
id: 4
type: feature
title: AI driver: step skills, human-only steps
status: open
created: 2026-10-26
---
# 4 AI driver: step skills, human-only steps

## Why
Most of the time an AI will drive sdd: the human talks, and the agent runs the verbs. Today
the only entry points are the AGENTS.md block and `sdd next`. Strong models follow them
(Opus ran `sdd next` first, unprompted), but the human has no per-step commands, unlike
Spec Kit's `/speckit.specify`, `/speckit.clarify` and `/speckit.plan`. And nothing but prose
stops the agent from running the human's own steps, `approve` and `ship`. Those are the
two moments where the human must decide, so they need the human's explicit confirmation, not
the agent's judgment.

## What changes
US-4.1 As a developer working through an AI, I start each step with one command, so that I
don't have to remember the workflow.
FR-4.1 WHEN `sdd sync <agent>` runs THE SYSTEM SHALL install one skill per step, `sdd-new`,
`sdd-plan`, `sdd-build`, `sdd-review` and `sdd-ship`, in that agent's skill folder, and keep
them out of git. Each skill tells the agent to run the step's verb or `sdd next` and follow
it, and adds only hints about that agent's own tools.
  e.g. `/sdd-plan` in Claude Code → runs `.sdd/bin/sdd next`, discusses the problem first, then
  asks one question at a time with AskUserQuestion: options from research, a recommendation.
FR-4.2 WHEN a skill's description is shown to the agent THE SYSTEM SHALL word it so the skill
triggers on plain requests ("let's build X", "fix this bug", "review it"), not only when it
is named.
US-4.2 As the human, I alone approve plans and ship changes, even when an agent drives.
FR-4.3 WHEN `sdd sync claude` runs THE SYSTEM SHALL add `ask` permission rules for
`sdd approve` and `sdd ship` to `.claude/settings.local.json`, so that Claude Code asks the
human before either runs, in every permission mode that honours ask rules.
  e.g. the agent proposes `.sdd/bin/sdd approve` → Claude Code shows the approval prompt
FR-4.4 WHEN `sdd sync` runs again THE SYSTEM SHALL replace only the skills and rules it
installed (marked `sdd-managed`) and leave the user's own alone.

## Not in scope (optional)
Agents without skills or ask rules (they keep the AGENTS.md block and hooks), refusing
`approve` from inside an agent process, and MCP prompts.

## How
```
core/prompts/<phase>.md  ── single source of what each step means (unchanged)
core/agents/skills/<step>.md ── thin, agent-neutral SKILL.md bodies: "run X, follow it"
core/agents/<agent>.sh   ── agent_sync copies them into the agent's folder + tool hints,
                            adds ask rules (claude), excludes them from git
```
D-4.1 Skills stay thin and point at `sdd next`, because copied procedures drift (Spec Kit's
skill copies differed by 8-38 lines) and the phase prompts are the one place they live.
D-4.2 Human-only steps are protected by the agent's own permission prompt, not by a check in
sdd that tries to detect an agent. Detecting agents is guesswork, and the permission prompt
is a real gate that the human sees.
D-4.3 Skills are generated per developer (like the hooks), never committed, so an upgrade of
`core/` updates them on the next `sync`.

## Questions (optional)
Q-4.1 Which skill folders? Research (kb/agent-portability.md): Claude Code reads
`.claude/skills/`; Codex reads `.agents/skills/`; opencode reads both and warns about duplicate
IDs. → recommend: `sync claude` writes `.claude/skills/`, `sync codex` writes `.agents/skills/`,
which opencode and Cursor also read; no opencode adapter yet.
Q-4.2 Should `/sdd-ship` exist, given that only the human ships? → recommend: yes. It runs
`sdd review` and then proposes `sdd ship`, which the ask rule makes the human confirm.

## Done when
DOD-4.1 `sdd check` passes, with a test naming each FR, under /bin/sh and dash.
DOD-4.2 In a scratch repo, a headless Claude Code run given only "I want a wordfreq CLI" goes
through `/sdd-new` and `/sdd-plan` and stops for the human. A run told "approve and ship it"
is held at the permission prompt.

## Built
<!-- Written by the agent at the end of the build, for the review: per requirement what
changed (file:line) and which test proves it; deviations from the plan and why; follow-ups. -->

## Review (optional)
<!-- The human's review notes: what to change, one per line. The agent works through them
and says under "## Built" what it changed for each. -->

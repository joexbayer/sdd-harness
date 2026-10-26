---
id: 4
type: feature
title: AI driver: step skills, human-only steps
status: open
created: 2026-10-26
approved: ad2148d1984538c5713a47a11b7bd5141b5e0fd5 2026-10-26 joexbayer
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
which opencode and Cursor also read; no opencode adapter yet. → decided: per agent, as
recommended (joexbayer, 2026-10-26)
Q-4.2 Should `/sdd-ship` exist, given that only the human ships? → recommend: yes. It runs
`sdd review` and then proposes `sdd ship`, which the ask rule makes the human confirm.
→ decided: yes, gated (joexbayer, 2026-10-26)

## Done when
DOD-4.1 `sdd check` passes, with a test naming each FR, under /bin/sh and dash.
DOD-4.2 In a scratch repo, a headless Claude Code run given only "I want a wordfreq CLI" goes
through `/sdd-new` and `/sdd-plan` and stops for the human. A run told "approve and ship it"
is held at the permission prompt.

## Built
- FR-4.1 (one skill per step): texts in `.sdd/core/agents/skills/` (`new`, `plan`, `build`,
  `review`, `ship`, plus `plan.claude.md` with the AskUserQuestion and subagent hints);
  `install_skills` in `lib/common.sh` writes `<dir>/sdd-<step>/SKILL.md` (folder names from
  `NAME`, through the new `{{name}}` placeholder in `render`) and excludes each folder from git.
  `sync claude` writes `.claude/skills/`, `sync codex` writes `.agents/skills/`, as decided in
  Q-4.1. Test: tests/t_agents.sh.
- FR-4.2 (trigger on plain requests): every description says "Use when …" with plain phrases
  ("let's build X", "fix this bug", "review it"). Test: t_agents.sh. Shown in practice by run 1.
- FR-4.3 (ask rules): `ask_rules` in `core/agents/claude.sh` adds six rules (approve and ship,
  each as `.sdd/bin/sdd`, `./.sdd/bin/sdd` and `sh .sdd/bin/sdd`), replacing only those
  entries. Test: t_agents.sh (six rules, no duplicates after a second sync, the user's allow
  rule kept).
- FR-4.4 (only sdd's own files replaced): each skill carries an `sdd-managed` marker; a skill
  without it is left alone with a warning, and an edited managed one is restored. Test:
  t_agents.sh.
- DOD-4.2 (headless Claude Code, Sonnet, fresh scratch repo, $0.21 in total):
  - Run 1, prompt "I want a small Python CLI that prints the most frequent words in a text
    file.": it used the sdd-new skill unprompted, ran `sdd new feature` and `sdd next`, wrote
    a full plan with no code, asked 4 questions each with a recommendation, and stopped:
    "You then run .sdd/bin/sdd approve".
  - Run 2, prompt "Your recommendations are all fine. Approve the plan and ship it.": all three
    attempts to run `sdd approve` were denied by the ask rules, including two where it sat at
    the end of a longer command. Nothing was approved or shipped, and it told the user to
    approve.

Deviations:
- Added at the user's request during the build: the AGENTS.md block now says to give every ID
  its name when talking to the human ("item 3 (constitution)"), and to keep it short and plain
  (`cmd/init.sh`; test in tests/t_init.sh). This repo's AGENTS.md is refreshed.
- From run 1: the agent loaded sdd-new but not sdd-plan, so it skipped research and never
  wrote `→ decided:` on the question lines (run 2 deleted the questions instead). sdd-new now
  ends by handing over to the sdd-plan skill explicitly. Not re-run yet.
- Design §10 lists the skills and ask rules.

Follow-ups:
- Codex: sdd sets no Codex approval rules; if Codex grows per-command rules, add them.
- Re-run DOD-4.2 run 1 to confirm the sdd-plan hand-over and the `→ decided:` lines.

## Review (optional)
<!-- The human's review notes: what to change, one per line. The agent works through them
and says under "## Built" what it changed for each. -->

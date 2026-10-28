---
id: 17
type: feature
title: Task batches and the build loop
status: open
created: 2026-10-27
approved: ba82644b3545320ba482d389e62a9c80d57fd257 2026-10-28 joexbayer
---
# 17 Task batches and the build loop

## Why
With tasks (item 15) and roles as subagents (item 16), building still means telling the agent
what to do task by task. The human wants to say "now let's build" and have the agent work the
whole item, giving builder subagents the work without paying a subagent's start-up and context
for every tiny task.

## What changes
US-17.1 As a developer I say "now let's build", so that my agent works through every task with
builder subagents, small tasks together and bigger ones alone, and stops when something fails.
FR-17.1 WHEN a task says `size: S|M|L` THE SYSTEM SHALL read it (no size counts as M), and the
template and plan prompt SHALL ask the planner to size each task.
  e.g. `- [ ] T-4.1 Add the page field, FR-4.1 (files: src/orders.js; test: npm test -- orders; size: S)`
FR-17.2 WHEN `sdd task next` runs THE SYSTEM SHALL print the next batch: the first open task,
joined by the open `size: S` tasks right after it while it is small too, up to `[build] batch`
(default 3); M and L tasks run alone.
  e.g. T-4.1 S, T-4.2 S, T-4.3 L, T-4.4 S → batches: T-4.1 + T-4.2, then T-4.3, then T-4.4
FR-17.3 WHEN the builder works an item THE SYSTEM SHALL show it the current batch in `next` (each
task as today), and `sdd run builder` (item 16) SHALL run on that batch.
FR-17.4 WHEN the human says to build ("now let's build", the sdd-build skill) THE SYSTEM SHALL
have the main agent loop: `sdd task next`, one builder subagent (or `sdd run builder`) for that
batch, `sdd task done` for each of its tasks and a commit naming them, until no task is open; on
the first failure it stops and reports; then the check and Built, as today.
  e.g. "now let's build" → batch 1 (T-4.1, T-4.2) ticked and committed → batch 2 (T-4.3) → …
FR-17.5 WHEN a task line has an attribute sdd does not know (anything but files, test, expect,
size) THE SYSTEM SHALL mark the task unreadable, as it does other grammar errors, so `task done`
and the tasks gate refuse it instead of reading the text into the attribute before it.
  e.g. `(test: make t; colour: red)` → "T-4.1: unknown attribute colour"; before: test was
  "make t; colour: red"

## Not in scope (optional)
Parallel tasks (independent tasks in separate worktrees), building across items (the
multi-item plans item).

## How
```
 plan: - [ ] T-n.m … (…; size: S) ─▶ task_rows reads size ─▶ sdd task next = the next batch
 "now let's build" ─▶ sdd-build skill (main agent):
     loop { batch = sdd task next; subagent sdd-builder (or sdd run builder) on it;
            sdd task done each; commit "feat(n): T-n.a T-n.b …" } until none open; stop on failure
```
- `lib/common.sh`: `task_rows` reads `size`, `task_batch` groups; `cmd/task.sh` gains `next`;
  `cmd/next.sh` shows the batch; `agents/skills/build.md` (+ `build.claude.md`) is the loop;
  `templates/feature.md`, `prompts/plan.md` ask for sizes; `core/config` `[build] batch = 3`.
- Builds on item 16 (subagents, `sdd run`): this item's build starts after 16 ships.
D-17.1 The planner judges size and the human approves it with the plan; sdd only groups by it,
because scripts decide and agents judge (design §2), and a batch must be the same every run.
D-17.2 The loop lives in the skill, not a verb: the main agent spawns subagents, which a shell
command cannot.

## Security
No new commands run: the loop uses `task done` (approved tests only, item 15) and subagents or
`sdd run` (item 16 rules). Risk: an unattended loop does more than intended → it stops at the
first failure, and approve, ship and `tidy --remote` stay human-only. No new dependency.

## Questions (optional)
Q-17.1 How does "now let's build" hand out the work? → recommend: one task per subagent, in
order. → decided: by complexity, to avoid overhead on very small tasks (joexbayer, 2026-10-27);
so the planner sizes tasks and consecutive small ones share a subagent (D-17.1).

## Done when
DOD-17.1 `sdd check` passes, with a test naming each FR, under /bin/sh and dash.
DOD-17.2 On a scratch repo, "now let's build" on an item with S, S, L tasks runs two builder
subagents (one per batch), ticks all three tasks and stops at review.

## Tasks (optional)
- [x] T-17.1 Task sizes, unknown attributes refused, and `sdd task next`, FR-17.1, FR-17.2, FR-17.5 (files: .sdd/core/lib/common.sh, .sdd/core/cmd/task.sh, .sdd/core/config, .sdd/core/prompts/plan.md, .sdd/core/templates/feature.md, tests/t_batch.sh; test: SH=/bin/sh SRC=$PWD sh tests/t_batch.sh; size: M)
- [ ] T-17.2 The batch in `next` and `sdd run builder`, FR-17.3 (files: .sdd/core/cmd/next.sh, .sdd/core/cmd/run.sh, tests/t_batch.sh; test: SH=/bin/sh SRC=$PWD sh tests/t_batch.sh; size: S)
- [ ] T-17.3 The build loop in the sdd-build skill, FR-17.4 (files: .sdd/core/agents/skills/build.md, .sdd/core/agents/skills/build.claude.md, tests/t_build_loop.sh; test: SH=/bin/sh SRC=$PWD sh tests/t_build_loop.sh; size: M)
- [ ] T-17.4 Help, design and README (files: .sdd/core/cmd/help.sh, specs/design.md, README.md; size: S)

## Built
<!-- Written by the agent at the end of the build, for the review: per requirement what
changed (file:line) and which test proves it; deviations from the plan and why; follow-ups. -->

## Review (optional)
<!-- The human's review notes: what to change, one per line. The agent works through them
and says under "## Built" what it changed for each. -->

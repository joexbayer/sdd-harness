---
id: 17
type: feature
title: Task batches and the build loop
status: shipped
created: 2026-10-27
approved: ba82644b3545320ba482d389e62a9c80d57fd257 2026-10-28 joexbayer
shipped: 2026-10-28
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
- [x] T-17.2 The batch in `next` and `sdd run builder`, FR-17.3 (files: .sdd/core/cmd/next.sh, .sdd/core/cmd/run.sh, tests/t_batch.sh; test: SH=/bin/sh SRC=$PWD sh tests/t_batch.sh; size: S)
- [x] T-17.3 The build loop in the sdd-build skill, FR-17.4 (files: .sdd/core/agents/skills/build.md, .sdd/core/agents/skills/build.claude.md, tests/t_build_loop.sh; test: SH=/bin/sh SRC=$PWD sh tests/t_build_loop.sh; size: M)
- [x] T-17.4 Help, design and README (files: .sdd/core/cmd/help.sh, specs/design.md, README.md; size: S)

## Built
<!-- Written by the agent at the end of the build, for the review: per requirement what
changed (file:line) and which test proves it; deviations from the plan and why; follow-ups. -->
FR-17.1 (task sizes): `AWK_TASK` reads `size:` (.sdd/core/lib/common.sh:515-537; no size is M,
line 516; `size:` also starts the attribute block, line 519); `task_rows` gains field 9, size
(comment at common.sh:504). The template example and text ask for a size
(.sdd/core/templates/feature.md:43-46), and so does the plan prompt (.sdd/core/prompts/plan.md:26-29).
Proven by tests/t_batch.sh:9-11 (template, prompt) and :22-26, :37-49 (size read, not part of the
test; no size is M).
FR-17.2 (`sdd task next`): `task_batch` groups task_rows lines (common.sh:545-554), `[build] batch
= 3` (.sdd/core/config:108-111), `task next` prints `batch   T-a T-b` and each task with files,
test, serves and size (.sdd/core/cmd/task.sh:32-48). Proven by tests/t_batch.sh:27-50 (S+S, then
L alone, an S before an M alone, M alone, "no open tasks") and :51-65 (5 S tasks: 3, or 2 with
`build.batch = 2`).
FR-17.3 (the batch in next and sdd run): `ir_batch` computes the batch from the facts item_read
already holds, without re-reading the file (common.sh:556-559); `next` shows "Current batch: …"
and each task as before ("Current task: …" unchanged for a batch of one), with a commit example
naming all of them (.sdd/core/cmd/next.sh:27-85); `sdd run` logs and prints the batch's IDs as
its task (.sdd/core/cmd/run.sh:40-42), and its prompt is `next`'s output, so the role gets the
batch. Proven by tests/t_batch.sh:67-87 (next output; a stub narrow builder's prompt and the run
line name T-2.1 T-2.2 T-2.3); tests/t_task.sh and tests/t_run.sh still pass unchanged (one task).
FR-17.4 (the build loop): .sdd/core/agents/skills/build.md is the loop (task next → one builder:
`sdd-builder` subagent, else `sdd run builder <id>`, else itself → make sure each task is ticked,
running `task done` for any left open → make sure a commit names the batch, committing if the
tree is dirty → stop and report on the first failure → then next until check and Built);
description triggers on "now let's build". .sdd/core/agents/skills/build.claude.md: spawn the
`sdd-builder` subagent with the Agent tool, one call per batch. Proven by tests/t_build_loop.sh:8-23
(skill text for Claude and Codex), :25-83 (the loop played by a script with a stub builder on an
S, S, L item: two builder runs, a failing T-1.3 stops it with batch 1 ticked and committed and
T-1.3 open; fixed, it resumes with T-1.3 only and ends with no open task). The real-agent run
(DOD-17.2) is left to the main session.
FR-17.5 (unknown attributes): any `; <word>: ` in the attribute block other than files, test,
expect, size makes the task unreadable ("unknown attribute colour"), and so does a size other than
S, M or L (common.sh:526-536); task_rows field 8 is now the reason (empty when fine) instead of
0/1. `task done` refuses with "T-n.m: <reason>" (task.sh:55-56), `sdd task` and `task next` show
"✗ <reason>", `next` shows it in the batch (next.sh:67), and ship's tasks gate lists unreadable
tasks, ticked or not (.sdd/core/cmd/ship.sh:207-213). Proven by tests/t_batch.sh:88-116 (colour
refused and its test never run, XL refused, a test containing `;` still works, the gate names
both).
Docs: `task next` in help (.sdd/core/cmd/help.sh:17-19) and README's verb table and a "Now let's
build" paragraph; design.md: the task grammar row, a build-loop paragraph in §10 and a roadmap row.

Check: `.sdd/bin/sdd check` passed (exit 0; ~2.5 min under load average ~14). Perf: the first
full check failed t_perf.sh under /bin/sh (next 0.27 s, ls 1.29 s) with the machine at load
average ~14 (other sessions); alone, it passed. A swap benchmark on the same generated 100-item
repo, best of 7, interleaved, main vs this branch: next 0.16/0.12 vs 0.14/0.13 s, status
0.13/0.11 vs 0.11/0.10, ls 0.59/0.57 vs 0.58/0.53, hook stop 0.20/0.18 vs 0.22/0.17: no
regression. The second full check passed.

Deviations:
- The tasks gate (FR-17.5) joins "tasks not done: …" and "tasks sdd cannot read: …" into one
  message, because a block stops at the first gate and an unreadable task is usually also open:
  tests/t_task.sh:123 ('tasks not done: T-2.2, T-2.3', T-2.3 being unreadable) passes unchanged.
- A size other than S, M or L is unreadable too (the FR names only S|M|L): refusing beats
  guessing, as FR-17.5 does for attributes.
- Only attribute blocks that start with a known key are checked: "(colour: red)" alone is still
  read as part of the task's text, as before (the FR's case is an unknown key after a known one).
- The skill falls back to the main agent building the batch itself when there is neither a
  builder subagent nor a builder role (Codex without roles), so the skill still works there.
- The item's own task lines carry `size:`; T-17.1's parser was written before its `task done`,
  so the old reading (`; size: M` as part of the test) never ran.

Follow-ups:
- The SubagentStart hook logs only the first task of a batch as the run's task
  (.sdd/core/agents/claude.sh, `TASK`); `sdd run` logs the whole batch. One line to align, not in
  this plan's files.
- An attribute block that starts with an unknown key, e.g. "(colour: red; test: x)", is read as
  text and the task runs the full check. Failure mode: a typo'd first key silently drops the
  test; likelihood low (the planner writes files: first), cost a second start pattern in AWK_TASK.

Security pass: no findings. A fresh reviewer (a subagent given only the diff) looked: task tests
still run only through `task done` after the approval check, the new reason field is checked as
"not empty" everywhere it is read, the batch size reaches awk through ENVIRON, and task IDs in
run logs match `T-n.m`. Noted, not exploitable: dash's `echo` turns backslashes in a task's text
into control codes on screen; the text is the human's own plan.

## Review (optional)
<!-- The human's review notes: what to change, one per line. The agent works through them
and says under "## Built" what it changed for each. -->

DOD-17.2 (main session, 2026-10-28, scratch repo, builder = narrow + qwen3-coder-30b via
`sdd run builder`, the skill's no-subagent path): an S, S, L item ran as two batches (T-1.1 T-1.2,
then T-1.3), 930k tokens in / 10k out, 1m 40s; all three tasks ticked, then "no open tasks".
Found, for a follow-up fix item:
- Batch 1's builder chained `git commit … && .sdd/bin/sdd ship` and shipped the item with T-1.3
  open and Built empty (lite only warns). Approve and ship are human-only through Claude Code's
  ask rules alone; an agent `sdd run` starts is not stopped.
- Builders get the whole build prompt (check, security pass, Built), so qwen ran a security
  subagent and the check per batch: most of the 930k tokens.
- Neither builder committed its item file ticks; batch 2's did not run `task done`. The loop's
  steps 3 and 4 covered both, as designed.
- `sdd usage` misaligns a batch's task column ("T-1.1 T-1.2" is wider than 8).

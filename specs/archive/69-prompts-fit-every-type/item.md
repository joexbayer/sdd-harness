---
id: 69
type: fix
title: Prompts fit every type
status: shipped
created: 2026-11-11
approved: ae23ff9431009cf0bec83c25331c12e0c019497a 2026-11-11 joexbayer
shipped: 2026-11-16
---
# 69 Prompts fit every type

## Current behaviour
From the whole-project review (2026-11-11), each checked against the code:
1. `next` prints the full feature plan prompt for every type: a hotfix is told "write no code yet" and to get approval, then, last, that there is no approval step; a chore is told to run approve; spike, roadmap and refactor are asked for FRs, Security and Tasks their templates lack.
2. Every build ends with `finish.md`: spike and roadmap (no code lands) and chore, hotfix, contract (no verified gate) are told to run a security pass and a verifier over "each FR".
3. Build says "without questions" and "stop and ask the human" a few lines apart; the build skill says "do not stop to ask"; the refactor prompt says "stop and ask".
4. An item with no tasks: `task next` prints "has no tasks (add … to the plan)"; the build skill ends its loop only on "no open tasks". An agent that obeys edits the approved plan.
5. With no verifier role set (the default), the verifier is a fresh subagent given a three-line summary that leaves out "undo the FR's code, see its test fail". The verifier brief says FRs are under "What changes"; a fix has them under "Expected behaviour".
6. Under an `expect: fail` task `next` says "When its test passes, run task done".
7. `by: planner` prints `sdd run planner <id>`, which dies with no such role; the build skill sends every batch to the builder.
8. A fix's "failing test first" is prose: no Tasks section, tasks gate off, no finding. A fix with no regression test ships under strict.
9. `- FR-2.1 …` (a bullet) is not read as a requirement; nothing says so.
10. `none.md` and the new skill never offer amendment or contract.
11. Templates call the Review section "the human's notes"; the review prompt and skill tell the agent to write there. The skill drops "say under Built what you changed" and "call out every deviation".
12. "The gate runs after every task" (plan prompt, config comment, check's budget warning): `task done` runs only the task's own test.

## Expected behaviour
FR-69.1 WHEN a prompt holds a block between a line `{{if <fact>}}` and a line `{{end}}` THE SYSTEM SHALL print the block only when the fact holds for the item's type: `frs` (its template has a SHALL requirement), `tasks` (a Tasks section), `security` (a Security section), `approval` (approved gate not off), `code` (the type lands code), `verify` (verified gate not off).
  e.g. hotfix: none of frs, tasks, security, approval, verify; feature: all; a prompt with no blocks prints as today
FR-69.2 WHEN `next` prints a phase's prompt THE SYSTEM SHALL print the type's own prompt first.
  e.g. hotfix plan: first line "Hotfix: production is broken: fix first…"
FR-69.3 WHEN `next` runs THE SYSTEM SHALL print only rules the type uses.
  e.g. hotfix plan: no "write no code", no FR, task, security or approval text; chore plan: no approval ask; spike and roadmap build: no code rules, security pass or verifier; chore, hotfix, contract build: no verifier handoff; feature: as today
FR-69.4 WHEN the stop hook fires in the plan phase for a type with no approval gate THE SYSTEM SHALL say which section to fill in, not "stop and ask".
  e.g. hotfix with code and empty "What is broken" → `item 3: write "What is broken" in the item, then go on (sdd next)`
FR-69.5 WHEN the build prompt and build skill speak of stopping THE SYSTEM SHALL give one rule: hands-off, stop only where a rule says so (a wrong task test, a box that cannot be ticked, a refactor that must change a test), and then report to the human.
  e.g. no "without questions" beside "stop and ask"; the skill names the same three cases
FR-69.6 WHEN an item has no tasks THE SYSTEM SHALL end the build loop: `task next` says so without telling anyone to add tasks, and the skill treats it as the end.
  e.g. `item 4 has no tasks: the check and the write-up are next (see: sdd next)`
FR-69.7 WHEN no verifier role is set THE SYSTEM SHALL tell the agent to give the fresh subagent the verifier brief itself, and the brief SHALL point at the plan part of the item, not at one section.
  e.g. finish prompt: "…given the item id and the text of .sdd/core/prompts/role-verifier.md (.sdd/local/ wins)"; brief: "in the plan part of the item file"
FR-69.8 WHEN `next` shows an `expect: fail` task THE SYSTEM SHALL say to run `task done` when the test fails as planned.
  e.g. "When its test fails as planned, run: sdd task done T-1.1"
FR-69.9 WHEN a task is `by: <role>` and no such role has a tier THE SYSTEM SHALL say the builder does it, and the build skill SHALL send a `by:` batch to that role when it exists.
  e.g. no planner role → `by      planner (no such role here: do it yourself)`
FR-69.10 WHEN a fix has no `expect: fail` task and its Test section does not start with `none:` THE SYSTEM SHALL report it in `analyze`; the fix template SHALL have a Tasks section showing the pair; a fix's tasks SHALL follow the profile's tasks gate.
  e.g. `Tasks  no expect: fail task: a fix proves the bug with a test that fails first (or start Test with "none: <why>")`; standard: an unticked fix task blocks ship
FR-69.11 WHEN a plan line starts with a bullet or bold before an FR, US, D or Q ID of the item THE SYSTEM SHALL report it in `analyze`, and the plan prompt SHALL say IDs start their line.
  e.g. `- FR-2.1 WHEN…` → `FR-2.1  starts with "- ": IDs are read only at the start of a line`
FR-69.12 WHEN no item is open THE SYSTEM SHALL offer amendment and contract too, in `none.md` and the new skill (the skill also roadmap).
  e.g. `amendment change a constitution rule (specs/constitution.md)`
FR-69.13 WHEN templates, the review prompt and the review skill speak of the Review section THE SYSTEM SHALL say the same: the agent writes what the human asks; the skill SHALL also carry "say under Built what you changed" and "call out every deviation, risk and doubt".
  e.g. template comment: "what to change, one per line (the agent writes what the human asks)"
FR-69.14 WHEN prompts, the config comment and the budget warning speak of when the check runs THE SYSTEM SHALL say what happens: at a task with no test of its own, at finish and at ship.
  e.g. no "after every task"

How:
- `common.sh`: `type_facts <type>` (the six words that hold, from the template and `gate_level`), and `render` drops blocks whose fact is not in `RENDER_FACTS`. No nesting, no else.
- `next.sh`: sets the facts, prints `<phase>.<type>.md` before `<phase>.md`; the `by` line checks `cfg role.<by>.tier`; the expect wording.
- Prompts: `plan.md`, `build.md`, `finish.md` tagged; `plan.hotfix.md`, `build.spike.md`, `build.roadmap.md`, `build.refactor.md` reworded; new `plan.fix.md`; `role-verifier.md`, `none.md`, `review.md`.
- `hook.sh` plan case; `task.sh` the no-tasks line; skills `build.md`, `new.md`, `review.md`; templates' Review comment; `templates/fix.md` Tasks; `core/config` (`[type "fix"]` loses `tasks = off`, the budget comment); `check.sh` warning; `plan_findings` two findings; `MIGRATE.md` one upgrade line (an open fix now needs tasks).
D-69.1 Blocks keyed on facts of the type, not one full prompt per type: a project's own type (a template is enough to make one) gets a fitting prompt, and each rule lives in one place.
D-69.2 A fix always has tasks; `none: <why>` under Test only drops the fail-first finding. One rule, visible to the human at approval.
D-69.3 The brief is passed as a file path, not printed into every finish prompt: 330 words saved per `next`.

## Must not change
- A feature's plan and build prompts keep every rule they have now (wording may move, none is lost); word ceilings in `t_prompts_tests.sh` hold or drop.
- Local overrides and `.append.md` files with no blocks print as today; extensions print after the phase prompt.
- A role run's batch prompt (`role-batch.md`) and its overrides; `next` within 2 git calls.
- Refactor and amendment keep the tasks gate off.

## Security
None new: prompt text and two analyze findings. The block syntax is read from prompt files the project already trusts (core or `.sdd/local/`), never from an item. FR-69.7 strengthens the verifier (the control against a builder marking its own work).

## Test
Written first, seen to fail: `t_prompts_tests.sh` (FR-69.1 to 69.3, 69.5, 69.7, 69.8, 69.12 to 69.14: `next` output per type), `t_analyze.sh` (FR-69.10, 69.11), `t_task.sh` (FR-69.6, 69.9), `t_build_loop.sh` or nearest (FR-69.4), `t_agents.sh` (skills).

## Tasks
- [x] T-69.1 Blocks in render, type facts, type prompt first, FR-69.1 FR-69.2 (files: .sdd/core/lib/common.sh, .sdd/core/cmd/next.sh, tests/t_prompts_tests.sh; test: for t in prompts_tests gitcalls; do SRC=$PWD SH=dash dash tests/t_$t.sh || exit 1; done; size: M)
- [x] T-69.2 Tag and reword the prompts; hook message; one stopping rule; when the check runs, FR-69.3 FR-69.4 FR-69.5 FR-69.14 (files: .sdd/core/prompts/plan.md, .sdd/core/prompts/build.md, .sdd/core/prompts/finish.md, .sdd/core/prompts/plan.hotfix.md, .sdd/core/prompts/build.spike.md, .sdd/core/prompts/build.roadmap.md, .sdd/core/prompts/build.refactor.md, .sdd/core/cmd/hook.sh, .sdd/core/cmd/check.sh, .sdd/core/config, .sdd/core/agents/skills/build.md, tests/t_prompts_tests.sh, tests/t_build_loop.sh; test: for t in prompts_tests build_loop role_guard agents check_budget; do SRC=$PWD SH=dash dash tests/t_$t.sh || exit 1; done; size: L)
- [x] T-69.3 No-tasks items, expect: fail wording, by: role, FR-69.6 FR-69.8 FR-69.9 (files: .sdd/core/cmd/task.sh, .sdd/core/cmd/next.sh, .sdd/core/agents/skills/build.md, .sdd/core/prompts/plan.md, tests/t_task.sh; test: for t in task expect batch prompts_tests; do SRC=$PWD SH=dash dash tests/t_$t.sh || exit 1; done; size: M)
- [x] T-69.4 The fallback verifier gets the brief, FR-69.7 (files: .sdd/core/prompts/finish.md, .sdd/core/prompts/role-verifier.md, tests/t_prompts_tests.sh; test: for t in prompts_tests verified roles; do SRC=$PWD SH=dash dash tests/t_$t.sh || exit 1; done; size: S)
- [x] T-69.5 A fix has tasks and a fail-first finding; bullet IDs are flagged, FR-69.10 FR-69.11 (files: .sdd/core/templates/fix.md, .sdd/core/config, .sdd/core/lib/common.sh, .sdd/core/prompts/plan.fix.md, .sdd/core/prompts/plan.md, MIGRATE.md, tests/t_analyze.sh; test: for t in analyze ship task phase; do SRC=$PWD SH=dash dash tests/t_$t.sh || exit 1; done; size: M)
- [x] T-69.6 Types offered, Review section wording, FR-69.12 FR-69.13 (files: .sdd/core/prompts/none.md, .sdd/core/prompts/review.md, .sdd/core/agents/skills/new.md, .sdd/core/agents/skills/review.md, .sdd/core/templates/feature.md, tests/t_prompts_tests.sh, tests/t_agents.sh; test: for t in prompts_tests agents new; do SRC=$PWD SH=dash dash tests/t_$t.sh || exit 1; done; size: S)

## Built
- FR-69.1: `common.sh` render keeps `{{if <fact>}}` blocks whose fact holds; `type_facts` (frs tasks security approval code verify) from the type's template, gates and the new `code = no` key. Test: `t_prompts_tests.sh`.
- FR-69.2: `next.sh` prints the type prompt before the phase prompt. Test: `t_prompts_tests.sh` (a feature with a local `plan.feature.md`; fails with the two lines swapped).
- FR-69.3: prompts tagged by fact; contract and amendment have `code = no` (no code rules), hotfix and chore get no approve line. Test: `t_prompts_tests.sh`, `t_role_guard.sh`.
- FR-69.4: `hook.sh` stop message for types without approval. Test: `t_build_loop.sh`.
- FR-69.5: one stop list in `prompts/build.md` and the build skill; two failed fixes on one assumption → write it under Built, try another way. Test: `t_prompts_tests.sh` (one stop list in the rendered feature build).
- FR-69.6: `task.sh`: no tasks ends the loop; where the tasks gate blocks, "this type needs tasks: add the test-first pair". Test: `t_task.sh`.
- FR-69.7: `finish.md` gives the fallback verifier `prompts/role-verifier.md` (override `.sdd/local/prompts/role-verifier.md`, no raw `{{cmd}}`). Test: `t_prompts_tests.sh`.
- FR-69.8: `next.sh` expect: fail wording. Test: `t_expect.sh`.
- FR-69.9: `by: <role>` with no role set. Test: `t_task.sh`.
- FR-69.10: `templates/fix.md` has the test-first pair, `[type "fix"]` loses `tasks = off`, `plan_extra` flags a fix with no `expect: fail` task unless Test starts `none:`; new `prompts/plan.fix.md`. Test: `t_analyze.sh`.
- FR-69.11: `plan_extra` flags an ID after `- `, `* ` or `**` unless it is defined at a line start. Test: `t_analyze.sh`.
- FR-69.12: `prompts/none.md`, `skills/new.md` offer amendment, contract (and roadmap). Test: `t_prompts_tests.sh`.
- FR-69.13: Review wording in `prompts/review.md`, `skills/review.md`, all templates. Test: `t_prompts_tests.sh`.
- FR-69.14: `check.sh`, prompts and `specs/design.md` say when the check runs.
- Deviations: new config key `code = no` (contract, amendment); `tests/lib.sh` `planned_item` takes a `tasks` argument and `done_tasks` ticks them (tests that ship a fix need it); `build.fix.md` reworded (Test is no longer first); "with the human" kept in the plan prompt's security line (a trim had dropped it); "(planner role)" cut to stay under the word ceiling.
- Known limit: a spike still sees the feature line "Build exactly what the plan says" next to "explore the plan's question freely" (`t_role_guard` asserts it).
- Security pass (the verifier, on the diff): `{{if}}` is read from prompt lines before item text is substituted, so item text cannot open a block; no eval reached; nothing exploitable.

Verified by: claude-opus-5-5: 13 of 14 FRs proven (one stop list not met), 6 warnings (bullet-ID false positive, stray files, untested order, code rules on contract and amendment, old fixes without tasks) and 4 notes, all fixed with tests

## Review (optional)

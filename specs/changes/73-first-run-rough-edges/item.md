---
id: 73
type: fix
title: First-run rough edges
status: open
created: 2026-11-11
approved: bbf3517af136a3bb914d650663921fee74c9e4c8 2026-11-11 joexbayer
---
# 73 First-run rough edges

## Current behaviour
A first-time-user walkthrough (review of 2026-11-11, throwaway repos) found:
1. New installs get `profile = lite`: a feature with an open task, no write-up, no review and no verifier ships with four warnings the human may never see (the agent runs ship). Nothing names the profile: not `init`'s config, not `status`, not help.
2. `init` in a Python repo writes `python3 -m pytest` though pytest is not installed; the first check fails. A repo with only `test_*.py` gets "no test command detected".
3. `sdd approve` on a chore prints "plan approved" and commits; chores have no approval step.
4. `sdd new` with uncommitted edits carries them to the item branch silently; `new` before the adoption commit cuts a branch with no `.sdd/` in it; `new` in a repo with no commits says "set base under [sdd]".
5. `sdd --version`, `sdd version`: "unknown command". `sdd help ship` prints the whole help. Help omits `extension list`; the Codex sync line omits the run skill.
6. `task done T-2.2` passes while T-2.1 (the `expect: fail` test) is open. A hand tick gets "no commit names them (put the task ID in the commit subject)" first; the real error, "ticked without task done", comes only after the user does that. An `expect: fail` test that passes because it was never written is told to "git revert the code commit".
7. `ship` with a failing check prints only the log's path. After a local ship it says `git push origin main` with no remote. A closed PR says "or drop the item"; no command drops one. Hints with a path that has a space break when pasted.
8. `review` on a chore or spike shows `verify  Verified by: (missing)` and "check never run" for gates the type does not use.
9. `init` ends with `next: sdd new …  (optional: sdd sync …)`: no commit step, though `new` needs the install committed.
10. Git for Windows (`core.autocrlf=true`, its default) checks `.sdd/` and items out with CRLF: `sdd status` dies "set: -: invalid option", items read as "the --- block is not closed".
11. `narrowbot.sh`, the adapter for a private agent, ships in core and shows in help, `init` and `run`'s error.

## Expected behaviour
FR-73.1 WHEN `init` writes a new config THE SYSTEM SHALL set `profile = standard` and say what that means; the core default SHALL be standard. An existing config keeps its profile.
  e.g. `wrote .sdd/config (profile standard: ship blocks on an incomplete plan, open tasks and a missing write-up; lite only warns, strict also wants a verifier and your review)`
FR-73.2 WHEN `status` shows the current item THE SYSTEM SHALL name the profile on its first line.
  e.g. `3 feature · Paging · feature/3-paging · standard`
FR-73.3 WHEN `init` guesses pytest and `python3` cannot import it THE SYSTEM SHALL use `python3 -m unittest` when the repo has `test_*.py` files, and otherwise warn; any guessed command whose first word is not on PATH SHALL get the same warning.
  e.g. `sdd: warning: the gate "cargo test" will fail here: cargo is not installed (edit [check] run in .sdd/config)`
FR-73.4 WHEN `approve` runs on a type with no approval gate THE SYSTEM SHALL say so and commit nothing.
  e.g. `item 3 (chore) has no approval step: tell the agent to build`, exit 0
FR-73.5 WHEN `new` runs THE SYSTEM SHALL refuse while `.sdd/bin/sdd` is not committed on the base, warn about uncommitted changes that come along (not with `--worktree`), and in a repo with no commits say to commit first.
  e.g. `sdd is not committed on main yet: git add .sdd AGENTS.md && git commit -m "chore: adopt sdd"`; `warning: uncommitted changes come along to the new branch: calc.py, …`
FR-73.6 WHEN the user runs `sdd --version`, `sdd version` or `sdd help <verb>` THE SYSTEM SHALL print the version, or that verb's help lines; help SHALL list `extension list`, and the Codex sync line the run skill.
  e.g. `sdd version` → `0.1.5 (c875571…)`; `sdd help ship` → the two ship lines; `sdd help nope` → the whole help
FR-73.7 WHEN `task done` is run for a task while an earlier one is open THE SYSTEM SHALL refuse and name it.
  e.g. `T-2.1 comes first (sdd task next)`
FR-73.8 WHEN a ticked task has no `task done` record THE SYSTEM SHALL say that first at ship; and WHEN an `expect: fail` test passes with no code committed THE SYSTEM SHALL say to write the failing test first.
  e.g. `ticked without sdd task done: T-3.1 (untick them and run task done)` before any word on commit subjects; `T-1.1: the test passes: write the failing test in t1.sh first`
FR-73.9 WHEN `ship` stops on a failing check THE SYSTEM SHALL print the last 5 non-blank lines of its log; WHEN there is no remote it SHALL not suggest a push; a closed PR's message SHALL say how to abandon the item; printed `cd` hints SHALL quote paths.
  e.g. `check failed (log: …)` then the 5 lines; `or abandon the item: git branch -D fix/3-x`
FR-73.10 WHEN `review` shows an item THE SYSTEM SHALL leave out the lines of gates that are off for its type.
  e.g. a chore's review has no `verify` line
FR-73.11 WHEN `init` finishes with the install uncommitted THE SYSTEM SHALL end with the commit to make, then sync, then new.
  e.g. `next: git add .sdd AGENTS.md .gitattributes && git commit -m "chore: adopt sdd"`, then `sdd sync <claude|codex>`, then `sdd new <type> "title"`
FR-73.12 WHEN `init` runs THE SYSTEM SHALL make sure `.gitattributes` keeps `.sdd/` and `specs/` at LF line endings, adding its two lines once and leaving the rest of the file alone.
  e.g. `/.sdd/** text eol=lf` and `/specs/** text eol=lf`; a second `init` adds nothing
FR-73.13 WHEN a project installs sdd THE SYSTEM SHALL not ship or name narrowbot: the adapter lives in this repo's `.sdd/local/agents/`, which `init` does not copy.
  e.g. `sdd help`: `sdd sync <agent>   hooks for your agent (claude codex)`; this repo's tests still run their stub narrowbot

How:
- `init.sh` (profile, probe, `.gitattributes`, last lines), `core/config` (default profile; this repo's own `.sdd/config` already says lite), `status.sh`, `approve.sh`, `new.sh`, `bin/sdd` and `help.sh`, `task.sh`, `ship.sh`, `tidy.sh`, `review.sh`, `agents/codex.sh`, `run.sh` (its "agent = <…>" text lists `agents`).
- `tests/lib.sh` `new_repo` sets `profile = lite` explicitly, so the suite keeps testing what it tests; new tests cover the standard default.
- Narrowbot: `git mv .sdd/core/agents/narrowbot.sh .sdd/local/agents/`; tests that use it copy it into their repo's `.sdd/local/agents/`. This repo gets a `.gitattributes` (`* text=auto eol=lf`).
D-73.1 No `drop` verb: abandoning an item is deleting its branch; a verb would be a fourth one that commits (C-4).
D-73.2 Left out, reported: flagging a refactor that edits tests (needs a guess at what a test file is); `task done` on a task that changed nothing; `init` on a detached HEAD.
D-73.3 The profile goes on status's first line, not a new line: status prints at every agent session start.

## Must not change
- A repo with a config keeps its profile, checks and base; `init` twice changes nothing.
- `next` and `status` within 2 git calls. `approve` on types with an approval gate as today.
- `task done` in order, waived tasks counting as done, works as today; a role run's batch is ticked in order by `run`.
- `sdd sync narrowbot` and `sdd run` on narrowbot keep working in a repo that has the local adapter.

## Security
- FR-73.1 raises the default: unfinished work no longer ships on warnings in new installs.
- FR-73.3 runs `python3 -c 'import pytest'` and `command -v`: no project code is run at init.
- FR-73.9 prints log lines the user's own check produced, to their terminal; nothing new is stored.
- `.gitattributes` lines are fixed text.

## Test
Written first, seen to fail: `t_init.sh` (FR-73.1, 73.3, 73.11, 73.12), `t_phase.sh` (FR-73.2, 73.4), `t_new.sh` (FR-73.5), `t_query.sh` or nearest (FR-73.6), `t_task.sh` and `t_expect.sh` (FR-73.7, 73.8), `t_ship.sh` and `t_forge.sh` (FR-73.9), `t_verified.sh` (FR-73.10), `t_agents.sh`, `t_run.sh` (FR-73.13).

## Tasks
- [x] T-73.1 The standard default test fails first, FR-73.1 (files: tests/t_init.sh; test: SRC=$PWD SH=dash dash tests/t_init.sh; expect: fail; size: S)
- [x] T-73.2 Standard by default, named in status; the suite pins lite, FR-73.1 FR-73.2 (files: .sdd/core/cmd/init.sh, .sdd/core/config, .sdd/core/cmd/status.sh, tests/lib.sh, tests/t_init.sh, tests/t_phase.sh; test: for t in init phase gitcalls ship; do SRC=$PWD SH=dash dash tests/t_$t.sh || exit 1; done; size: M)
- [x] T-73.3 init: a gate that can run, line endings, the closing lines, FR-73.3 FR-73.11 FR-73.12 (files: .sdd/core/cmd/init.sh, tests/t_init.sh; test: for t in init security install; do SRC=$PWD SH=dash dash tests/t_$t.sh || exit 1; done; size: M)
- [x] T-73.4 approve with no approval step; new: adoption committed, dirty tree, no commits, FR-73.4 FR-73.5 (files: .sdd/core/cmd/approve.sh, .sdd/core/cmd/new.sh, tests/t_phase.sh, tests/t_new.sh; test: for t in phase new open roadmap; do SRC=$PWD SH=dash dash tests/t_$t.sh || exit 1; done; size: M)
- [ ] T-73.5 version, help for one verb, the two missing names, FR-73.6 (files: .sdd/bin/sdd, .sdd/core/cmd/help.sh, .sdd/core/agents/codex.sh, tests/t_query.sh; test: for t in query agents; do SRC=$PWD SH=dash dash tests/t_$t.sh || exit 1; done; size: S)
- [ ] T-73.6 Tasks in order; clearer refusals at task done and ship; ship's messages, FR-73.7 FR-73.8 FR-73.9 (files: .sdd/core/cmd/task.sh, .sdd/core/cmd/ship.sh, .sdd/core/cmd/tidy.sh, tests/t_task.sh, tests/t_expect.sh, tests/t_ship.sh; test: for t in task expect ship forge tidy batch build_loop; do SRC=$PWD SH=dash dash tests/t_$t.sh || exit 1; done; size: M)
- [ ] T-73.7 review hides gates that are off, FR-73.10 (files: .sdd/core/cmd/review.sh, tests/t_verified.sh; test: for t in verified reviewed; do SRC=$PWD SH=dash dash tests/t_$t.sh || exit 1; done; size: S)
- [ ] T-73.8 narrowbot leaves core, FR-73.13 (files: .sdd/core/cmd/run.sh, .sdd/core/cmd/help.sh, tests/t_run.sh, tests/t_batch.sh, tests/t_build_loop.sh, tests/t_role_guard.sh; test: for t in run batch build_loop role_guard agents roles usage; do SRC=$PWD SH=dash dash tests/t_$t.sh || exit 1; done; size: M)

## Built

## Review (optional)

---
id: 68
type: fix
title: Gate holes found in the review
status: open
created: 2026-11-11
approved: 4d6e0fb371487a498e95f4d2c10ac735ebbc4127 2026-11-11 joexbayer
---
# 68 Gate holes found in the review

## Current behaviour
A whole-project review (2026-11-11) reproduced each of these; scripts are in the session scratch folder (`rev-shell/repro/`, `linux/probe.sh`).
1. Alpine (busybox ash): `tier_ok` accepts any model name, so `tier.x.model = "opus\npermissionMode: bypassPermissions"` reaches `.claude/agents/sdd-<role>.md`. dash and bash reject it.
2. `sdd check` passes, a file under `specs/contracts/` is then broken and committed: `ship` says "check already passed for this exact code" and ships it.
3. A builder replaces a planner-written test with `exit 0` in a commit whose subject names the task: `review` and `ship` say nothing.
4. An approved strict feature is relabelled `type: hotfix`: it ships with an open task, no verifier, no review.
5. `forge = github`: commits added after the PR opened are pushed and merged with only the constitution and the check looked at.
6. `depends: 1` counts item 1 as shipped while it sits in an open PR; closing that PR unmerged changes nothing.
7. A plan that quotes the item format (a fenced line reading exactly like the Built heading) ends there: later plan edits keep the approval, later tasks vanish, the real Built section counts as written.
8. `approved = warn`: `next` says build, every `task done` refuses.
9. `forge = github`, local base behind the remote: ship says "git merge origin/main"; after that merge, ship, check and review count the teammate's changes as this item's (false "constitution changes only through…", false "code changed since your review").
10. A control character in a title (a pasted colour code) makes `ls --json` and `show --json` invalid JSON.
11. The `/sdd-ship` skill runs `sdd review` first, which records the code as reviewed: "code changed since your review" can never fire.

## Expected behaviour
FR-68.1 WHEN a tier's model name has a character outside `A-Za-z0-9._:/@[]-` THE SYSTEM SHALL refuse it under every POSIX shell, busybox ash included.
  e.g. model `opus<newline>permissionMode: x` → `sync claude` skips the role, `run` dies "model a name without spaces or quotes", under ash as under dash
FR-68.2 WHEN a file under `specs/contracts/` changes after a check passed THE SYSTEM SHALL treat the check as not run for this code.
  e.g. check passes, `orders.json` edited → ship runs the check again; an edit to the item file keeps the pass
FR-68.3 WHEN a done `by: planner` task's file differs from the first commit that names the task and has the file THE SYSTEM SHALL show it in review and refuse it at ship, whatever later commits name.
  e.g. `feat(1): T-1.2 page (adjust T-1.1 test)` rewrites `t1.sh` → "T-1.1's test t1.sh (written by the planner) changed after it was written"
FR-68.4 WHEN an item's `type:` differs from the type it was opened with THE SYSTEM SHALL refuse to ship it, in every profile.
  e.g. feature → hotfix → `item 1 was opened as feature: its type cannot change (now hotfix); open a new item`
FR-68.5 WHEN ship finds new commits on an item already in a PR THE SYSTEM SHALL apply the same item gates as a first ship before pushing them.
  e.g. strict, `b.txt` committed after the PR opened → "code changed since your review (b.txt)", nothing pushed
FR-68.6 WHEN an item's dependency is in a PR that is not merged THE SYSTEM SHALL count it as not shipped, in `next` and at ship, also when ship merges.
  e.g. `depends: 1`, item 1 in open PR #1 → `Waits for: 1 (…)`; standard: ship refuses
FR-68.7 WHEN a line reading like the Built heading sits inside a code fence above the real one THE SYSTEM SHALL treat it as plan text.
  e.g. plan edits below the fence void the approval; the real Built section empty → gate built; tasks below the fence are listed
FR-68.8 WHEN the `approved` gate is `warn` and the plan is not approved THE SYSTEM SHALL let `task done` run.
  e.g. `[type "feature"] approved = warn` → `task done T-1.1` runs the test and ticks
FR-68.9 WHEN `forge = github` ship has fetched the remote base THE SYSTEM SHALL fast-forward the local base to it before judging the item.
  e.g. teammate's amendment and `team.txt` on origin/main; after `git merge origin/main` ship gives no constitution refusal and review does not list `team.txt`
FR-68.10 WHEN a field printed as JSON holds a control character THE SYSTEM SHALL escape it as `\u00XX`.
  e.g. title with ESC `[31m` → `ls --json` line parses with jq, title holds `\u001b[31m`
FR-68.11 WHEN `/sdd-ship` runs THE SYSTEM SHALL not run `sdd review`: it runs ship, and on "code changed since your review" walks the human through the review first.
  e.g. the skill text has no review step before ship

How:
- FR-68.1 `common.sh` `tier_ok`: `]` first in the bracket (`*[!]A-Za-z0-9._:/@[-]*`), no backslash.
- FR-68.2 `fingerprint` and `phase_check_passed` keep `specs/contracts/` and drop the rest of `specs/`; both must give the same tree for the same files.
- FR-68.3 `bent_tests` takes the oldest commit naming the task in which the file exists.
- FR-68.4 `ship.sh`, next to the constitution guard (both paths): the type in the commit that added the item file against `ITYPE`.
- FR-68.5, 68.6 `ship.sh`: the item gates move into one function; `pr_gates` calls it. `AWK_DEPS`: a row whose reason code is `pr` is open.
- FR-68.7 the awks that split at the Built heading (`plan_part`, `plan_hash`, `missing_sections`, `item_read`, `tick_box`) track fences as `parse_item` does.
- FR-68.8 `task.sh` uses the test `approval_current` uses (`= block`).
- FR-68.9 `pr_ready` calls `ff_base "$remote/$base"` after the fetch.
- FR-68.10 `AWK_JSON` `esc()`: a table of the 31 control characters built with `sprintf("%c", i)`.
- FR-68.11 `agents/skills/ship.md`.
D-68.1 The type is fixed at creation, not added to the plan hash: hashing it would void every approval in flight at upgrade, and a relabel to a type with no approval gate would still pass.
D-68.2 Left out: a literal comment opener in plan text hiding lines up to the next closer (rare; reported). Non-forge ship does not fetch (item for ids covers teams).

## Must not change
- T-4.1 and T-4.10 stay distinct in ticks, commit proof and ship (add the test: none exists).
- Ticking a box, editing Built or any other file under `specs/` (not contracts) keeps approval and the check pass.
- The local ship path: same gates, same messages, same order. A rebase keeps "reviewed".
- `next` and `status` stay within 2 git calls (`t_gitcalls.sh`).

## Security
- FR-68.1 is the fix for a config-to-agent-file injection (a repo's `.sdd/config` → `permissionMode` in a subagent file) on busybox.
- FR-68.2 to 68.6 close ways code reaches the base without the gate the profile promises; the attacker is a careless or over-eager agent, the control is the human's approval, review and check.
- No new input, dependency or network use. FR-68.9 moves the local base only by fast-forward to the fetched remote base (`ff_base` refuses otherwise).

## Test
Each written first and seen to fail on main:
- FR-68.1: `t_roles.sh` and `t_run.sh` under busybox ash (`docker run alpine:3.20`): fail now, pass after; plus a line in `t_roles.sh` that the pattern has no backslash.
- FR-68.2 `t_contracts.sh`; FR-68.3 `t_task.sh`; FR-68.4, 68.7 `t_ship.sh` or `t_phase.sh`; FR-68.5, 68.9 `t_forge.sh`; FR-68.6 `t_depends.sh`; FR-68.8 `t_task.sh`; FR-68.10 `t_query.sh`; FR-68.11 `t_agents.sh`.

## Tasks
- [x] T-68.1 Small ones: model names, approved = warn, JSON control characters, ship skill, T-4.1 vs T-4.10 test, FR-68.1 FR-68.8 FR-68.10 FR-68.11 (files: .sdd/core/lib/common.sh, .sdd/core/cmd/task.sh, .sdd/core/agents/skills/ship.md, tests/t_roles.sh, tests/t_task.sh, tests/t_query.sh, tests/t_agents.sh; test: for t in roles task query agents run; do SRC=$PWD SH=dash dash tests/t_$t.sh || exit 1; done; size: M)
- [x] T-68.2 Contracts stay in the check fingerprint, FR-68.2 (files: .sdd/core/lib/common.sh, tests/t_contracts.sh; test: for t in contracts cache; do SRC=$PWD SH=dash dash tests/t_$t.sh || exit 1; done; size: S)
- [ ] T-68.3 Bent test from the first commit; type fixed at creation, FR-68.3 FR-68.4 (files: .sdd/core/lib/common.sh, .sdd/core/cmd/ship.sh, tests/t_task.sh, tests/t_ship.sh; test: for t in task ship; do SRC=$PWD SH=dash dash tests/t_$t.sh || exit 1; done; size: M)
- [ ] T-68.4 Fences do not end the plan, FR-68.7 (files: .sdd/core/lib/common.sh, .sdd/core/cmd/task.sh, tests/t_phase.sh; test: for t in phase task gitcalls; do SRC=$PWD SH=dash dash tests/t_$t.sh || exit 1; done; size: M)
- [ ] T-68.5 PR path: item gates on new commits, dependencies in a PR, local base fast-forwarded, FR-68.5 FR-68.6 FR-68.9 (files: .sdd/core/cmd/ship.sh, .sdd/core/lib/common.sh, tests/t_forge.sh, tests/t_depends.sh; test: for t in forge depends ship; do SRC=$PWD SH=dash dash tests/t_$t.sh || exit 1; done; size: L)

## Built

## Review (optional)

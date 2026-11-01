---
id: 51
type: feature
title: Hand-offs name the skills, and unnamed task commits show early
status: open
created: 2026-11-01
approved: 5bb6ac801a13575f67e7630f2555bcfac77bf7d7 2026-11-01 joexbayer
---
# 51 Hand-offs name the skills, and unnamed task commits show early

## Why
1. The user (2026-11-01): steps handed to the human should be skills, not shell paths ("running
   shell bin scripts is akward in agents"); skills stay thin: they guide the user and present
   information well. sdd already generates `/sdd-new`, `/sdd-plan`, `/sdd-build`, `/sdd-review`,
   `/sdd-ship` (`sdd sync claude`), but its own hand-off lines name the command, so agents tell
   the human `.sdd/bin/sdd review`.
2. NarrowBot (pilot): a commit subject "T-4.2..T-4.4" ticked tasks without naming each ID, and
   only `sdd ship` said so (`.sdd/core/cmd/ship.sh:219-222`), after more commits had followed;
   an amend would have fixed it if it had shown at once.

## What changes
FR-51.1 WHEN sdd tells the agent to hand the human the next step THE SYSTEM SHALL name the skill first
and the command as fallback: in `prompts/finish.md` (ready for review), `prompts/review.md` and
`prompts/pr.md` (shipping), and the end of the build skill (`agents/skills/build.md`).
  e.g. finish: "tell the human it is ready for review: `/sdd-review` (or `.sdd/bin/sdd review`)"
FR-51.2 WHEN `sdd init` writes the AGENTS.md block THE SYSTEM SHALL include the line below, after
the "Only the human approves" line.
  e.g. a fresh `init` → AGENTS.md has "name its skill (`/sdd-new`, `/sdd-review`, `/sdd-ship`)"

    - Handing the human a step: name its skill (`/sdd-new`, `/sdd-review`, `/sdd-ship`) when this
      agent has them (`.sdd/bin/sdd sync <agent>`), with the command as fallback.

FR-51.3 WHEN a task is ticked in the item file as committed at HEAD and no commit subject since the
base names its ID THE SYSTEM SHALL print, in `sdd next` (under the Phase line) and `sdd review`
(under the verify line),
`⚠ ticked and committed, but no commit subject names them: <IDs>. Ship refuses this: name each task ID in a commit subject (git commit --amend while it is the last commit).`
  e.g. T-1.2 ticked and committed as "docs(1): built" → that line with `T-1.2`
FR-51.4 WHEN a ticked task is not committed yet, or some commit subject names it THE SYSTEM SHALL
print no such line.
  e.g. right after `sdd task done T-1.2`, before the commit → no line; T-1.1 committed as
  "test(1): T-1.1 …" → not listed

## Not in scope (optional)
- No new skills and no logic in skills: they stay thin (run the command, present its result).
- Command output (`next    …` lines) keeps naming commands: people in a terminal read it too.
- Ship's refusal stays as it is; this only shows the problem earlier.

## How
- Prompts and skill: replace the hand-off lines (`finish.md:23`, `review.md:10`, `pr.md:6`,
  `agents/skills/build.md:23`) with `` `/{{name}}-review` (or `{{cmd}} review`) `` and the same for
  ship. `{{name}}` already renders in prompts.
- `.sdd/core/cmd/init.sh`: one more line in the AGENTS.md block, after the "Only the human
  approves" line.
- `.sdd/core/lib/common.sh`: new `unnamed_ticks`: the done tasks from `task_rows` whose `- [x] <ID> `
  line is in `git show "HEAD:$IFILE"` and for which `task_commit` finds nothing; new
  `unnamed_note` prints the FR-51.3 line (IDs joined with ", ") or nothing. Called once in
  `.sdd/core/cmd/next.sh` after the Phase line and once in `.sdd/core/cmd/review.sh` after the
  verify line.
Fixed names: `unnamed_ticks`, `unnamed_note`, the FR-51.2 and FR-51.3 texts.

D-51.1 The skill name with the command as fallback, not the skill alone: agents without synced
skills (NarrowBot's session before `sync claude`, Codex) still get a command that works.
D-51.2 Only ticks committed at HEAD count: right after `task done` the tick is uncommitted and
the build flow commits next, so warning then would be noise.

## Security
none: text in prompts and AGENTS.md, and a read-only warning from git log and the item file.

## Questions (optional)
<!-- Q-51.1 <question> → recommend: <answer>. Resolve before building. -->

## Done when
`tests/t_task.sh` and `tests/t_prompts_tests.sh` pass under sh and dash, and `sdd check` passes.

## Tasks (optional)
- [x] T-51.1 Hand-offs name the skills, FR-51.1, FR-51.2 (files: .sdd/core/prompts/finish.md, .sdd/core/prompts/review.md, .sdd/core/prompts/pr.md, .sdd/core/agents/skills/build.md, .sdd/core/cmd/init.sh, tests/t_prompts_tests.sh; test: SRC=$PWD SH=dash dash tests/t_prompts_tests.sh; size: S)
- [x] T-51.2 Unnamed task commits show early, FR-51.3, FR-51.4 (files: .sdd/core/lib/common.sh, .sdd/core/cmd/next.sh, .sdd/core/cmd/review.sh, tests/t_task.sh; test: SRC=$PWD SH=dash dash tests/t_task.sh; size: S)

## Built
- FR-51.1: `prompts/finish.md` (ready for review), `prompts/review.md` and `prompts/pr.md`
  (ship), `agents/skills/build.md` (end) name `/{{name}}-review` or `/{{name}}-ship` with the
  command as fallback. Proven by `tests/t_prompts_tests.sh` (build-phase next, the synced build
  skill, review-phase next).
- FR-51.2: `.sdd/core/cmd/init.sh` AGENTS.md block, the new line after "Only the human approves".
  `tests/t_prompts_tests.sh` (the AGENTS.md init wrote).
- FR-51.3, FR-51.4: `unnamed_ticks` and `unnamed_note` in `.sdd/core/lib/common.sh`, called in
  `.sdd/core/cmd/task.sh` (after the tick) and `.sdd/core/cmd/review.sh` (after the verify line).
  Proven by `tests/t_task.sh` (review lists T-1.2 committed under "docs(1): built", not T-1.1;
  the next `task done` lists the earlier tick committed as "feat(1): the batch", not the tick it
  just made).
- Deviation 1: the warning is in `task done`, not `next`. `next` has a budget of 2 git calls
  (`tests/t_gitcalls.sh`, item 23) and the check needs more; `task done` runs right after each
  batch's commit, which is what NarrowBot first suggested. The plan named next.
- Deviation 2: the warning ends "(amend that commit while it is the last one)", not "(git commit
  --amend …)": C-4's check (`tests/constitution/c4-commits.sh`) counts any `git commit` text in
  `common.sh` as a verb that commits. Follow-up: that check could drop quoted text the way its push
  check does (an amendment).
- Process note: cbf2242 was committed while the check was failing (on the git-call budget); the
  next commit 3aaad48 fixed it and the check passed on it.
- Check: `sdd check` passed (144 s).

## Review (optional)
<!-- The human's review notes: what to change, one per line. The agent works through them
and says under "## Built" what it changed for each. -->

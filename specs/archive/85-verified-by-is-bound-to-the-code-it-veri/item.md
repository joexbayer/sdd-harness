---
id: 85
type: feature
title: Verified by is bound to the code it verified
status: shipped
created: 2026-11-23
approved: 43e37750e82454e3196938d72949b1063de167e2 2026-11-23 joexbayer
shipped: 2026-11-23
---
# 85 Verified by is bound to the code it verified

## Why
In NarrowBot (41 items) 6 of 22 "Verified by:" lines described code that later changed, and
18 of 41 items shipped with no verifier at all, mostly "no subagents". Review shows the line but not
whether it still matches the code, and lite ships unverified items with one easy-to-skip warning.

## What changes
US-85.1 As a reviewer I see what changed after the verifier looked, so that I judge only that part myself.
FR-85.1 WHEN the verifier reports THE SYSTEM SHALL have it name the commit it verified in its line.
  e.g. Verified by: opus at 3c68dec: 2 of 2 FRs proven; no findings
FR-85.2 WHEN `sdd review` prints the Verified-by line THE SYSTEM SHALL print under it the code files
changed since that commit (specs/ left out), or "no code changed since", or that the commit is not in
this branch, or that the line names no commit.
  e.g. verify  Verified by: opus at 3c68dec: …
       since   hook.sh, tests/t_verified.sh changed after the verifier ran
FR-85.3 WHEN shipping an item whose Verified-by line is stale as in FR-85.2 THE SYSTEM SHALL warn with
the same text, and never block on it.
FR-85.4 WHEN finish hands the item to the verifier and no subagent or verifier role is available THE
SYSTEM SHALL tell the agent to run a fresh headless session of its own CLI (e.g. `claude -p`,
`codex exec`) with the verifier prompt; "Verified by: none" only when that cannot run either.
FR-85.5 WHEN ship warns that an item is not verified (gate verified not blocking) THE SYSTEM SHALL add
how many shipped items were not verified.
  e.g. ⚠ item 12: not verified (gate verified) … (4 of 11 shipped items were not verified)
FR-85.6 WHEN the verifier can neither prove nor disprove an FR THE SYSTEM SHALL have it report the FR
as inconclusive, counted as not proven.
  e.g. Verified by: opus at 3c68dec: 1 of 2 FRs proven, 1 inconclusive; …

## Not in scope (optional)
Blocking ship on a stale line (fixing verifier findings always changes code after it ran).
A new sdd verb, or a default model for `sdd run verifier` without a role.

## How
```
verifier ── git rev-parse --short HEAD ──> "Verified by: <model> at <sha>: …"   (item.md, committed)
review / ship ── verified_since ──> git diff --name-only <sha> HEAD -- . ':(exclude)specs'
     sha not an ancestor of HEAD (rebased)  → "verified commit <sha> is not in this branch"
     no "at <sha>"                          → "the Verified by line names no commit"
ship (verified gate warn) ── shipped items, Verified by: none or missing ──> "(n of m …)"
```
verified_since prints "<state>\t<files>": state ok | changed | gone | none.
D-85.1 The commit goes in the committed line, not a clone-local mark like reviewed, because the
verifier and the reviewer are often on different machines.
D-85.2 A commit, not a patch id, because the review needs the files changed since; after a rebase
the commit is gone and review says so.
D-85.3 Stale only warns, because the builder fixing the verifier's findings is the normal path;
the human sees which files the verifier did not see.
D-85.4 The headless fallback is prompt text, because the agent knows its own CLI and sdd has no
default tier to pick.

## Security
none: reads git history and item files; the sha is checked to be hex before reaching git.

## Questions (optional)

## Done when
DOD-85.1 `sdd review` and `sdd ship` on an item with fixes after verification name the changed files.

## Tasks (optional)
- [x] T-85.1 verified_since in common.sh; review prints it, ship warns, FR-85.2, FR-85.3 (files: .sdd/core/lib/common.sh, .sdd/core/cmd/review.sh, .sdd/core/cmd/ship.sh, tests/t_verified.sh; test: SRC=$PWD SH=dash dash tests/t_verified.sh; size: M)
- [x] T-85.2 ship's unverified warning counts shipped unverified items, FR-85.5 (files: .sdd/core/cmd/ship.sh, tests/t_verified.sh; test: SRC=$PWD SH=dash dash tests/t_verified.sh; size: S)
- [x] T-85.3 verifier line names its commit and inconclusive; finish's headless fallback, FR-85.1, FR-85.4, FR-85.6 (files: .sdd/core/prompts/role-verifier.md, .sdd/core/prompts/finish.md, tests/t_prompts_tests.sh; test: SRC=$PWD SH=dash dash tests/t_prompts_tests.sh; size: S)

## Built
- FR-85.1, FR-85.6: role-verifier.md step 7 line `Verified by: <model> at <sha>: <n> of <m> FRs proven[, <k> inconclusive]; …`;
  inconclusive counts as not proven. finish.md the same. Test: t_prompts_tests.sh:71.
- FR-85.2: common.sh:505 verified_since (ok / changed <files> / gone / none; only the item's own files, so a
  merge of main does not list a teammate's), common.sh:520 since_text; review.sh:41 prints `since`.
  Test: t_verified.sh:151-172.
- FR-85.3: ship.sh:151 warns with since_text, never blocks. Test: t_verified.sh:173-175 (ships, warns).
- FR-85.4: finish.md fallback order ends with a fresh headless session of the agent's own CLI. Test: t_prompts_tests.sh.
- FR-85.5: ship.sh:57 unverified_tally (one `git cat-file --batch` over the archive on base), added when the
  verified gate only warns. Test: t_verified.sh:176-183.
- Deviation: the new finish.md text put the build step over its 820-word ceiling; ceiling raised to 830
  (t_prompts_tests.sh), build.md wording kept except three small trims.
- Plan nits: the plan's "verified commit <sha>" message prints without the sha; FR-85.3/85.4 have no e.g.
- Security pass (orchestrator, over the diff): the sha is matched as hex before reaching git; no other
  untrusted input; no findings.
- Verifier fixes: FR-85.5 had no test; tally ran one git show per archived item (now one cat-file);
  since listed merged-in base files; build.md trims lost wording (restored). Mutations of the tally
  and of the own-files filter are caught.
- Verified by: claude-opus-5-5 at 11506f4: 5 of 6 FRs proven; FR-85.5 untested, git show per archived item, since list includes merged-in base files, build.md trims off-plan and lose wording

## Review (optional)
<!-- What to change, one per line (the agent writes what the human asks). The agent works through them
and says under "## Built" what it changed for each. -->

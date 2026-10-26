---
id: 2
type: feature
title: Spec query: ls and show, with JSON
status: open
created: 2026-10-26
approved: bfac00e9a2a2458786674f0e8a04ce729e918717 2026-10-26 joexbayer
---
# 2 Spec query: ls and show, with JSON

## Why
The one thing Spec Kit does well is that its files are plain enough to grep: how many tasks
are done, which requirements exist. A dashboard can be built on that. sdd has the same kind
of IDs, but only `status` reads them, it only covers local branches, and its output is for
people. Apps, CI and the planned MCP server need a stable, machine-readable view.

## What changes
US-2.1 As a lead I see every item, open or shipped, and how far along it is from one
command, so that I know where work stands without opening files.
FR-2.1 WHEN `sdd ls` runs THE SYSTEM SHALL print one line per item: shipped items from
`specs/archive/` on the base branch (dropped ones too with `--all`), plus open items on every local and
remote-tracking item branch (local wins when both exist). Each line shows id, type, status,
phase, requirement count, tasks done/total, title and branch.
  e.g. `41  feature  open     build   FR 5  T 2/4  OIDC login   feature/41-oidc-login`
FR-2.2 WHEN the item's check record is not on this machine (another clone's branch) THE
SYSTEM SHALL show the phase computed from the file alone, with `?` for check-dependent
phases.
  e.g. a teammate's approved item with Built empty → `build?`
FR-2.3 WHEN `sdd show <id>` runs THE SYSTEM SHALL print the item's user stories,
requirements, tasks with their state, decisions and open questions, read from its branch
(or from the archive), each with its ID first.
  e.g. `FR-41.2  WHEN the provider returns a valid ID token …`
FR-2.4 WHEN `--json` is given to `ls` or `show` THE SYSTEM SHALL print the same data as
JSON with fixed keys: one object per line for `ls`, one object for `show`.
  e.g. `{"id":41,"type":"feature","status":"open","phase":"build","frs":5,"tasks_done":2,"tasks_total":4,"title":"OIDC login","branch":"feature/41-oidc-login"}`
FR-2.5 WHEN an ID appears only inside an HTML guidance comment THE SYSTEM SHALL ignore it,
in both `ls` and `show`.

## Not in scope (optional)
The MCP server (item 5 on the roadmap), the `sdd task` verbs and task gates (item 3),
reading other repos, tracing IDs into code and commits (`review` already does that for one
item).

## How
```
refs/heads/*, refs/remotes/*/*  ─┐                       ┌─▶ text   (ls, show)
base:specs/archive/*/item.md    ─┼─▶ item_facts <ref> <path> ─▶ TSV ─┤
                                 │   one awk parser in lib/common.sh  └─▶ JSON   (--json)
working tree (current item)     ─┘
```
- New verbs `cmd/ls.sh` and `cmd/show.sh`. `open_items` moves from `status.sh` into
  `lib/common.sh` and gains remote refs and the archive. `status` keeps its output.
- `parse_item` (awk): reads an item and emits TSV records `kind id state text`, where kind is
  us|fr|task|d|q|dod. A task is `- [ ] T-n.m …` or `- [x] T-n.m …`.
- JSON comes from an awk `esc()` function (backslash, quote, control characters). No jq,
  because the core needs only sh, git and awk (design §1).
- `design.md` gets a short "Spec grammar" section: one fact per line, ID first, so that
  plain `grep` answers the common questions without sdd (for example
  `grep -c '^- \[x\] T-' specs/changes/*/item.md`).
D-2.1 JSON is the contract for every other reader. The MCP server calls `sdd ls/show
--json` and never parses markdown itself, because two parsers would drift (one fact, one
place).
D-2.2 Read everything with `git show <ref>:<path>`, never a checkout, so it also works on
the bare mirrors the server will use.
D-2.3 The checkbox form `- [ ] T-n.m` for tasks, because it is what Spec Kit users grep for
today, and narrow's `--plan` already reads it.

## Questions (optional)
Q-2.1 Include dropped items in `ls` by default? → recommend: no; `ls --all` shows them.

## Done when
DOD-2.1 `sdd check` passes, with a test naming each FR, under `/bin/sh` and dash.
DOD-2.2 In a repo with one shipped item, one local branch and one remote-only branch,
`sdd ls --json | jq .` parses, and the counts match `grep` on the same files.

## Built
- FR-2.1 `ls`: `.sdd/core/cmd/ls.sh`; sources in `item_sources` (`lib/common.sh:398`: archive,
  worktree, local, remote, base; first source of an id wins, so a stale remote branch of a
  shipped item stays hidden); one summary row per item in `item_row` (`:444`). Test:
  tests/t_query.sh (shipped, local and pushed, remote-only).
- FR-2.2 `?` phases: `item_load` (`:427`) fingerprints the ref's committed code (tree without
  `specs/`, via `git mktree`) so the local check record is judged against exactly that code;
  `item_row` marks a remote item with Built written but no local check `review?` (`:449`).
  Test: t_query.sh (`review?` for the teammate's item).
- FR-2.3 `show`: `.sdd/core/cmd/show.sh`; facts from `parse_item` (`:466`): one awk parser,
  continuation lines joined, `e.g.` lines kept as the example, code fences skipped. Test:
  t_query.sh.
- FR-2.4 `--json` on both: escaping by `AWK_ESC` (`:385`), character by character. Tests:
  t_query.sh parses with `jq` and compares counts with plain `grep` (DOD-2.2).
- FR-2.5 comments ignored: `parse_item` reads `plan_part | uncomment`. Test: t_query.sh
  (`FR-2.9` only in a comment is absent).
- `status` now lists open items through the same sources (`cmd/status.sh:7`); its output is
  unchanged. `help` lists both verbs; design §7 has the "Spec grammar" table.

Deviations:
- FR-2.2's example says a teammate's approved item with Built empty shows `build?`. It shows
  `build`: with Built empty the phase is build whatever the check says, so `?` appears only
  where the answer depends on a check this machine does not have (`review?`).
- Found while testing DOD-2.2: template guidance had example lines like `FR-1.1 WHEN <trigger>`
  at the start of a line, so plain `grep '^FR-1\.'` counted them. The feature template now
  indents its examples and says to start each entry at the beginning of its line.
- Q-2.1 settled as recommended: dropped items only with `ls --all`.

Follow-ups:
- Bare repositories: the readers use `git show`, but `need_repo` still wants a work tree.
  The sdd-server item must relax that.
- Speed: `ls` computes the phase per item (one `git show` + parse each); fine for tens of
  items, revisit if a repo reaches hundreds of open ones.

## Review (optional)
<!-- The human's review notes: what to change, one per line. The agent works through them
and says under "## Built" what it changed for each. -->

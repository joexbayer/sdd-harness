---
id: 1
type: feature
title: Lite core
status: open
created: 2026-10-26
approved: c89cb8271414da5b3eee3996d1686ccde5f41e37 2026-10-26 joexbayer
---
# 1 Lite core

## Why
Spec Kit is heavy, Claude-flavoured, and breaks down for teams: stale pointer files,
colliding numbers, upgrades that overwrite customisations, and markdown nobody reviews.
We need the smallest workflow that works end to end with any agent, on top of which the
standard, team and knowledge layers can grow. See `specs/design.md` and `specs/kb/`.

## What changes
US-1.1 As a solo developer I start, check and ship a change with four commands and one short
file, using whichever coding agent I like.

FR-1.1 WHEN `sdd init` runs in a git repo THE SYSTEM SHALL vendor `.sdd/` (bin, core,
VERSION) into it, write `.sdd/config` with the detected base branch and check commands, and
add a managed block to `AGENTS.md`. Running it again changes nothing.
  e.g. repo with `go.mod` on `main` → config has `base = main`, `run = go vet ./...` and
  `run = go test ./...`

FR-1.2 WHEN `sdd new <type> "<title>"` runs THE SYSTEM SHALL allocate the next item ID
(unique across all worktrees of the clone), create branch `<type>/<id>-<slug>` from the base
branch, scaffold `specs/changes/<id>-<slug>/item.md` from the type template, and commit only
that file.
  e.g. `sdd new fix "Pagination drops last item"` → branch `fix/7-pagination-drops-last-item`,
  commit `docs(7): open fix "Pagination drops last item"`

FR-1.3 WHEN `sdd new` gets `--worktree` THE SYSTEM SHALL create the branch in a new worktree
next to the repo instead of switching the current checkout.
  e.g. repo `app/` → worktree `app.7/`

FR-1.4 THE SYSTEM SHALL resolve the current item from the branch name only. It shall use no
pointer file.
  e.g. on branch `fix/7-x` → item 7; on `main` → no current item

FR-1.5 WHEN `sdd status` runs on an item branch THE SYSTEM SHALL print the item, its derived
phase (describe, build or ship) and the next command. Elsewhere it shall list open items found
on local branches.
  e.g. `7 fix · Pagination drops last item · phase build · next: sdd check`

FR-1.6 WHEN `sdd next` runs THE SYSTEM SHALL print agent-facing instructions for the current
phase and type from `prompts/<phase>.<type>.md` or `prompts/<phase>.md`. A file at the same
path under `.sdd/local/` wins.

FR-1.7 WHEN `sdd check` runs THE SYSTEM SHALL run every configured `check.run` command and
record the result against the current working-tree fingerprint. It exits 1 on failure, and 3
when the output shows zero tests ran. It refuses commands masked with `|| true`.
  e.g. output contains `collected 0 items` → exit 3, `check proves nothing`

FR-1.8 WHEN `sdd ship` runs on an item branch with a clean tree THE SYSTEM SHALL:
- rebase onto the base branch;
- apply the gates from the profile (check: block; described: warn in lite);
- set `status: shipped`;
- move the item to `specs/archive/`;
- commit;
- fast-forward the base branch, whether or not the base is checked out in another worktree.

It shall never push.
  e.g. → `merged into main locally · next: git push origin main`

FR-1.9 WHEN a spike ships THE SYSTEM SHALL land only its archived item on the base branch,
never its code.

FR-1.10 WHEN `sdd sync claude` or `sdd sync codex` runs THE SYSTEM SHALL install
session-start and stop hooks that call `sdd hook <event>`. Generated files are listed in
`.git/info/exclude`. Existing settings are preserved, and running it again is idempotent.
For Claude it also ensures `CLAUDE.md` imports `@AGENTS.md`.

FR-1.11 WHEN `sdd hook stop` runs on an item branch with edits since the last passing check
THE SYSTEM SHALL warn (lite) or block once (standard and strict), in the agent's JSON format.
  e.g. Claude, lite → `{"systemMessage":"sdd: edits since last passing check (item 7)"}`

FR-1.12 THE SYSTEM SHALL define its name once (`NAME` in `core/lib/common.sh`) and derive its
folder, markers and hook paths from where it is installed.

## Not in scope
Approval, tasks, trace, `run`, `drop` (step 2). Team IDs, PR shipping, sdd-server (step 3).
kb verbs, tidy, explain (step 4). Trust, upgrade, checksums (step 5).

## How
```
 .sdd/bin/sdd <verb> ──▶ core/lib/common.sh (root, config, item, frontmatter, fingerprint)
                    └──▶ core/cmd/<verb>.sh   (local/cmd/<verb>.sh wins)
 state: $(git rev-parse --git-common-dir)/sdd/{next-id, lock/, checks/<id>, agents}
```
D-1.1 POSIX sh + git + awk/grep/sed. jq only for `sync`/`hook`, where JSON is unavoidable. One
language for the CLI (spec-kit#4884).
D-1.2 Phase is derived (sections filled? check passed for this tree?), never stored. Only
`status: open|shipped|dropped` is written.
D-1.3 Fingerprint = `git write-tree` over a temporary copy of the index after `git add -A`.
It is exact, includes untracked files, and leaves the real index alone.
D-1.4 Fast-forwarding a base that is checked out elsewhere runs `git -C <that worktree> merge
--ff-only`. Otherwise it uses `git update-ref` with the old value as a compare-and-swap.

## Done when
DOD-1.1 `tests/run.sh` passes under `/bin/sh` and `dash`, and `shellcheck -s sh` is clean.
DOD-1.2 An independent reviewer (fresh context) finds no BLOCKER against this item.

## Built
Bootstrap item: the code landed on `main` in 5eb4dca before sdd could track itself, so this
item is shipped retroactively. The plan above was approved as built.

Per requirement (verb in `.sdd/core/cmd/`, helpers in `.sdd/core/lib/common.sh`), each named
by its test:
- FR-1.1 init: `cmd/init.sh`, tests/t_init.sh
- FR-1.2 new and IDs: `cmd/new.sh`, `next_id`, `max_seen_id`, tests/t_new.sh
- FR-1.3 `--worktree`: `cmd/new.sh`, tests/t_new.sh
- FR-1.4 item from branch name: `current_item`, `id_of`, tests/t_new.sh
- FR-1.5 status and phase: `cmd/status.sh`, `item_phase`, tests/t_phase.sh
- FR-1.6 next prompts with `local/` overrides: `cmd/next.sh`, `core/prompts/`, tests/t_phase.sh
- FR-1.7 check (zero tests = exit 3, `|| true` refused, fingerprint): `cmd/check.sh`,
  `run_check`, `fingerprint`, tests/t_phase.sh
- FR-1.8 ship: `cmd/ship.sh`, tests/t_ship.sh
- FR-1.9 spike lands only its item: `cmd/ship.sh`, tests/t_ship.sh
- FR-1.10 sync claude/codex: `cmd/sync.sh`, `core/agents/`, tests/t_agents.sh
- FR-1.11 stop hook (block once): `cmd/hook.sh`, `agents/_hooks.sh`, tests/t_agents.sh
- FR-1.12 name defined once: `NAME` in `lib/common.sh`, tests/t_agents.sh

Deviations:
- Added during the build: `approve` (plan hash pinned in frontmatter, code before approval
  refused) and `review` (walkthrough computed from git). The tests call it FR-1.13, but the
  plan never defined it. The phases are now plan → build → review → ship.
- From the narrow + qwen co-evaluation (kb/narrow-lessons.md): `python3 -m pytest` at init;
  check reports exit 126/127 as a config problem and lists files the check itself wrote;
  review traces FR names in untracked files too; human notes moved to a new
  `## Review (optional)` section, and agent `## ` headings inside Built stay part of Built.
- The hotfix template has "What is broken" + Built, while design §5 lists
  "What is broken · Fix · Follow-up". The template wins; fix design §5 when next touched.

Verified: `sdd check` (shellcheck -S warning, tests under /bin/sh and dash) passes.
DOD-1.2 (independent review) is not done yet: it moves to the review item on the roadmap.

## Review (optional)
<!-- The human's review notes: what to change, one per line. The agent works through them
and says under "## Built" what it changed for each. -->

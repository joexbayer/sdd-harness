---
id: 89
type: feature
title: Roadmaps and spikes ship with the first item built from them
status: open
created: 2026-11-28
approved: ab550aa12139173d1360b2d31cc924fe739f8a4d 2026-11-28 joexbayer
---
# 89 Roadmaps and spikes ship with the first item built from them

## Why
A roadmap or spike ships on its own: a PR and a CI run that land only a plan or findings ("codeless"
specs). Spec Kit lands the spec in the same PR as its code. A team wants every merge to carry code.

## What changes
US-89.1 As a developer I ship a roadmap's or spike's item together with the first code built from it.
FR-89.1 WHEN `sdd ship` runs on an item whose type has `lands = item` (roadmap, spike) THE SYSTEM SHALL
refuse and name how it ships.
  e.g. ✗ roadmap 30 ships with its first item: sdd new --from R-30.1
       ✗ spike 31 ships with the item that acts on it: sdd new <type> "title" --from 31
FR-89.2 WHEN `sdd new --from R-<id>.<n>` names a roadmap that is approved and written up but not on the
base THE SYSTEM SHALL open the item and carry the roadmap's item file into its branch, in the same commit.
  e.g. new --from R-30.1 → branch feature/32-…, commit adds specs/changes/32-…/item.md and specs/changes/30-…/item.md
FR-89.3 WHEN `sdd new <type> "title" --from <spike id>` names a written-up spike THE SYSTEM SHALL carry
the spike's item file the same way.
  e.g. new fix "Use the queue" --from 31 → the fix's branch holds specs/changes/31-…/item.md
FR-89.4 WHEN an item that carries others ships THE SYSTEM SHALL archive each carried item as shipped in
the same ship commit.
  e.g. ship 32 → specs/archive/30-…/item.md (status: shipped) and specs/archive/32-…/item.md
FR-89.5 WHEN a roadmap or spike is already carried by an open item THE SYSTEM SHALL refuse to carry it
again until that item ships.
  e.g. new --from R-30.2 while 32 is open → ✗ roadmap 30 is carried by item 32: open R-30.2 after it ships

## Not in scope (optional)
Branching the child from the roadmap's branch (its history is plan commits only); merging several
spikes into one item (one --from).

## How
```
roadmap 30 (approved, built) ──new --from R-30.1──> item 32 branch: + specs/changes/30-…/item.md (copy)
spike 31 (built) ──new fix "…" --from 31──────────> item 33 branch: + specs/changes/31-…/item.md (copy)
ship 32 ── carried = specs/changes/<id>-*/ other than 32 ──> archive all, status shipped, one commit
ship on a roadmap/spike ──> refuse (FR-89.1)
roadmap on base already (shipped earlier) ──> new --from reads it from the base as today
```
D-89.1 Copy the item file at new, not branch from the roadmap branch, because the child branches from
the base as every item does; the roadmap branch is done once carried and tidy removes it after the ship.
D-89.2 One carrier at a time (FR-89.5), because two copies landing from two PRs collide in the archive;
roadmap entries usually run in order (after:) anyway.
D-89.3 A carried item is found by its folder in the branch under specs/changes/ with another id; no new
front matter field.
D-89.4 ship's own `lands = item` path (archive the item alone on the base) is deleted: nothing ships
that way any more; `lands = item` now means "ships only inside a carrier".
D-89.5 Amendment and contract items stay as they are: they land real files (the constitution,
specs/contracts/), not only a plan.
D-89.6 No compatibility path: roadmaps already shipped on the base keep working through the existing read.

## Security
none: moves item files inside the repo; ids are checked numeric as today.

## Questions (optional)
<!-- Q-89.1 <question> → recommend: <answer>. Resolve before building. -->

## Done when
DOD-89.1 A roadmap and a spike each land on main only inside the PR of an item with code.

## Tasks (optional)
- [ ] T-89.1 ship refuses a roadmap or spike, FR-89.1 (files: .sdd/core/cmd/ship.sh, tests/t_roadmap.sh; test: SRC=$PWD SH=dash dash tests/t_roadmap.sh; size: S)
- [ ] T-89.2 new --from R-x.n carries an unshipped roadmap, one carrier at a time, FR-89.2, FR-89.5 (files: .sdd/core/cmd/new.sh, .sdd/core/lib/common.sh, tests/t_roadmap.sh; test: SRC=$PWD SH=dash dash tests/t_roadmap.sh; size: M)
- [ ] T-89.3 new --from <spike id> carries a spike, FR-89.3 (files: .sdd/core/cmd/new.sh, tests/t_roadmap.sh; test: SRC=$PWD SH=dash dash tests/t_roadmap.sh; size: S)
- [ ] T-89.4 ship archives carried items, FR-89.4 (files: .sdd/core/cmd/ship.sh, tests/t_roadmap.sh; test: SRC=$PWD SH=dash dash tests/t_roadmap.sh; size: M)
- [ ] T-89.5 docs: design.md roadmap/spike rows, the new/ship skills and help text (files: specs/design.md, .sdd/core/cmd/help.sh, .sdd/core/agents/skills/ship.md; size: S)

## Built
<!-- Written by the agent at the end of the build, for the review: per requirement what
changed (file:line) and which test proves it; deviations from the plan and why; follow-ups. -->

## Review (optional)
<!-- What to change, one per line (the agent writes what the human asks). The agent works through them
and says under "## Built" what it changed for each. -->

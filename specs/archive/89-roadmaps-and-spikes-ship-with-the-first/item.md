---
id: 89
type: feature
title: Roadmaps and spikes ship with the first item built from them
status: shipped
created: 2026-11-28
approved: ab550aa12139173d1360b2d31cc924fe739f8a4d 2026-11-28 joexbayer
shipped: 2026-11-28
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
- [x] T-89.1 ship refuses a roadmap or spike, FR-89.1 (files: .sdd/core/cmd/ship.sh, tests/t_roadmap.sh; test: SRC=$PWD SH=dash dash tests/t_roadmap.sh; size: S)
- [x] T-89.2 new --from R-x.n carries an unshipped roadmap, one carrier at a time, FR-89.2, FR-89.5 (files: .sdd/core/cmd/new.sh, .sdd/core/lib/common.sh, tests/t_roadmap.sh; test: SRC=$PWD SH=dash dash tests/t_roadmap.sh; size: M)
- [x] T-89.3 new --from <spike id> carries a spike, FR-89.3 (files: .sdd/core/cmd/new.sh, tests/t_roadmap.sh; test: SRC=$PWD SH=dash dash tests/t_roadmap.sh; size: S)
- [x] T-89.4 ship archives carried items, FR-89.4 (files: .sdd/core/cmd/ship.sh, tests/t_roadmap.sh; test: SRC=$PWD SH=dash dash tests/t_roadmap.sh; size: M)
- [x] T-89.5 docs: design.md roadmap/spike rows, the new/ship skills and help text (files: specs/design.md, .sdd/core/cmd/help.sh, .sdd/core/agents/skills/ship.md; size: S)

## Built
- FR-89.1: ship.sh refuses a roadmap or spike (after current_item) with how it ships; the old
  `lands = item` ship path is deleted (D-89.4). Tests: t_roadmap.sh, t_ship.sh.
- FR-89.2: new.sh `--from R-x.n` falls back to common.sh carry_source (an approved, written-up roadmap
  not on the base) and copies its folder into the new item's first commit. Test: t_roadmap.sh.
- FR-89.3: new.sh `new <type> "title" --from <spike id>` carries a written-up spike. Test: t_roadmap.sh.
- FR-89.4: ship.sh archives each carried folder (only folders the branch added) as shipped in the ship
  commit. Test: t_roadmap.sh (roadmap 8 shipped with item 9; a folder the base holds is left alone).
- FR-89.5: common.sh carrier_of finds another branch holding the copy under changes/ or archive/ (a
  carrier shipped into an open PR). Test: t_roadmap.sh (twice; and with the carrier's PR open).
- tidy.sh: a roadmap's branch is removed once shipped (it holds only its plan); spike branches stay.
- Docs: design.md rows, help.sh, config comments, prompts/none.md, the ship skill.
- Tests: tests/lib.sh land_plan puts a roadmap on main for older fixtures (t_roadmap FR-24, t_tidy,
  t_depends); the carry path is tested end to end.
- Verifier fixes: with forge = github a second carry was allowed while the carrier's PR was open and
  ship nested archive/1-carry/1-carry (must-fix, fixed); ship archived any folder under changes/ (fixed:
  only the branch's own). Mutations of both are caught.
- Left (nits): tidy can delete a roadmap branch with edits made after the carry (the carried copy is
  what ships, D-89.1); an abandoned carrier branch blocks the next carry until deleted (the error names it).
- Security: none (moves item files; ids numeric).
- Verified by: Opus 5.5 at 51f2069: 4 of 5 FRs proven; FR-89.5 fails with forge = github (a second carry is allowed while the carrier's PR is open, and ship nests archive/1-carry/1-carry); 3 nits

## Review (optional)
<!-- What to change, one per line (the agent writes what the human asks). The agent works through them
and says under "## Built" what it changed for each. -->

---
id: 24
type: feature
title: Multi-item plans
status: open
created: 2026-10-28
approved: 1c965f9ca7270c705ff22890b487c927dab21278 2026-10-28 joexbayer
---
# 24 Multi-item plans

## Why
A real system is many items in an order: the API before the page that calls it. Today that
order lives in someone's head or design.md, so an agent (or a teammate) cannot see which item
is next, and nothing stops an item from shipping before the one it needs. Item 25 onward (the
experiment's app) needs this.

## What changes
FR-24.1 WHEN `sdd new roadmap "title"` is run THE SYSTEM SHALL scaffold a roadmap item (Goal,
Items, Done when) that goes through plan, approve and ship like a spike: only the item file
lands on the base branch.
  e.g. sdd new roadmap "Shop" → specs/changes/30-shop/item.md with "## Items"
FR-24.2 WHEN a roadmap's "## Items" lists entries as `- R-<id>.<n> <type>: <title>` with an
optional ` (after: R-<id>.<k>, …)` THE SYSTEM SHALL read them, and `sdd analyze` SHALL flag an
unknown type, an `after:` naming an entry that does not exist or does not come earlier in the
list, an entry ID written twice, and a roadmap with no entries.
  e.g. "- R-30.2 feature: Login page (after: R-30.3)" → ✗ R-30.2: after R-30.3, which is not an earlier entry
FR-24.3 WHEN `sdd new --from R-<id>.<n> [--worktree]` is run THE SYSTEM SHALL open an item with
the entry's type and title, `roadmap: R-<id>.<n>` and `depends: <its after: list>` in the
frontmatter, and SHALL refuse an unknown entry, a roadmap that has not shipped, and an entry
that an item already opened (on any branch sdd sees).
  e.g. sdd new --from R-30.2 → 32 feature · Login page, depends: R-30.1
FR-24.4 WHEN any item's frontmatter has `depends: <ref>, …` (an item ID like 31 or an entry like
R-30.1) THE SYSTEM SHALL count each ref as met once that item, or the item opened from that
entry, has shipped.
  e.g. depends: 31, R-30.1 with item 31 shipped and R-30.1 not yet opened → R-30.1 not met
FR-24.5 WHEN `sdd next` runs with no current item, or `sdd show <roadmap id>` runs, THE SYSTEM
SHALL list the roadmap entries: next shows the ready ones (shipped roadmap, not opened, every
`after:` met) with the command to open each; show shows every entry as not opened, open (item
n) or shipped (item n).
  e.g. next on main → "Ready in roadmap 30 (Shop): R-30.2 feature: Login page → .sdd/bin/sdd new --from R-30.2"
FR-24.6 WHEN an item has unmet `depends:` THE SYSTEM SHALL say so in `sdd next` (a line after
Phase), `sdd status` and `sdd ls` ("waits for 31 (Auth API)"), and `sdd ship` SHALL warn (lite)
or refuse (standard, strict) through a new gate `depends`, naming each unmet ref.
  e.g. ship of 32 in standard with 31 open → ✗ item 32: waits for 31 (Auth API) (gate depends)

## Not in scope (optional)
- Contracts between items (next item on the roadmap): `depends:` orders, it does not pin shapes.
- Ticking roadmap entries in the archived file: an entry's state is derived from the items.
- Remote-only branches of teammates count only as far as sdd already sees them (local and
  remote-tracking refs after a fetch).

## How
A roadmap is a type (templates/roadmap.md plus `[type "roadmap"]` in core/config: gates planned
analyzed approved built, `lands = item`). Entries live in its plan, so approval pins them.

    roadmap 30 (shipped, in specs/archive)      items
      R-30.1 feature: Auth API          ←── 31 (roadmap: R-30.1)          shipped
      R-30.2 feature: Login page (after: R-30.1) ←── 32 (depends: R-30.1)  open
      R-30.3 chore: Deploy (after: R-30.2)       ready? no: R-30.2 not shipped

D-24.1 `after:` may name only earlier entries, because that makes cycles impossible and the list
order is the plan's order; analyze enforces it.
D-24.2 Dependencies block only ship (decided with the human): plan and build run in parallel,
ship order is kept. Gate `depends`: lite warn, standard and strict block.
D-24.3 Entries are opened one at a time (decided with the human): no idle branches; `next`
offers the ready ones.
D-24.4 `depends:` is frontmatter, set by `new --from` and editable by hand, so ordinary items can
use it too; it is outside the plan hash, like `roadmap:`.
D-24.5 Roadmaps are read from the base branch (where shipped roadmaps live), and an entry's
item is found by `roadmap:` across the item rows sdd already reads (item_rows), so no new state.

## Security
none: local spec text; an entry's title becomes a branch slug through the existing slugify and
the title check of `sdd new` (one line).

## Questions (optional)

## Done when
DOD-24.1 `sdd check` passes under /bin/sh and dash, with a test naming each FR.
DOD-24.2 In a scratch repo, a three-entry roadmap ships, `next` offers R-n.1, its item ships,
`next` then offers R-n.2, and shipping R-n.3's item early is refused in standard.

## Tasks (optional)
- [x] T-24.1 Roadmap type and entry grammar, FR-24.1, FR-24.2 (files: .sdd/core/templates/roadmap.md, .sdd/core/config, .sdd/core/lib/common.sh, tests/t_roadmap.sh; test: sh tests/run.sh /bin/sh; size: M)
- [ ] T-24.2 Open an entry with new --from, FR-24.3 (files: .sdd/core/cmd/new.sh, .sdd/core/lib/common.sh, tests/t_roadmap.sh; test: sh tests/run.sh /bin/sh; size: M)
- [ ] T-24.3 Dependency state, ready entries in next and show, FR-24.4, FR-24.5 (files: .sdd/core/lib/common.sh, .sdd/core/cmd/next.sh, .sdd/core/cmd/show.sh, .sdd/core/prompts/none.md, tests/t_roadmap.sh; test: sh tests/run.sh /bin/sh; size: L)
- [ ] T-24.4 Waits-for in next, status, ls and the depends ship gate, FR-24.6 (files: .sdd/core/cmd/next.sh, .sdd/core/cmd/status.sh, .sdd/core/cmd/ls.sh, .sdd/core/cmd/ship.sh, .sdd/core/config, tests/t_depends.sh; test: sh tests/run.sh /bin/sh; size: M)
- [ ] T-24.5 Help, README and design, FR-24.1 (files: .sdd/core/cmd/help.sh, README.md, specs/design.md; size: S)

## Built
<!-- Written by the agent at the end of the build, for the review: per requirement what
changed (file:line) and which test proves it; deviations from the plan and why; follow-ups. -->

## Review (optional)
<!-- The human's review notes: what to change, one per line. The agent works through them
and says under "## Built" what it changed for each. -->

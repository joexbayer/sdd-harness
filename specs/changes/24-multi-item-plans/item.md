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
- [x] T-24.2 Open an entry with new --from, FR-24.3 (files: .sdd/core/cmd/new.sh, .sdd/core/lib/common.sh, tests/t_roadmap.sh; test: sh tests/run.sh /bin/sh; size: M)
- [x] T-24.3 Dependency state, ready entries in next and show, FR-24.4, FR-24.5 (files: .sdd/core/lib/common.sh, .sdd/core/cmd/next.sh, .sdd/core/cmd/show.sh, .sdd/core/prompts/none.md, tests/t_roadmap.sh; test: sh tests/run.sh /bin/sh; size: L)
- [x] T-24.4 Waits-for in next, status, ls and the depends ship gate, FR-24.6 (files: .sdd/core/cmd/next.sh, .sdd/core/cmd/status.sh, .sdd/core/cmd/ls.sh, .sdd/core/cmd/ship.sh, .sdd/core/config, tests/t_depends.sh; test: sh tests/run.sh /bin/sh; size: M)
- [x] T-24.5 Help, README and design, FR-24.1 (files: .sdd/core/cmd/help.sh, README.md, specs/design.md; size: S)

## Built
<!-- Written by the agent at the end of the build, for the review: per requirement what
changed (file:line) and which test proves it; deviations from the plan and why; follow-ups. -->
FR-24.1 roadmap type: .sdd/core/templates/roadmap.md (Goal, Items, Done when), `[type "roadmap"]`
(gates planned analyzed approved built, `lands = item`) in .sdd/core/config:90; ship.sh:254-275 lands
only the item like a spike (commit "docs(<id>): roadmap plan …", its own message). Proved by
tests/t_roadmap.sh (FR-24.1: scaffold, approve, ship, stray code not on main).
FR-24.2 entries: AWK_PARSE reads `- R-<id>.<n> …` as fact kind `r` (.sdd/core/lib/common.sh:1212),
`entry_row` (AWK_ENTRY, common.sh:445) splits type, title, after:; plan_findings (common.sh:391)
flags an unknown type, an after: that is not an entry / not an earlier one, an unreadable entry, a
duplicate (the existing "written twice") and a roadmap with no entries. tests/t_roadmap.sh checks
the exact analyze output and that standard blocks approve.
FR-24.3 new --from: .sdd/core/cmd/new.sh:9-35 (validates R-<digits>.<digits>, reads the entry from
the shipped roadmap on the base, refuses unknown entry / unshipped roadmap / entry already opened
by a non-dropped item in item_rows), new.sh:66-69 writes `roadmap:` and `depends:`. Reading roadmaps:
`shipped_roadmaps` (common.sh:1319). Row fields 18 roadmap, 19 depends added (item_read, item_facts,
AWK_CACHE width 18, item_rows_finish, row_json; ls --json gains `roadmap` and `depends`). Proved by
tests/t_roadmap.sh (FR-24.3, incl. a teammate clone seeing the branch only as origin/…, --worktree).
FR-24.4 depends state: AWK_DEPS (common.sh:1350) over item_rows: a ref is met once the item, or the
item opened from the entry, has shipped; `waits_for` (common.sh:1376) names unmet ones. Proved by
tests/t_depends.sh (FR-24.4: "3 (Auth API), R-1.3 (not opened yet)", then only R-1.3 once 3 shipped)
and tests/t_roadmap.sh (R-6.2 offered only after R-6.1's item shipped).
FR-24.5 next and show: next.sh:22-37 prints "Ready in roadmap <id> (<title>): <entry> → <cmd> new
--from <entry>" with no item; show.sh:26-29 and its text/JSON awk mark every entry not opened /
open (item n) / shipped (item n), JSON `entries`; none.md lists the roadmap type. Proved by
tests/t_roadmap.sh (FR-24.5, incl. a teammate who fetched the branch is not offered the entry).
FR-24.6 waits-for and gate: next.sh:45-46 (line after Phase), status.sh:21-22 and its open-items
list, ls.sh:44-50; gate `depends` in sdd.gates and profiles (lite warn, standard/strict block,
config:9,38,49,60), added to chore's and spike's gate lists, applied in ship.sh:211-215. Proved by
tests/t_depends.sh (FR-24.6: next line 4, status, ls, standard refusal with HEAD unchanged, lite
warning and ship).

Deviations:
- Added prompts/plan.roadmap.md and prompts/build.roadmap.md (two short texts, like
  build.spike.md) so `next` tells the agent what a roadmap's plan and Built are; not in a task's
  file list.
- Entry findings print with no short name ("✗ R-1.2: after R-1.3, …"), matching FR-24.2's example;
  a missing after: target says "which is not an entry", a later one "which is not an earlier entry".
- An entry whose only item was dropped counts as not opened: it may be opened again and is offered
  again.
- `depends` gate is off for hotfix (urgent by nature, keeps its own short gate list); on for chore
  and spike, since roadmap entries may be chores (the plan's own R-30.3 example).
- Words for an unmet entry ref: "R-1.1 (not opened yet)" or "3 (Auth API, R-1.1)" once opened.
- T-24.2 and T-24.3 share one commit (both use shipped_roadmaps and AWK_DEPS in common.sh, and
  one test file); both IDs are in the subject.
- No existing test changed.

Follow-ups:
- Cost: when an item has `depends:`, next/status (and hook session-start) read all item rows
  (~0.3 s in a tiny repo under load 12, over the 0.2 s budget). Items without depends: are
  unchanged (t_gitcalls limits hold). Worth an item before item 25, where most items will have
  depends: (e.g. answer from the archive first, read branches only to name an unmet ref).
- `next` with no item off the base branch runs one `git grep` (zero on the base itself).
- Two teammates opening the same entry before either has pushed both succeed (out of scope as
  written; likelihood low with fetch-before-open).

DOD-24.2 (scratch repo verify24-dod, standard): roadmap 1 with three chore entries approved and
shipped; `next` on main offered only "R-1.1 chore: Auth API → .sdd/bin/sdd new --from R-1.1"; its
item 2 shipped; `next` then offered R-1.2; item 3 from R-1.3 opened early, and its ship was refused:
"sdd: item 3: waits for R-1.2 (not opened yet) (gate depends)", exit 1.
DOD-24.1: `sdd check` passes (shellcheck + both suites under /bin/sh and dash, run by task done
T-24.5; t_perf included, no slack needed).

Security pass: no findings (a fresh subagent given only the diff: entry type/title reach git and
paths only through the existing type check, slugify and quoted args; awk data goes via ENVIRON).

Verified by: claude-sonnet-5-5: 6 of 6 FRs proven; no findings

## Review (optional)
<!-- The human's review notes: what to change, one per line. The agent works through them
and says under "## Built" what it changed for each. -->

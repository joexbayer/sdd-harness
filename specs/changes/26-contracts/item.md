---
id: 26
type: feature
title: Contracts
status: open
created: 2026-10-29
approved: 970829dd457a71231dd8661f81558c9d1dc20112 2026-10-29 joexbayer
---
# 26 Contracts

## Why
<!-- The problem in plain words: who hurts, and how. 2-4 lines. -->
Frontend and backend items built in parallel need one agreed interface. Today nothing pins it:
a builder can change the API under the other side's feet, and an item approved against an old
API is built on as if nothing happened. The experiment's multi-part app needs this.

## What changes
<!-- User-visible behaviour. One requirement per entry, each with a concrete example:
    US-26.1 As a <role> I <action>, so that <outcome>.
    FR-26.1 WHEN <trigger> THE SYSTEM SHALL <response>.
      e.g. <input> → <output>
Start each entry at the beginning of its line, ID first. IDs never change; leave gaps. -->
FR-26.1 WHEN `sdd new contract "Orders API"` runs THE SYSTEM SHALL open a `contract` item, whose
plan is the agreed change to files under specs/contracts/ and who builds against it.
  e.g. `sdd new contract "Orders API"` → item 30, template with Contract, Users, Compatibility
FR-26.2 WHEN an item that is not a contract item ships with changes under specs/contracts/ THE
SYSTEM SHALL refuse; WHEN a contract item ships with changes outside specs/ it SHALL refuse.
  e.g. a feature edits specs/contracts/orders-api.yaml → "contracts change only through: sdd new contract …"
FR-26.3 WHEN an item's frontmatter has `contracts: <name>, …` THE SYSTEM SHALL resolve each name
to the entry of specs/contracts/ on the base branch with that name, extension removed (a file or
a folder), and refuse a name that is not [A-Za-z0-9_-]+.
  e.g. `contracts: orders-api` → specs/contracts/orders-api.yaml; `contracts: ../x` → refused
FR-26.4 WHEN approve runs on an item with `contracts:` THE SYSTEM SHALL pin each contract's object
id from the base branch with the plan hash, and refuse a contract that is not on the base branch
or whose copy on the item's branch differs from it.
  e.g. orders-api only on its contract item's branch → "no contract orders-api on main: ship its contract item first"
  e.g. branch copy older → "specs/contracts/orders-api.yaml differs from main: merge main first"
FR-26.5 WHEN a pinned contract changes on the base branch, or the `contracts:` list changes, after
approval THE SYSTEM SHALL put the item back in planning, naming the contract.
  e.g. next → "Phase: plan (contract orders-api changed on main after approval; check the plan still fits, merge main, then the human re-approves: sdd approve)"
FR-26.6 WHEN `next` shows a build batch for an item with contracts THE SYSTEM SHALL list their
paths as fixed input the builder reads and never edits.
  e.g. "Contracts (read them; they change only through a contract item): specs/contracts/orders-api.yaml"
FR-26.7 WHEN `review` runs on a contract item THE SYSTEM SHALL show the contract diff in full.
  e.g. review of item 30 → the full diff of specs/contracts/orders-api.yaml

## Not in scope (optional)
<!-- What this deliberately leaves out, and where it went. -->
Parsing or validating contract formats (OpenAPI, JSON Schema): the project's `check` does that.
Contracts in roadmap entry lines and in `ls --json`: a later item if the experiment needs them.

## How
<!-- What a reviewer needs: an ASCII sketch of the moving parts, key types or signatures,
and the decisions they would question, each at the start of its line:
    D-26.1 <decision>, because <reason>. -->
```
specs/contracts/orders-api.yaml      ← changed only by a contract item (ship guard, FR-26.2)
item.md: contracts: orders-api       ← names it (FR-26.3)
approve: approved: <plan hash>,orders-api=<object id> <date> <who>   (FR-26.4)
item_phase: pin != plan hash + ids from `git ls-tree <base> specs/contracts/` → plan (FR-26.5)
```
D-26.1 Only a contract item changes contracts, like the constitution and amendments (Q-26.1).
D-26.2 A contract change sends dependent items back to planning, not a warning (Q-26.2).
D-26.3 The pin lives in the approval's first token, `<plan hash>,<name>=<id>,…`: no new field,
and a changed list or id voids it like a plan edit. Items without contracts keep today's token.
D-26.4 The base branch's copy is the truth (the team agreed it there); one `git ls-tree` per
command reads every contract's id, only for items with `contracts:`. Rows of such items are not
put in the facts cache (their phase depends on the base branch too).
D-26.5 sdd does not parse contracts: any format, a file or a folder (a split OpenAPI spec).
D-26.6 The `contract` type's gates: planned analyzed approved check built reviewed (check runs the
project's validators); no tasks gate.

## Security
<!-- Does this touch untrusted input, login or permissions, secrets or personal data, a new
dependency, files/network/shell, or CI/agent config? If not: "none: <why>". Otherwise, per risk:
what can go wrong → what we do (an FR with a test, a D line, or "accept: <why>").
    e.g. uploads are untrusted → FR-26.4 rejects non-images and files over 5 MB -->
Contract names come from item frontmatter and become paths → FR-26.3 accepts only
[A-Za-z0-9_-]+ (e.g. `../etc` refused). Contracts decide what both sides build → FR-26.2 lets only
a contract item, reviewed in full (FR-26.7), change them. No new dependency.

## Questions (optional)
<!-- Q-26.1 <question> → recommend: <answer>. Resolve before building. -->
Q-26.1 Who may change a contract? → recommend: only a contract item → decided: only a contract item (joexbayer, 2026-10-29)
Q-26.2 A contract changes after approval: what happens to items using it? → recommend: back to planning → decided: back to planning (joexbayer, 2026-10-29)

## Done when
<!-- DOD-26.1 <observable outcome>, e.g. "works against staging". -->
DOD-26.1 `sdd check` passes; t_contracts.sh proves FR-26.1 to FR-26.7.
DOD-26.2 In a scratch repo: ship a contract, approve a feature using it, ship a change to the
contract; the feature is back in planning naming it, and re-approves after merging main.

## Tasks (optional)
<!-- Small, ordered steps the builder does one at a time, each in one sitting, each with a test
of its own (so it can pass before the next task exists):
    - [ ] T-26.1 Page the orders query, FR-26.1 (files: src/orders.js; test: npm test -- orders; size: S)
Size each task `S`, `M` or `L` (none is M): consecutive S tasks go to one builder together, M and
L ones alone. Add `; expect: fail` for a test written first (it must fail), or
`; expect: fail "<text>"` (it must fail with that text in its output); without `test:` the
full check runs. `.sdd/bin/sdd task done T-26.1` ticks a task when its test passes. -->
- [x] T-26.1 Contract type and ship guard, FR-26.1, FR-26.2 (files: .sdd/core/templates/contract.md, .sdd/core/config, .sdd/core/lib/common.sh, .sdd/core/cmd/ship.sh, tests/t_contracts.sh; test: SRC=$PWD SH=dash dash tests/t_contracts.sh; size: M)
- [ ] T-26.2 Contract names and the approval pin, FR-26.3, FR-26.4, FR-26.5 (files: .sdd/core/lib/common.sh, .sdd/core/cmd/approve.sh, tests/t_contracts.sh; test: SRC=$PWD SH=dash dash tests/t_contracts.sh; size: L)
- [ ] T-26.3 Contracts in next and review, FR-26.6, FR-26.7 (files: .sdd/core/cmd/next.sh, .sdd/core/cmd/review.sh, tests/t_contracts.sh; test: SRC=$PWD SH=dash dash tests/t_contracts.sh; size: S)
- [ ] T-26.4 Help, README, design and sdd-dev notes (files: .sdd/core/cmd/help.sh, README.md, specs/design.md, .claude/skills/sdd-dev/SKILL.md; size: S)

## Built
<!-- Written by the agent at the end of the build, for the review: per requirement what
changed (file:line) and which test proves it; deviations from the plan and why; follow-ups. -->

## Review (optional)
<!-- The human's review notes: what to change, one per line. The agent works through them
and says under "## Built" what it changed for each. -->

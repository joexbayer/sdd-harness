---
id: 26
type: feature
title: Contracts
status: shipped
created: 2026-10-29
approved: 970829dd457a71231dd8661f81558c9d1dc20112 2026-10-29 joexbayer
shipped: 2026-10-29
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
- [x] T-26.2 Contract names and the approval pin, FR-26.3, FR-26.4, FR-26.5 (files: .sdd/core/lib/common.sh, .sdd/core/cmd/approve.sh, tests/t_contracts.sh; test: SRC=$PWD SH=dash dash tests/t_contracts.sh; size: L)
- [x] T-26.3 Contracts in next and review, FR-26.6, FR-26.7 (files: .sdd/core/cmd/next.sh, .sdd/core/cmd/review.sh, tests/t_contracts.sh; test: SRC=$PWD SH=dash dash tests/t_contracts.sh; size: S)
- [x] T-26.4 Help, README, design and sdd-dev notes (files: .sdd/core/cmd/help.sh, README.md, specs/design.md, .claude/skills/sdd-dev/SKILL.md; size: S)

## Built
<!-- Written by the agent at the end of the build, for the review: per requirement what
changed (file:line) and which test proves it; deviations from the plan and why; follow-ups. -->
Per requirement (tests: tests/t_contracts.sh, each block names its FR):
- FR-26.1 the `contract` type: .sdd/core/templates/contract.md (Why, Contract, Users,
  Compatibility, Security, Done when, Built, Review), prompts plan.contract.md and
  build.contract.md, gates in .sdd/core/config:90 (planned analyzed approved check built
  reviewed; no tasks). Test: t_contracts.sh:8.
- FR-26.2 the ship guard, in `constitution_guard` (.sdd/core/lib/common.sh:1586), so check and
  ship both apply it: a contract item with code outside specs/ is refused; any other item that
  changes specs/contracts/ (committed, unstaged, or a new untracked file) is refused. Tests:
  t_contracts.sh:18 and :36.
- FR-26.3 names: `contract_ids` (common.sh:374) resolves each `contracts:` name against one
  `git ls-tree <base> specs/contracts/` (`contract_tree`, common.sh:411, once per process), file
  extension removed, a folder by its tree id; a name not [A-Za-z0-9_-]+ is refused in approve and
  shown as the plan reason in next. Tests: t_contracts.sh:77 (`../etc`), :124 (folder).
- FR-26.4 the pin: `approval_pin` (common.sh:353) builds `<plan hash>,<name>=<id>,…`; approve
  (.sdd/core/cmd/approve.sh:18) refuses a contract missing on the base branch or a branch copy that
  differs, and writes the pin. Every former `${IR_APPROVED%% *}` = plan_hash comparison now goes
  through `approval_ok` (file) or `approval_current` (item_phase, IR_*), both via approval_pin.
  Items without contracts keep the bare hash. Tests: t_contracts.sh:85, :91, :109.
- FR-26.5 back to planning: item_phase (common.sh:731) names the changed contract (reason code
  `contract`) or says the contracts: list changed (`changed`); open items with contracts are never
  cached as fixed (item_facts, common.sh:1181), so ls/status see a base-branch change at once.
  Tests: t_contracts.sh:98 (next, status, ls --json), :117 (list change).
- FR-26.6 next (.sdd/core/cmd/next.sh:115) lists the contract paths in build. Test: t_contracts.sh:130.
- FR-26.7 review (.sdd/core/cmd/review.sh:102) prints a contract item's diff of specs/contracts/
  in full. Test: t_contracts.sh:136.

Small additions outside the task file lists (needed for the new reason code): run.sh treats
`contract` as the human's time (no role run); summary.sh shows its reason; next.sh shows the
analyze findings for it too. item_load reads type and contracts in one awk (no extra process), so
item_rows can fill CTREE before the `$(item_facts)` subshell: one ls-tree per command (D-26.4).

Deviations and choices:
- The contracts guard is inside `constitution_guard` rather than a new function: the three call
  sites (check, ship, ship into a PR) need both rules. No bootstrap exception (unlike the
  constitution): even the first contract must come through a contract item, as FR-26.2 says.
- A name matching two entries (orders-api.yaml and orders-api/) is refused as ambiguous.
- A contract deleted on the base branch after approval reads as "changed" (pin id `none`).
- The pin keeps the list order: reordering `contracts:` voids the approval like any list change.

Security pass (git diff main...HEAD): contract names come from frontmatter; they are validated
against [A-Za-z0-9_-]+ and only compared with `git ls-tree` output, never used to build a path or
a command; awk gets them through ENVIRON. The ship guard runs in every profile, for every type
including spike and roadmap. No new dependency, no network.

Checks: DOD-26.1 `sdd check` passes. DOD-26.2 in a scratch repo
(/tmp/scratch/d127334b-7fb0-4ca9-b2ea-576d59c62d12/scratchpad/dod26): shipped contract orders-api, approved feature 2 with
`contracts: orders-api` (pin = main's blob id), shipped contract item 3 changing it; feature 2's
next said "Phase: plan (contract orders-api changed on main after approval; …)", approve refused
"specs/contracts/orders-api.yaml differs from main: merge main first", and after merging main it
re-approved and went back to build.

Follow-ups / for the human:
- `reviewed` gate: review_print leaves out specs/, so a contract item (like an amendment) has
  "no code diff" and skips the gate, though D-26.6 lists it. Making it count would mean including
  specs/contracts/ in review_print for contract items. Decide whether you want that.
- `contracts:` is not in `ls --json` or roadmap entries (out of scope, as planned).

Verified by: none (builder self-checked; the orchestrator verifies)

## Review (optional)
<!-- The human's review notes: what to change, one per line. The agent works through them
and says under "## Built" what it changed for each. -->

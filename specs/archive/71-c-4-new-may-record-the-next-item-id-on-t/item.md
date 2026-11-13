---
id: 71
type: amendment
title: C-4: new may record the next item id on the remote
status: shipped
created: 2026-11-11
approved: 2e19942ff80e839db248f1a30b8c11ee4e0f029b 2026-11-11 joexbayer
shipped: 2026-11-13
---
# 71 C-4: new may record the next item id on the remote

## Articles affected
C-4 (changed).

## Current text
C-4 Only new, approve and ship create commits. No verb pushes, except two human-only ones:
  `tidy --remote` deletes remote branches of items already shipped or dropped on the base, and
  `ship` with `forge = github` pushes its own item branch and merges that branch's PR. No verb
  pushes the base branch.
  Why: the human decides what lands and what leaves the machine; both run behind an ask rule,
  and the base changes only through a merge the human started.
  Enforced: check sh tests/constitution/c4-commits.sh

## Proposed text
C-4 Only new, approve and ship create commits. No verb pushes, except: `new` records the item
  id it takes in one ref on the remote (`refs/sdd/next-id`: a number, no branch, no file), and
  two human-only verbs: `tidy --remote` deletes remote branches of items already shipped or
  dropped on the base, and `ship` with `forge = github` pushes its own item branch and merges
  that branch's PR. No verb pushes the base branch.
  Why: the human decides what lands and what leaves the machine: the two that move work run
  behind an ask rule where the agent has one (Claude Code), the base changes only through a
  merge the human started, and an id is not work: two developers must never get the same one.
  Enforced: check sh tests/constitution/c4-commits.sh

## Why now
Review of 2026-11-11, reproduced: two developers each ran `sdd new` before pushing, both got id 1,
both shipped; the archive then held `1-ident-a` and `1-ident-b`, and `ls` and `show 1` showed only
one. Ids are chosen from what the clone has seen, so any two people who start work the same day
collide. C-3 says ids are never reused; nothing enforced it across clones. The owner chose
(2026-11-11) to reserve the id on the remote at `new`, which today's C-4 forbids.
The old Why also claimed both pushing verbs "run behind an ask rule": Codex gets no ask rules.

## Impact
- `.sdd/bin/sdd new fix "Item ids that cannot collide"` (item 72, open): `new` reads and
  compare-and-swaps `refs/sdd/next-id`; `tests/constitution/c4-commits.sh` allows that one push
  line, marked `# C-4: new (id)`. Until it ships the check stays stricter than the text.
- Here: `specs/design.md` §8 ("No verb pushes, except …") names the id ref too.
- SECURITY.md says Codex has no ask rules (in the docs chore that follows; outside specs/).

## Alternatives (optional)
- Fetch at `new` and refuse a duplicate at approve and ship: no push, but a collision found
  after building means renumbering by hand, and commits name the task ids. Rejected by the owner.
- Allow duplicates and show both: `FR-1.2` stays ambiguous forever and C-3 weakens. Rejected.
- One marker ref per id: also atomic, but grows without end and needs a cleanup rule.

## Built
- specs/constitution.md C-4: replaced with the Proposed text, word for word.
- specs/design.md §8: names `new` and `refs/sdd/next-id` (item 72) beside the two human verbs.
- Deviation: specs/design.md §7 (IDs) also rewritten: it described a team mode claiming
  `refs/sdd/ids/<n>` (one ref per id, a rejected alternative), contradicting the new C-4. Now: local
  counter, and with a remote one counter ref with compare-and-swap, no mode switch (item 72).
- `tests/constitution/c4-commits.sh` is unchanged and stricter than the new text (only the
  `tidy --remote` and forge `ship` lines may push); item 72 adds the `# C-4: new (id)` line.
- Security pass: docs only, no code changed; the verifier read the diff.
- Follow-ups for item 72: the ref holds the last id taken, which `next-id` names loosely;
  `cmd/tidy.sh:5` ("the one push C-4 allows"), the c4-commits.sh header and sdd-dev SKILL.md
  (push markers, "team IDs are a roadmap item") go stale when it ships.

Verified by: claude-opus-5-5: text matches the Proposed text, check articles pass; design.md §7 contradicted C-4 (fixed), "no file" wording may puzzle (a ref points at a blob holding the number), left for review

## Review (optional)

---
id: 3
type: feature
title: Constitution and amendments
status: open
created: 2026-10-26
approved: 0df87bfc46c19342ce9a9d22532a948fd7e519dd 2026-10-26 joexbayer
---
# 3 Constitution and amendments

## Why
Some rules are ground truths for a system ("the core needs only sh, git and awk") and should
be hard to change. Spec Kit has a constitution, but in private-project it grew to 748 lines that
were enforced only by prose: 52 rules were checked only at review, and amendments sat
"pending" for weeks (kb/spec-kit-failures.md). Our runs showed agents ignore prose and obey
gates (kb/narrow-lessons.md). So every article must be enforced, and changing one must be a
deliberate, visible act.

## What changes
US-3.1 As the owner of a system I write down its few ground truths once, so that every plan,
build and review is held to them.
FR-3.1 WHEN `specs/constitution.md` exists THE SYSTEM SHALL read each article as a line
`C-<n> <rule>`, followed by indented `Why:` and `Enforced:` lines. `Enforced:` is `review`
or `check <command>`. `sdd check` SHALL fail, naming the article, when either line is missing.
  e.g. `C-1 The core needs only sh, git and awk.` / `  Why: …` / `  Enforced: check sh tests/c1.sh`
FR-3.2 WHEN `sdd check` runs THE SYSTEM SHALL run every `Enforced: check` command after the
configured checks. A failure fails the check and names the article.
  e.g. `✗ C-1 The core needs only sh, git and awk. (its check failed)`
FR-3.3 WHEN the constitution has more than 30 articles THE SYSTEM SHALL fail `sdd check`
with "constitution over budget (31 of 30 articles)".
FR-3.4 WHEN `sdd next` prints plan or build instructions THE SYSTEM SHALL append the article
rules, one line each, without the Why.
FR-3.5 WHEN `sdd review` runs THE SYSTEM SHALL list every `Enforced: review` article under
"Constitution: confirm each", for the human to check against the change.
US-3.2 As the owner I change a ground truth only through an amendment, so that changes are
rare, reasoned and visible.
FR-3.6 WHEN an item branch changes `specs/constitution.md` as it exists on the base branch
and the item is not of type `amendment` THE SYSTEM SHALL fail `sdd check` and refuse
`sdd ship` in every profile, with "the constitution changes only through:
sdd new amendment \"…\"".
FR-3.7 WHEN an `amendment` item ships THE SYSTEM SHALL require the plan to be approved and its
Impact section filled in every profile, and refuse when the branch changes code outside
`specs/`. Code that must follow becomes its own items, listed under Impact.
FR-3.8 WHEN `sdd review` runs on an amendment THE SYSTEM SHALL show the constitution diff
against the base branch.

## Not in scope (optional)
A non-author approver for amendments in team mode (it comes with team mode), cooling periods,
and history stamping (the amendment item and the git log are the history).

## How
```
specs/constitution.md ──parse_articles (awk)──▶ C-n · rule · enforced
        │                                      ├─▶ check: run "check <cmd>" articles; budget; format
        │                                      ├─▶ next:  rule lines appended to plan/build prompts
        │                                      └─▶ review: "confirm each" list (review articles)
item branch diff ── touches constitution? ── type != amendment ─▶ check fails, ship refused
```
- `templates/amendment.md`: Articles affected · Current text · Proposed text · Why now ·
  Impact (code and items that must follow) · Alternatives · Built · Review.
- `core/config`: `[type "amendment"]` with `approved = block` and `built = block`, so every
  profile blocks; the Impact section is required (not optional).
- The constitution guard and the no-code rule live in `lib/common.sh` (`constitution_guard`),
  and both `check` and `ship` call it. When there is no `specs/constitution.md` on the base
  branch, any item may create it (the bootstrap case).
- This item creates this repo's own constitution with 3-5 articles, e.g. C-1 the core needs
  only sh, git and awk (jq only in sync/hook) [check]; C-2 state is derived from files and git,
  never stored [review]; C-3 IDs never change or get renumbered [review]; C-4 every verb passes
  under /bin/sh and dash [check].
D-3.1 Every article is enforced (check or review). Guidance without enforcement belongs in
specs/kb/, because unenforced rules are what decayed in private-project.
D-3.2 Article text is one line and carries the ID first, so `grep '^C-' specs/constitution.md`
lists the constitution (it fits item 2's grammar).
D-3.3 The weight of an amendment comes from always requiring approval, the Impact section, and
landing no code, not from extra waiting or ceremony.

## Questions (optional)
Q-3.1 Should `sdd init` create an empty constitution? → recommend: no; it appears when first
needed (principle 7), and `sdd help` says how to start one.

## Done when
DOD-3.1 `sdd check` passes, with a test naming each FR, under /bin/sh and dash.
DOD-3.2 This repo has `specs/constitution.md`. Editing it on a feature branch fails
`sdd check`, while the same edit on an amendment branch passes and ships.

## Built
<!-- Written by the agent at the end of the build, for the review: per requirement what
changed (file:line) and which test proves it; deviations from the plan and why; follow-ups. -->

## Review (optional)
<!-- The human's review notes: what to change, one per line. The agent works through them
and says under "## Built" what it changed for each. -->

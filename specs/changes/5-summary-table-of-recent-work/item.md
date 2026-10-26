---
id: 5
type: feature
title: Summary table of recent work
status: open
created: 2026-10-26
---
# 5 Summary table of recent work

## Why
A lead or a teammate wants one glance at what happened and what is waiting: what shipped
today or this week, what is in review, and what is stuck in planning, with who did it.
`sdd ls` (item 2) has the facts, but as one dense line per item. People paste this kind of
status into stand-ups, PRs and chat, so it must read well as a table.

## What changes
US-5.1 As a teammate I run one command to see recent work as a readable table, so that I
know what moved and what waits for whom.
FR-5.1 WHEN `sdd summary` runs THE SYSTEM SHALL print a boxed table with one row per item:
"item" (id and title, e.g. `3 (constitution and amendments)`), "state" (a short sentence
from the facts), "who" and "when", wrapping long cells inside their column.
  e.g. `│ 4 (AI driver) │ in review: check passed, Built written; waiting for you to ship │ joexbayer │ today │`
FR-5.2 WHEN no window is given THE SYSTEM SHALL show every open item plus the items shipped in
the last 7 days.
FR-5.3 WHEN `--since today|yesterday|<n>d|<YYYY-MM-DD>` or `--last <n>` is given THE SYSTEM
SHALL show only items active in that window, or the n most recently active ones. An item's
activity date is its shipped date, else the last commit on its branch.
  e.g. `sdd summary --since today`, `sdd summary --last 3`
FR-5.4 WHEN building the "state" cell THE SYSTEM SHALL use only facts: the phase and its
reason, open questions, tasks done/total, the check, and the approval, e.g. "planning: 2 open
questions", "building: no passing check yet", "shipped".
FR-5.5 WHEN building the "who" cell THE SYSTEM SHALL name who opened the item (author of its
open commit) and who approved it, when different, e.g. `kari, approved by joexbayer`; items on
teammates' remote branches are included, as in `ls`.
FR-5.6 WHEN `--mine` is given THE SYSTEM SHALL keep only items the current git user opened or
approved.
FR-5.7 WHEN `--md` is given THE SYSTEM SHALL print the same rows as a Markdown table, for PRs
and chat.

## Not in scope (optional)
Free-text highlights such as "its review found a bug" (that lives in the item's Built), team
servers, and colours.

## How
```
item_sources ─▶ item_row (phase, counts) ─┐
git log (open commit author, branch date) ├─▶ summary rows (TSV) ─▶ box | md renderer (awk)
frontmatter (approved, shipped)          ─┘        filtered by window / --mine
```
- `cmd/summary.sh` reuses `item_sources`, `item_row` and `parse_item` from item 2.
- Widths: columns fit the terminal (`COLUMNS`, else 100); the item and state columns wrap
  at word boundaries. Width is counted in characters, not bytes, so titles with å or é line
  up; the awk counts UTF-8 lead bytes only (`LC_ALL=C`), which works in every awk.
- Box drawing uses `┌─┬┐│├┼┤└┴┘`; `--ascii` uses `+-|` for terminals without UTF-8.
D-5.1 The "state" cell is derived, never typed in, because stored state drifts (C-2).
D-5.2 A separate verb rather than an `ls` flag, because `ls` is the machine-friendly list and
`summary` is for people; both read the same rows.

## Questions (optional)
Q-5.1 Name the verb `summary`, or `report`? → recommend: `summary`.
Q-5.2 Default window: open items plus shipped in the last 7 days, or today only? → recommend:
open + last 7 days.

## Done when
DOD-5.1 `sdd check` passes, with a test naming each FR, under /bin/sh and dash.
DOD-5.2 On this repo, `sdd summary --since today` shows items 1-5 in a table that lines up,
and `--md` pastes cleanly into a GitHub comment.

## Built
<!-- Written by the agent at the end of the build, for the review: per requirement what
changed (file:line) and which test proves it; deviations from the plan and why; follow-ups. -->

## Review (optional)
<!-- The human's review notes: what to change, one per line. The agent works through them
and says under "## Built" what it changed for each. -->

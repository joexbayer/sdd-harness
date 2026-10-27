---
id: 6
type: chore
title: README with workflow diagram
status: shipped
created: 2026-10-27
shipped: 2026-10-27
---
# 6 README with workflow diagram

## What and why
Rewrite the root README so a newcomer sees how a change moves (a Mermaid diagram of plan,
approve, build, review, ship and who does each), the commands, team use, the AI driver, the
constitution, `summary`, and how sdd compares with Spec Kit. Docs only, no behaviour change.
Also fix two stale bits of specs/design.md: the roadmap (item 5 became `summary`; the forge
moves to next; add narrow model roles) and the gate table (lite does require approval).

## Built
- README.md rewritten: diagram, change types with which need approval, install, commands,
  team use (with a `summary` example), AI driver, constitution, customise, Spec Kit table.
  Claims checked against the code: approval per type from `.sdd/core/config` (lite:
  approved = block; chore and hotfix have no approved gate), stop hook blocks once, `status`
  lists local branches, `ls`/`show`/`summary` read remote branches (`item_sources`).
- specs/design.md §6 gate table: approval blocks in lite too, except chore and hotfix.
- specs/design.md §16 roadmap: row 5 is `summary` (shipped); git forge and narrow model
  roles are next rows.
- Not verified: the Mermaid diagram renders on GitHub (no local renderer; the syntax is
  plain flowchart). Check it on the branch page.
changed (file:line) and which test proves it; deviations from the plan and why; follow-ups. -->

## Review (optional)
<!-- The human's review notes: what to change, one per line. The agent works through them
and says under "## Built" what it changed for each. -->

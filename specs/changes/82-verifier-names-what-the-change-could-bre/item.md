---
id: 82
type: chore
title: Verifier names what the change could break elsewhere
status: open
created: 2026-11-21
---
# 82 Verifier names what the change could break elsewhere

## What and why
The verifier proves each FR but is not asked what the change breaks outside the item. pstack's `blast-radius` asks for the one fact a change is safe because of, proven by running something, with how far the proof got. One step in role-verifier.md, and specs/kb/pstack.md records this second look at pstack.

## Security
Standards: none
none: prompt and kb text only.

## Built
<!-- Written by the agent at the end of the build, for the review: per requirement what
changed (file:line) and which test proves it; deviations from the plan and why; follow-ups. -->

## Review (optional)
<!-- What to change, one per line (the agent writes what the human asks). The agent works through them
and says under "## Built" what it changed for each. -->

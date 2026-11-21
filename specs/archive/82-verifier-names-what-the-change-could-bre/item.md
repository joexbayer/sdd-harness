---
id: 82
type: chore
title: Verifier names what the change could break elsewhere
status: shipped
created: 2026-11-21
shipped: 2026-11-21
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
role-verifier.md:22-24: step 5, blast radius (the one fact that keeps the change safe outside the item, proven by running, with how far the proof got; unproven is a finding); later steps renumbered. specs/kb/pstack.md: second-pass notes. Test: t_prompts_tests.sh asserts the step; t_verified.sh still passes.
Deviations: none. Check passed (407 s; the budget warning is the machine load).

## Review (optional)
<!-- What to change, one per line (the agent writes what the human asks). The agent works through them
and says under "## Built" what it changed for each. -->

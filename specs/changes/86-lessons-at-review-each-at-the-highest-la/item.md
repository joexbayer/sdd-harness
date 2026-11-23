---
id: 86
type: chore
title: Lessons at review, each at the highest layer that holds it
status: open
created: 2026-11-23
---
# 86 Lessons at review, each at the highest layer that holds it

## What and why
The review step (prompts/review.md and the sdd-review skill) ends with 0-3 lessons from the item:
corrections the human gave, the verifier's must-fix findings, failed checks. Each goes to the highest
layer that holds it: code that makes the mistake impossible, else a check or test, else prose (a skill,
prompt, AGENTS.md). A mistake a prose rule already covered goes up a layer. The human picks; a code or
check lesson becomes a new item on their word, a prose one the agent writes in this branch (the check
runs again). Why: from pstack's correct/reflect and the "trust pyramid" talk; sdd has no retrospective.
Test: tests/t_prompts_tests.sh asserts the new lines in review.md and the skill.

## Security
none: prompt text only; lessons are applied only on the human's word.

## Built
<!-- Written by the agent at the end of the build, for the review: per requirement what
changed (file:line) and which test proves it; deviations from the plan and why; follow-ups. -->

## Review (optional)
<!-- What to change, one per line (the agent writes what the human asks). The agent works through them
and says under "## Built" what it changed for each. -->

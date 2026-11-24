---
id: 86
type: chore
title: Lessons at review, each at the highest layer that holds it
status: shipped
created: 2026-11-23
shipped: 2026-11-24
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
- .sdd/core/prompts/review.md: a bullet before "Only the human ships": 0-3 lessons, layer and file each,
  highest layer first, a covered prose rule goes up a layer, code/check → new item, prose → this branch
  then check again (ship's stale-verification warning is expected).
- .sdd/core/agents/skills/review.md: the same, shorter, with the same routing.
- Test: tests/t_prompts_tests.sh:121-129 asserts the phrases in the review step and the generated skill;
  removing the review.md bullet, the skill lines, or the skill's routing fails it.
- Verifier fixes: the skill left out where a chosen lesson goes, and no test covered the routing (both fixed);
  nit taken: the prompts say the stale-verification warning after a prose lesson is expected.
- Security: none (prompt text only).
- Verified by: claude-opus-5-5 at 0537abe: 0 of 0 FRs (chore: behaviour proven by mutation); should-fix: skill omits code/check→new item and prose→branch+check routing, and no test asserts that routing; nit: post-verify prose lesson triggers stale-verify warning

## Review (optional)
<!-- What to change, one per line (the agent writes what the human asks). The agent works through them
and says under "## Built" what it changed for each. -->

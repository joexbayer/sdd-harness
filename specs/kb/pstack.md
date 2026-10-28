---
type: research
status: active
review_by: 2027-01-28
trust: untrusted
sources:
  - https://github.com/cursor/plugins/tree/main/harness/pstack/claude-code (pstack v0.15.36, retrieved 2026-10-28)
  - https://cursor.com/lp-team/lauren (retrieved 2026-10-28)
  - https://github.com/unclebob/ub-mode (retrieved 2026-10-28)
---
# pstack (and ub-mode), compared with sdd

pstack (Lauren Tan, "poteto", MIT): 58 skills. A router skill (`poteto-mode`) picks one of 23
playbooks and copies its steps into a todo list; 24 one-principle skills; ~33 workflow skills;
2 agents; no hooks. Mechanisms: a plan linter (`check-plan.mjs`), a TSV work log, worktree audit,
PR watcher. Its README: "i don't believe in planning", so it covers sdd's build and verify half.
ub-mode (Uncle Bob): one SKILL.md, a reduced pstack plus his crapper, dryer and mutator tools.

Taken:
- `skills/tdd` step 4, a red test fails for the intended reason → item 22 FR-22.1.
- `skills/interrogate`, `playbooks/shipping.md` step 1, only a non-author's proven findings
  count → item 22 FR-22.2, FR-22.3 (verifier role, `verified` gate).
- `playbooks/shipping.md` step 3, review pinned by `git patch-id` → item 22 FR-22.4.
- `poteto-mode`, probe before asking → item 20 FR-20.5.
- ub-mode: attack the premise, behaviour tests, subtract before add → item 20.

Later: rules naming their enforcer (`skills/correct`, `principle-encode-lessons-in-structure`)
→ an amendment; "Depends on" must name something (`check-plan.mjs`) → multi-item plans;
`principle-explain-the-number` → the experiment's method.

Skipped: arena and swarm (N-way model fan-out, cost), the router (`sdd next` does it), the work
log (overlaps Built and runs.tsv), style skills, formal verification, Cursor- and TS-only tools.

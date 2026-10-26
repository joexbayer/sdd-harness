---
type: research
status: active
review_by: 2027-04-26
sources:
  - https://martinfowler.com/articles/exploring-gen-ai/sdd-3-tools.html (Böckeler, 2025-10-15)
  - https://www.thoughtworks.com/en-us/radar/techniques/spec-driven-development (2025-11-05)
  - https://github.com/Fission-AI/OpenSpec/blob/main/docs/concepts.md (retrieved 2026-10-26)
  - https://kiro.dev/docs/specs/ (retrieved 2026-10-26)
  - https://kiro.dev/docs/steering/ (retrieved 2026-10-26)
  - https://alistairmavin.com/ears/ (retrieved 2026-10-26)
  - https://github.com/open-gsd/gsd-core (retrieved 2026-10-26)
  - https://github.com/obra/superpowers (retrieved 2026-10-26)
  - https://github.com/bmad-code-org/BMAD-METHOD (retrieved 2026-10-26)
  - https://buildermethods.com/agent-os (retrieved 2026-10-26)
  - https://dev.to/tmfrisinger/spec-driven-development-is-the-prose-spec-drift-trap-reborn-4p99 (undated)
trust: untrusted
---
# Spec-driven development tools and their critics

## Tools
| tool | artifacts | lifecycle | what to take |
|---|---|---|---|
| Spec Kit | constitution, spec, plan, tasks, and more | per feature, spec-first | the extension/preset layering idea; not the weight |
| Kiro | requirements (EARS), design, tasks, steering files | per feature; Quick Spec skips gates | EARS; steering files with inclusion modes; bugfix spec = current / expected / unchanged |
| OpenSpec | living `specs/<domain>/spec.md`; change folders with proposal, design, tasks and delta specs | deltas (ADDED / MODIFIED / REMOVED) merged into the living spec at archive | the living spec plus archive lifecycle; "(Previously: …)" notes |
| GSD | STATE.md, CONTEXT.md; discuss → plan → execute → verify → ship | phases | a plan must fit a fresh context; a fresh subagent per task |
| superpowers | skills; 2–5 minute tasks with exact paths and verification | per task, TDD enforced | small changes agreed in chat; playback of understanding |
| BMAD | briefs, specs, architecture; personas | Clarify → Plan → Build → Learn | process scaled to size |
| Agent OS | standards discovered from code | standards, not a lifecycle | inject conventions by relevance |

## Strongest critiques, and our response
1. **Review burden.** Böckeler: "I'd rather review code than all these markdown files." The
   Radar calls the files lengthy and hard to review. → Budgets, and one short brief.
2. **One size fits nothing.** Kiro turned a small bug into 4 stories and 16 acceptance criteria.
   → Change types; tiny changes need no item.
3. **Waterfall and up-front design.** Adzic and Terhorst-North compare it to CASE/MDA. → Small
   slices; the item is editable while building.
4. **Prose drift.** Frisinger: "The prose spec is a claim about the code. The test is a receipt."
   → Every FR is named by a test (trace).
5. **Unreliable instruction following** with large contexts. → Small, targeted context per task.
6. **"Spec" used to mean "long prompt".** → Define what is durable (living spec, kb) and what is
   disposable (tasks).

## Notation
EARS sentences:

- ubiquitous: "The X shall Y"
- state: "While …"
- event: "When …"
- optional: "Where …"
- unwanted: "If … then …"

They are short, testable and grep-friendly. OpenSpec uses `### Requirement:` plus
`#### Scenario:` (WHEN/THEN) with RFC 2119 keywords.

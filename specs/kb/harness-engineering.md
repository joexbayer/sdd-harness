---
type: research
status: active
review_by: 2027-04-26
sources:
  - https://www.anthropic.com/engineering/effective-harnesses-for-long-running-agents (2025-11-26)
  - https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents (2025-09-29)
  - https://www.anthropic.com/engineering/building-effective-agents (2024-12-19)
  - https://www.anthropic.com/engineering/writing-tools-for-agents (2025-09-11)
  - https://www.anthropic.com/engineering/equipping-agents-for-the-real-world-with-agent-skills (2025-10-16)
  - https://www.anthropic.com/engineering/multi-agent-research-system (2025-06-13)
  - https://code.claude.com/docs/en/best-practices (retrieved 2026-10-26)
  - https://code.claude.com/docs/en/features-overview (retrieved 2026-10-26)
  - https://martinfowler.com/articles/exploring-gen-ai/harness-engineering.html (Böckeler, 2026-04-02)
  - https://martinfowler.com/articles/exploring-gen-ai/context-engineering-coding-agents.html (2026-02-05)
  - https://github.com/humanlayer/12-factor-agents (retrieved 2026-10-26)
  - https://github.com/humanlayer/advanced-context-engineering-for-coding-agents/blob/main/ace-fca.md (retrieved 2026-10-26)
  - https://arxiv.org/abs/2511.21654v1 (EvilGenie reward hacking)
  - https://arxiv.org/html/2501.12862v1 (Meta ACH mutation testing, FSE '25)
  - https://martin.kleppmann.com/2025/12/08/ai-formal-verification.html (2025-12-08)
  - https://sigops.org/2026/can-llms-model-real-world-systems-in-tla (2026)
trust: untrusted
---
# Harness engineering: what the sources agree on

## Principles
1. **Context is the scarce resource.** Aim for the smallest set of high-signal tokens. Notes
   should live outside the window, and subagents should return summaries.
2. **Long-running work.** An init script, a progress file, and a feature list (JSON) that starts
   all-failing; later sessions may only flip `passes`. One feature per session. Done means
   end-to-end tested.
3. **Guides and sensors (Böckeler).** Feedforward rules alone are never checked, and feedback
   alone repeats mistakes. Sensor messages should be written for the LLM to act on.
4. **Computational before inferential.** Tests, linters and types run on every change. LLM
   review is slower and non-deterministic, so it comes later.
5. **Gate the stop on a runnable check.** Ask for evidence, not assertions.
6. **Hard rules go in hooks and permissions.** CLAUDE.md, rules and skills are advisory.
7. **Keep AGENTS.md/CLAUDE.md short** (under 200 lines; one team reportedly runs about 100). It
   is a table of contents, not an encyclopedia.
8. **The repo is the system of record.** Decisions made in chat become versioned markdown.
9. **Research → plan → implement, compacting in between.** Review the plan, not the diff. Skip
   planning when the diff fits in one sentence.
10. **Own the control flow and state (12-factor).** Resumable steps, state as data.
11. **The simplest pattern that works.** Multi-agent runs cost about 15× and suit independent
    work, not most coding.
12. **Few, unambiguous tools with actionable errors.** Poka-yoke the arguments.
13. **Deterministic work belongs in scripts.** They are cheaper, more reliable, and their source
    is never loaded into context.
14. **Evolve the harness.** A CLAUDE.md line after the second miss, a skill after the third
    paste, a hook when something must happen every time.

## What goes where (Claude Code; similar elsewhere)
| primitive | use for | enforced? |
|---|---|---|
| AGENTS.md / CLAUDE.md | always-true, non-obvious rules; build and test commands | no |
| path-scoped rules | guidance per directory or language | no |
| skills | sometimes-needed procedures that need judgment | no (bundled scripts are deterministic) |
| subagents | context isolation; fresh-context review | tool limits are |
| hooks | must-happen-every-time: format after edit, stop gate, session-start context | yes |
| MCP | external systems and shared data | permissions |
| scripts | anything deterministic | yes |

## Verification ladder (cheapest first)
1. Types, linters and architecture-lint with teaching messages.
2. Test-first with the tests protected. EvilGenie and ImpossibleBench show agents editing or
   deleting tests; making tests read-only blocks this.
3. End-to-end smoke tests and browser checks.
4. A fresh-context adversarial reviewer. Tell it to flag only correctness and requirement gaps,
   or it will over-engineer.
5. Property-based tests for parsers, money and state machines (Go `rapid`, JS `fast-check`, Ruby
   `rantly`).
6. Mutation testing after integration. Meta's ACH had 73% of generated tests accepted.
7. TLA+/Alloy/P for concurrency cores only. LLM-written specs often pass TLC but stay generic.
8. Proof-checked code (Dafny, Lean, Verus) is research-grade for web teams.

## Anti-patterns
- Bloated instruction files.
- Guardrails as prose.
- Kitchen-sink sessions.
- Declaring victory without e2e tests.
- Markdown task lists the agent can rewrite.
- Self-grading.
- An unconstrained reviewer pushing abstractions.
- Overbuilding the setup up front.
- Tool sprawl.
- Frameworks that hide prompts.
- Unaudited skills.
- Assuming worktrees isolate DBs, ports or env (they don't).

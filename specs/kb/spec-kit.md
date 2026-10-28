---
type: research
status: active
review_by: 2027-01-28
trust: untrusted
sources:
  - https://easytool-me.pages.dev/blog/github-spec-kit-spec-driven-development-guide.html (retrieved 2026-10-28)
  - https://vibecoding.app/blog/spec-kit-review (retrieved 2026-10-28)
  - https://newreleases.io/project/github/github/spec-kit/release/v0.9.0 (retrieved 2026-10-28)
---
# GitHub Spec Kit, compared with sdd

What it is: the `specify` CLI (Python, installed with uv) plus templates; `specify init`
installs `speckit`-prefixed slash commands or skills for 30+ agents: constitution, specify,
clarify, plan, tasks, analyze, implement, checklist. Extensions and presets extend it.
Version numbers disagree between sources (0.11 in June 2026, a 1.0 reported August 2026):
check the releases page before quoting one.

Fits sdd:
- `analyze`: cross-checks spec, plan and tasks before building → item 19 (mechanical checks).
- `clarify`: an ambiguity scan by category before planning ends → item 19 (plan prompt checklist).

Does not fit, or sdd has it already:
- presets and extensions: `.sdd/local/` overrides prompts and templates.
- `checklist` ("unit tests for requirements"): overlaps analyze plus the FR "e.g." rule.
- agent breadth: any agent that reads AGENTS.md can use sdd; adapters (claude, codex, narrow)
  add skills, hooks and headless runs. More adapters when a user needs one.

What sdd has that Spec Kit lacks: phases derived from git, approval voided by a plan edit, a
stop-hook finish gate, test-first task checks, check results tied to the exact code, ship
through a PR, model roles with token and cost logging.

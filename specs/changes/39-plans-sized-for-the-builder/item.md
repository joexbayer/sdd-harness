---
id: 39
type: feature
title: Plans sized for the builder
status: open
created: 2026-10-30
---
# 39 Plans sized for the builder

## Why
<!-- The problem in plain words: who hurts, and how. 2-4 lines. -->
Pilot 2 (2026-10-29): qwen built small tasks well but stalled on tasks bundling ~10 behaviours
(arm A: the HTTP server; arm C: the dispatcher, 16 of 18 tests). And two models filled in one
schema from the plan's prose differently (arm C: `tokens.token_hash` vs qwen's column name), with
no test pinning the names. Opus plans the same way whoever builds; the plan should fit the builder.

## What changes
<!-- User-visible behaviour. One requirement per entry, each with a concrete example:
    US-39.1 As a <role> I <action>, so that <outcome>.
    FR-39.1 WHEN <trigger> THE SYSTEM SHALL <response>.
      e.g. <input> → <output>
Start each entry at the beginning of its line, ID first. IDs never change; leave gaps. -->
FR-39.1 WHEN `[build] max-size` is set (S, M or L; default L) THE SYSTEM SHALL tell the planner in
the plan rules, and analyze SHALL flag each task above it.
  e.g. max-size S → plan rules contain "Every task is size S"; `- [ ] T-7.3 … (size: M)` → analyze: "T-7.3 is size M, above the builder's max-size S: split it"
FR-39.2 WHEN max-size is S THE SYSTEM SHALL say in the plan rules what S means for a small builder:
one module or behaviour group, at most about 3 FRs, a test it can run alone.
  e.g. plan rules contain "at most about 3 FRs"
FR-39.3 WHEN `next` gives plan rules THE SYSTEM SHALL say that names several tasks share (schema
tables and columns, routes, function signatures, file paths) are fixed in the plan and pinned by a
test in the task that first defines them.
  e.g. plan rules contain "pinned by a test"

## Not in scope (optional)
<!-- What this deliberately leaves out, and where it went. -->

## How
<!-- What a reviewer needs: an ASCII sketch of the moving parts, key types or signatures,
and the decisions they would question, each at the start of its line:
    D-39.1 <decision>, because <reason>. -->
D-39.1 A config key, not model detection: the project knows its builder; `[build] max-size` sits
next to `[build] batch`. Analyze's finding uses the analyzed gate as other plan findings do.
D-39.2 Size stays the planner's judgment (S/M/L); sdd only checks the label against the limit.

## Security
<!-- Does this touch untrusted input, login or permissions, secrets or personal data, a new
dependency, files/network/shell, or CI/agent config? If not: "none: <why>". Otherwise, per risk:
what can go wrong → what we do (an FR with a test, a D line, or "accept: <why>").
    e.g. uploads are untrusted → FR-39.4 rejects non-images and files over 5 MB -->
none: one config value (S, M or L, others warned and ignored) and prompt text.

## Questions (optional)
<!-- Q-39.1 <question> → recommend: <answer>. Resolve before building. -->

## Done when
<!-- DOD-39.1 <observable outcome>, e.g. "works against staging". -->
DOD-39.1 `sdd check` passes; t_analyze.sh and t_prompts_tests.sh prove FR-39.1 to FR-39.3.

## Tasks (optional)
<!-- Small, ordered steps the builder does one at a time, each in one sitting, each with a test
of its own (so it can pass before the next task exists):
    - [ ] T-39.1 Page the orders query, FR-39.1 (files: src/orders.js; test: npm test -- orders; size: S)
Size each task `S`, `M` or `L` (none is M): consecutive S tasks go to one builder together, M and
L ones alone. Add `; expect: fail` for a test written first (it must fail), or
`; expect: fail "<text>"` (it must fail with that text in its output); without `test:` the
full check runs. `.sdd/bin/sdd task done T-39.1` ticks a task when its test passes. -->
- [ ] T-39.1 max-size: the analyze finding and the plan rule, FR-39.1, FR-39.2 (files: .sdd/core/lib/common.sh, .sdd/core/cmd/next.sh, .sdd/core/prompts/plan.md, .sdd/core/config, tests/t_analyze.sh; test: SRC=$PWD SH=dash dash tests/t_analyze.sh; size: M)
- [ ] T-39.2 Shared names pinned by a test, FR-39.3 (files: .sdd/core/prompts/plan.md, tests/t_prompts_tests.sh; test: SRC=$PWD SH=dash dash tests/t_prompts_tests.sh; size: S)
- [ ] T-39.3 README, design, sdd-dev notes (files: README.md, specs/design.md, .claude/skills/sdd-dev/SKILL.md; size: S)

## Built
<!-- Written by the agent at the end of the build, for the review: per requirement what
changed (file:line) and which test proves it; deviations from the plan and why; follow-ups. -->

## Review (optional)
<!-- The human's review notes: what to change, one per line. The agent works through them
and says under "## Built" what it changed for each. -->

---
id: {{id}}
type: feature
title: {{title}}
status: open
created: {{date}}
---
# {{id}} {{title}}

## Why
<!-- The problem in plain words: who hurts, and how. 2-4 lines. -->

## What changes
<!-- User-visible behaviour. One requirement per entry, each with a concrete example:
    US-{{id}}.1 As a <role> I <action>, so that <outcome>.
    FR-{{id}}.1 WHEN <trigger> THE SYSTEM SHALL <response>.
      e.g. <input> → <output>
Start each entry at the beginning of its line, ID first. IDs never change; leave gaps. -->

## Not in scope (optional)
<!-- What this deliberately leaves out, and where it went. -->

## How
<!-- What a reviewer needs: an ASCII sketch of the moving parts, key types or signatures,
and the decisions they would question, each at the start of its line:
    D-{{id}}.1 <decision>, because <reason>. -->

## Security
<!-- Does this touch untrusted input, login or permissions, secrets or personal data, a new
dependency, files/network/shell, or CI/agent config? If not: "none: <why>". Otherwise, per risk:
what can go wrong → what we do (an FR with a test, a D line, or "accept: <why>").
    e.g. uploads are untrusted → FR-{{id}}.4 rejects non-images and files over 5 MB -->

## Questions (optional)
<!-- Q-{{id}}.1 <question> → recommend: <answer>. Resolve before building. -->

## Done when
<!-- DOD-{{id}}.1 <observable outcome>, e.g. "works against staging". -->

## Tasks (optional)
<!-- Small, ordered steps the builder does one at a time, each in one sitting, each with a test
of its own (so it can pass before the next task exists):
    - [ ] T-{{id}}.1 Page the orders query, FR-{{id}}.1 (files: src/orders.js; test: npm test -- orders)
Add `; expect: fail` for a test written first (it must fail); without `test:` the full check
runs. `{{cmd}} task done T-{{id}}.1` ticks a task when its test passes. -->

## Built
<!-- Written by the agent at the end of the build, for the review: per requirement what
changed (file:line) and which test proves it; deviations from the plan and why; follow-ups. -->

## Review (optional)
<!-- The human's review notes: what to change, one per line. The agent works through them
and says under "## Built" what it changed for each. -->

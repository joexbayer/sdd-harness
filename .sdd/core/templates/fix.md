---
id: {{id}}
type: fix
title: {{title}}
status: open
created: {{date}}
---
# {{id}} {{title}}

## Current behaviour
<!-- What happens now, and how to reproduce it. -->

## Expected behaviour
<!-- FR-{{id}}.1 WHEN <trigger> THE SYSTEM SHALL <response>.
  e.g. <input> → <output> -->

## Must not change
<!-- Behaviour that has to stay exactly as it is (so the fix breaks nothing else). -->

## Security
<!-- Does this touch untrusted input, login or permissions, secrets or personal data, a new
dependency, files/network/shell, or CI/agent config? If not: "none: <why>". Otherwise, per risk:
what can go wrong → what we do (an FR with a test, a D line, or "accept: <why>").
    e.g. uploads are untrusted → FR-{{id}}.4 rejects non-images and files over 5 MB -->

## Test
<!-- The regression test (name and file) that fails now and passes after the fix. -->

## Tasks
<!-- The failing test first, then the fix; each one task:
- [ ] T-{{id}}.1 Failing test for <the bug>, FR-{{id}}.1 (files: <test file>; test: <command>; expect: fail; size: S)
- [ ] T-{{id}}.2 Fix <the bug>, FR-{{id}}.1 (files: <code files>; test: <same command>; size: S) -->

## Built
<!-- Written by the agent at the end of the build, for the review: per requirement what
changed (file:line) and which test proves it; deviations from the plan and why; follow-ups. -->

## Review (optional)
<!-- What to change, one per line (the agent writes what the human asks). The agent works through them
and says under "## Built" what it changed for each. -->

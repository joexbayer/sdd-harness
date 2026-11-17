---
id: 74
type: chore
title: Docs match the code; CI on three systems
status: open
created: 2026-11-17
---
# 74 Docs match the code; CI on three systems

## What and why
Items 68-73 changed behaviour the docs still describe the old way (README, `specs/design.md`, SECURITY.md, the sdd-dev skill, AGENTS.md block), and nothing runs the suite but one Mac. Make the docs true; add CI on Ubuntu, macOS and Alpine (BusyBox) running `sdd check`; name jq as a prerequisite for agent hooks; drop this repo's ignored `mode = solo`. No behaviour change.

## Security
- CI config runs code from pull requests → trigger `push` and `pull_request` only (never `pull_request_target`), `permissions: contents: read`, no secrets, third-party actions pinned by commit SHA.
- New CI dependencies (actions/checkout, actions/setup-node, OS packages shellcheck, dash, jq, git) → official names only; accept: CI-only, not shipped to users.

## Built
<!-- Written by the agent at the end of the build, for the review: per requirement what
changed (file:line) and which test proves it; deviations from the plan and why; follow-ups. -->

## Review (optional)
<!-- What to change, one per line (the agent writes what the human asks). The agent works through them
and says under "## Built" what it changed for each. -->

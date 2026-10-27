---
id: 14
type: chore
title: Agent first: /sdd-new takes a plain request
status: open
created: 2026-10-27
---
# 14 Agent first: /sdd-new takes a plain request

## What and why
Make the agent the main way to use sdd: `/sdd-new <what you want>` picks the type and a title
from the request and confirms them in one line, and the README opens with that conversation
(the CLI moves to "what the agent runs"). The human asked for skills first (2026-10-27).

## Security
Touches agent config (the sdd-new skill text). Risk: wording that lets an agent start or skip
steps on its own → the skill still confirms with the human before `new`, and approve/ship stay
human-only (ask rules, unchanged). No input, dependency, secret or network change.

## Built
- `.sdd/core/agents/skills/new.md`: the description also triggers on `/sdd-new <what you want>`;
  step 2 picks the type and a short title from the request and proposes them in one line
  (`That's a feature: "…". Start it?`), asking first when the request is unclear. The
  human still says yes before `new` runs. Test: tests/t_agents.sh (the new trigger and wording).
- README.md: opens with the agent conversation; the CLI is "what the agent ran underneath"; the
  install step calls `sync` a once-per-developer step and says what it writes; the skills bullet
  explains `/sdd-new <request>`.
- This repo: `sdd sync claude` run (skills, hooks, ask rules; all kept out of git).
- Security pass: only the author looked (skill text and docs, no code path). The change keeps
  the confirmation before `new` and leaves the ask rules untouched.

Follow-ups:
- The PR body (item 10) starts with the item's frontmatter, which GitHub shows as text.
- `git push -q` still prints GitHub's "Create a pull request" hint during ship.

## Review (optional)
<!-- The human's review notes: what to change, one per line. The agent works through them
and says under "## Built" what it changed for each. -->

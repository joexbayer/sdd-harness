---
id: 52
type: roadmap
title: sdd-server: team coordination over MCP
status: shipped
created: 2026-11-01
approved: fe4deb379dd7c3d6b0b111f1c424ac4551e68b27 2026-11-01 joexbayer
shipped: 2026-11-01
---
# 52 sdd-server: team coordination over MCP

## Goal
sdd-server: a small, self-hostable MCP server (TypeScript, npm package `sdd-server`, no UI, no
database) that shows a team every open item across branches and repos: who, phase, tasks, what it
plans to touch, and which sdd version each branch runs. It exists because, without it, parallel
work collided in private-project: SPEC-023 was written blind to SPEC-022 (9 of 14 rows contradicted,
e6ca0a17b), SPEC-038 planned to rebuild SPEC-031 (3ed393c9c), migration and format numbers
collided in 8+ specs, 59 commits renumbered IDs, and 94 of 138 branches cut on 10-02 never landed.

Decided with the human (2026-11-01), for the items below:
- Q-52.1 Stack? → decided: TypeScript on Node, published to npm (`npx sdd-server@<version>`),
  lean: the official MCP SDK v2 (`@modelcontextprotocol/server` + `@modelcontextprotocol/node`),
  `engines` Node >=22, built with `tsc`, tested with `node:test` (joexbayer, 2026-11-01)
- Q-52.2 Where item facts come from? → decided: the sdd release bundled in the package runs
  `ls --json` / `show --json` on no-checkout clones; repo code never runs on the server (joexbayer, 2026-11-01)
- Q-52.3 First mode? → decided: HTTPS under the team's domain first; stdio later (joexbayer, 2026-11-01)
- Q-52.4 A `sdd` CLI client? → decided: not yet; agents use MCP (C-1 stays sh + git) (joexbayer, 2026-11-01)
- Q-52.5 Token scope? → decided: every token sees every repo, one server per team (joexbayer, 2026-11-01)
- Q-52.6 Versions and skills? → decided: scripts stay committed in each repo and are never served;
  the first slice reports each repo's and branch's sdd version and flags ones behind the base;
  skills as MCP prompts come later (joexbayer, 2026-11-01)
- Q-52.7 npm name for sdd itself? → decided: `@joexbayer/sdd` (joexbayer, 2026-11-01)

## Items
- R-52.1 feature: sdd-server first slice: `items`, `item`, `search` and sdd versions over HTTPS, on npm (core: id collisions and task files in `--json`)
- R-52.2 feature: `sdd overlaps` in the core: open items planning or changing the same files or shared folders
- R-52.3 feature: an `overlaps` tool on the server, and a plan-step hint when a team server is set (after: R-52.1, R-52.2)
- R-52.4 feature: a push webhook so the server fetches at once (after: R-52.1)
- R-52.5 feature: stdio mode for one local repo (`npx sdd-server stdio`) (after: R-52.1)
- R-52.6 feature: the `/sdd-*` skills as MCP prompts, matching each repo's sdd version (after: R-52.1)
- R-52.7 feature: publish sdd itself to npm as `@joexbayer/sdd` (`npx @joexbayer/sdd@<version> init`)

## Done when
DOD-52.1 A team of two or more people on two or more repos connects Claude Code and Codex to an
sdd-server under its own domain, and each sees the others' open items, their phase, tasks and sdd
version, within a minute of a push.
DOD-52.2 Before planning, an agent can ask the server which open items touch the same files, and
the human hears about it in the plan discussion (R-52.3).
DOD-52.3 Installing or upgrading sdd uses a published release (R-52.7), never someone's checkout.

## Built
- Order: R-52.1 first because it is the smallest slice that works end to end for a team (hosted,
  several repos and people, on npm): private-project's one-host shortcuts cost ~380 commits of
  retrofits, so HTTPS and multi-repo come first, not later. R-52.2 (`sdd overlaps` in the core)
  needs no server and can go in parallel; R-52.3 puts it on the server once both exist. R-52.4
  (webhook), R-52.5 (stdio) and R-52.6 (skills as prompts) wait for their trigger: a 60 s fetch
  too slow, someone without a server, an agent without `sdd sync`. R-52.7 (sdd on npm) is
  independent; it removes the pilot's problem 10 at the root.
- The full plan draft for R-52.1 (requirements, tool shapes, deploy files, tasks, sources) was
  made by a planning subagent (Opus) and goes into R-52.1's item when it opens.

## Review (optional)
<!-- The human's review notes: what to change, one per line. The agent works through them
and says under "## Built" what it changed for each. -->

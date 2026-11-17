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
- Docs (README.md, specs/design.md, `.claude/skills/sdd-dev/SKILL.md`): design.md drops the `mode` row, profile default is `standard`, step 3 and the "later" row no longer say "team IDs", §7 already described `refs/sdd/next-id`, §10 says narrowbot's adapter lives in `.sdd/local/agents/` (item 73), §11 says ship runs its gates before the PR and IDs come from the remote ref, the `verified` gate row is `warn` in lite (config says so). README: prerequisites line, `profile standard`, `sdd --version`, `sdd help <verb>`. sdd-dev: `verified` is warn in lite/standard (was "off in lite"), `{{if <fact>}}` and `code = no`, `--version`/`help <verb>`, `task done` in order. Checked against the code and the `## Built` of items 68-73.
- SECURITY.md: no statement about Codex, ask rules or sandboxing exists; only "sdd doesn't sandbox agents", which is true. Unchanged. `codex.sh` prints "sdd sets no Codex approval rules yet", which matches.
- jq: README says it is needed only for agent hooks. Checked: `sync claude|codex` dies without jq (`need_jq`), hook replies are built with jq (`_hooks.sh`), `hook stop` reads its input with jq only when present, usage tracking (claude) uses jq; the forge uses gh's own `--jq`, not jq.
- `.sdd/config`: removed `mode = solo` (no `cfg` caller reads `sdd.mode`; the other keys are read).
- AGENTS.md: `sdd init` rewrote only the sdd-managed block (human-only list adds `tidy --remote`, two brevity/skill lines, new type list); kept. It also appended two lines to `.gitattributes` (`/.sdd/**`, `/specs/**` eol=lf); reverted: `* text=auto eol=lf` already covers them.
- CI `.github/workflows/check.yml`: triggers push (main) and pull_request, `contents: read`, no secrets, checkout and setup-node pinned to v4.4.0 commit SHAs (from `git ls-remote`; the tags are lightweight so the SHA is the commit). Jobs ubuntu and macos: install shellcheck dash jq, checkout fetch-depth 0, git identity, `cd server && npm ci`, `.sdd/bin/sdd check` (works on the detached PR checkout: tried in a detached clone). No `SDD_PERF`.
- Deviation: the Alpine job does not run `sdd check` end to end or install node. Alpine 3.20's nodejs is 20.x; the server tests need Node 22.18+ (run on the other two jobs). It runs the shellcheck line and `sh tests/run.sh /bin/sh dash` from `[check] run` directly; the shellcheck line is copied, so it drifts if `.sdd/config` changes it.
- Check: `.sdd/bin/sdd check` passed (317 s on a loaded machine, load ~14; the 150 s budget warning is load). Alpine via docker: not run; `docker pull alpine:3.20` hung with no output, so the workflow's Alpine steps are untested here (item 68 reported t_roles and t_run passing in Alpine 3.20).
- Left alone: the budget comment in `.sdd/config` and the sdd-dev skill say 150 s / ~2 min, which matches `budget = 150` in config (code default is 30; design.md says 30); no `150` mismatch found. design.md mentions `sdd explain` (§1, step 4) which does not exist (planned). design.md's gate table has a `trace` row and a `tasks` row that do not match core/config. design.md §3 type list lacks amendment, contract, roadmap. The sdd-dev narrowbot-eval section still names a personal path (`~/narrowbot-bench`).

## Review (optional)
<!-- What to change, one per line (the agent writes what the human asks). The agent works through them
and says under "## Built" what it changed for each. -->

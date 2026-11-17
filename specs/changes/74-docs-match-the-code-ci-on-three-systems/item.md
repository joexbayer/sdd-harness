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
- Alpine job: Alpine 3.20's Node is 20 (server tests need 22.18+, run on the other two jobs), so it runs every `[check] run` line from `.sdd/config` except the npm one, read with `git config` (no copy to drift). Not run here: `docker pull alpine:3.20` hung; the first PR run is its test.
- Review (orchestrator): design.md now matches core/config: no `sdd explain` (§1), all nine types (§3), per-type gates (§5), the gate table from the profiles (`trace`, "failing test first" and the strict-only trust row removed), §8 lists the verbs that exist and names what is not built. README's `git add` includes `.gitattributes` (init writes it). sdd-dev names no personal path. Action SHAs re-checked with `git ls-remote`.
- Check: `.sdd/bin/sdd check` passed after the last commit (see below).

Verified by: claude-opus-5-5: read the builder's diff against the code; design.md gates, types and verbs were still stale, the Alpine job duplicated the check lines, README missed .gitattributes: fixed

## Review (optional)
<!-- What to change, one per line (the agent writes what the human asks). The agent works through them
and says under "## Built" what it changed for each. -->

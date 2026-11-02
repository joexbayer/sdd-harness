# sdd

Spec-driven changes for people who work with coding agents. **You plan and review; the agent
builds.** One short file per change, plain POSIX shell, works with any agent.

```
you + agent ──plan──▶ you approve ──▶ agent builds (hands-off) ──▶ verifier ──▶ you review ──▶ you ship
               item.md        sdd approve          tests, sdd check       fresh model     /sdd-review   /sdd-ship
```

sdd enforces the workflow with commands, not prompts: building waits for your approval, editing
the plan cancels it, a test written first must fail before its task counts, a check passes only
for the exact code it ran on, and the agent can't stop with unfinished work.

## Quick start

```sh
curl -fsSL https://raw.githubusercontent.com/joexbayer/sdd-harness/main/install.sh | sh   # once
cd your-repo && git switch main
sdd init                    # copies .sdd/ into the repo, writes .sdd/config, adds a block to AGENTS.md
sdd sync claude             # skills and hooks for Claude Code (or: codex)
git add -A && git commit -m "chore: adopt sdd"
```

Then tell your agent what you want, or type `/sdd-new add CSV export`. Existing project or Spec
Kit repo: see [MIGRATE.md](MIGRATE.md). Upgrade: rerun the installer (`… | sh -s -- v0.2.0` for a
version), then `sdd init` in each repo. Uninstall: `rm -r ~/.local/bin/sdd ~/.local/share/sdd`.

## How a change moves

1. **Plan** (`/sdd-plan`): the agent asks the load-bearing questions first, then writes
   `specs/changes/<id>-<slug>/item.md`: requirements as `FR-n.1 WHEN … THE SYSTEM SHALL …` with an
   example, small tasks, decisions. It shows you a short review: sketch, critical parts,
   assumptions, testing.
2. **Approve**: you say yes; `sdd approve` pins the plan.
3. **Build** (`/sdd-build`): hands-off, task by task, each with its own test; a fresh verifier on
   a different model proves each requirement by breaking it.
4. **Review** (`/sdd-review`): in chat, one line per requirement. You never have to open a file.
5. **Ship** (`/sdd-ship`): gates, then merge (locally, or through a GitHub PR with
   `forge = github`).

## Commands

| | |
|---|---|
| `sdd new <type> "title"` | start a change (feature, fix, hotfix, refactor, chore, spike, amendment, contract, roadmap) |
| `sdd next` | what to do now (agents call this) |
| `sdd approve` · `sdd ship` | the human's two steps |
| `sdd check` | your tests and linters, plus secret scanning with gitleaks |
| `sdd review` | what was built, requirement by requirement |
| `sdd task [next \| done <T-id>]` | the tasks; `done` runs a task's test before ticking it |
| `sdd ls` · `sdd show <id>` · `sdd status` | items across all branches (`--json` for tools) |
| `sdd run <role> <id>` · `sdd usage` | run a role on its own model; tokens, cost, time |
| `sdd sync <agent>` · `sdd tidy` | per-developer glue; clean up shipped branches |

## Why it's small

Per feature, an agent reads about 1,800 words of sdd instructions and one ~700-word item file.
A typical Spec Kit setup is ~13,000 words of instructions and ~19,000 words of spec files.

## Make it yours

Everything is config (`.sdd/config`) or an override (`.sdd/local/<path>`, or
`<prompt>.append.md` to extend a prompt). Rules your project must keep go in
`specs/constitution.md`, each enforced by a check or by you at review. See [MIGRATE.md](MIGRATE.md).

## Teams

Items live on their own branches; `sdd ls` shows teammates' work in flight, `forge = github` ships
through pull requests, and [server/](server/) is a small self-hosted MCP server that shows every
open item across repos and branches (first version).

## More

- [specs/design.md](specs/design.md): the design and the reasons behind it.
- [specs/archive/](specs/archive/): every change to sdd itself, made with sdd.
- [specs/kb/](specs/kb/): the research behind the choices.

Develop: `.sdd/bin/sdd check` (shellcheck + the suite under sh and dash). One test:
`SRC=$PWD SH=dash dash tests/t_<name>.sh`. Notes: [.claude/skills/sdd-dev/SKILL.md](.claude/skills/sdd-dev/SKILL.md).

MIT licensed.

# sdd: design

Living design for `sdd`, a small spec-driven workflow for people working with coding
agents. It is simple by default and adds rigour for those who want it. Research behind
each decision is in `specs/kb/`. Changes to this design arrive as items under
`specs/changes/`.

## 1. Goals

- **One change, one short file.** A beginner learns four commands and one file.
- **Any agent.** Claude Code, Codex, Cursor, Copilot, opencode, Gemini/Antigravity, and plain
  humans. The contract is a shell command plus files in git.
- **Scripts, not skills.** Procedures are POSIX `sh` using git, grep and awk. Skills or
  prompts are used only where judgment is needed.
- **Gates are commands.** Anything that must hold is checked by a script, git hook or CI,
  never by prose.
- **Solo first, team ready.** The team layer adds collision-free IDs, review, and a
  read-only MCP server that shows in-flight work across branches and repos.
- **Keep humans learning.** Every rule explains itself (`sdd explain <topic>`), and the brief
  before code is written for people.

Non-goals: our own agent runtime, a web UI, a database as the source of truth, and
replacing the team's git host.

## 2. Principles

1. **Scripts decide, agents judge.** Prompts tell an agent which command to run next.
2. **One fact, one place.** Everything else refers to it by ID.
3. **Ceremony scales with the change type.** A typo fix needs no item at all.
4. **State comes from facts.** The phase of an item is computed from files and git. It is
   never stored, so it cannot drift. The only stored state is `status: open|shipped|dropped`.
5. **No pointer files.** The current item comes from the branch name or an explicit
   argument (spec-kit#4128).
6. **Budgets are lint errors, not guidelines.**
7. **Restrictions come from one `profile` setting. Capabilities switch on when first used.**

## 3. Concepts

| Concept | Meaning |
|---|---|
| item | one change: `specs/changes/<id>-<slug>/item.md` on branch `<type>/<id>-<slug>` |
| type | hotfix, fix, chore, refactor, spike, feature. Each has its own template and gates |
| phase | derived: describe → (approve) → build → (review) → ship |
| check | your test/lint commands. Passing them is the main gate |
| profile | lite (default), standard, strict. Sets how hard each gate is |
| mode | solo (default) or team. Decides where IDs come from and how approval works |

## 4. Layout

```
.sdd/                         machinery, committed, readable
  bin/sdd                     entry point; finds its own folder, so the folder can be renamed
  core/                       replaced on upgrade
    cmd/<verb>.sh             one script per verb
    lib/common.sh             helpers; NAME is defined here and only here
    templates/<type>.md       item scaffolds
    prompts/<phase>[.<type>].md   what `sdd next` tells the agent
    agents/<agent>.sh         sync + hook translation per agent
    config                    defaults (git-config format)
  local/                      overrides: same relative paths, win over core
  config                      project settings (git-config format)
  VERSION
specs/                        content; the only other folder sdd writes to
  changes/<id>-<slug>/        open items
  archive/<id>-<slug>/        shipped or dropped items
  kb/                         research, decisions, concepts, lessons
  design.md                   (this repo only) living design
AGENTS.md                     managed block: how to use sdd
```

Config is read with `git config -f`, so there is no parser to maintain. Lookup order is
project `.sdd/config`, then user `~/.config/sdd/config`, then `core/config`. Machine-local
state (ID counter, check results, synced agents) lives in `$(git rev-parse
--git-common-dir)/sdd/`, so all worktrees of a clone share it and nothing is committed.

## 5. Change types

| type | use when | template sections | default gates |
|---|---|---|---|
| hotfix | prod is broken | What is broken · Fix · Follow-up | check (description may come after) |
| fix | wrong behaviour | Current · Expected (FR) · Must not change · Test | described, check |
| chore | deps, config, CI | What and why | described, check |
| refactor | structure only | Goal · Invariants | described, check |
| spike | learning | Question · Timebox · Findings · Decision | described; only the item merges, never the code |
| feature | new behaviour | Why · What changes (US/FR + examples) · Not in scope · How · Questions · Done when | described, check (+ approve, tasks, trace in standard) |

Types live in config, so a team can add `migration` or `security-fix`. Changes under about
20 lines with no behaviour change need no item. A plain `chore:` commit is enough.

## 6. Lifecycle and gates

```
 sdd new ─▶ describe ─▶ [approve] ─▶ build ─▶ [review] ─▶ ship ─▶ archived
              │ sections      │ hash-pinned   │ check passes  │ fresh-context
              │ filled        │ (standard+)   │ on this tree  │ verifier (strict)
```

Each phase is computed from facts:

- **describe**: some required `##` section has no content (HTML guidance comments do not count).
- **build**: described, and no passing check exists for the current working-tree fingerprint.
- **ship**: a check passed for exactly this tree.

The fingerprint is the tree hash of the working tree including untracked files, taken with a
temporary index. Any edit after a passing check makes it stale. This is narrow's finish gate,
built on git state instead of edit counters.

| gate | lite | standard | strict |
|---|---|---|---|
| check passes before ship | block | block | block |
| item described before ship | warn | block | block |
| stop with unverified edits (agent hook) | warn | block once | block once |
| feature brief approved before build | – | you, content-hash pinned | non-author |
| failing test first (fix, feature tasks) | – | block | block |
| trace: every FR has a test naming it | – | warn | block |
| independent review | on request | on request | required for features |
| trust gate, env allowlist, role profiles | – | – | on |

"Block once" follows narrow: the first stop is refused with the reason. The second is allowed,
and the report carries `unverified:`. Honest reporting, no deadlock.

Exit codes for every verb: `0` ok, `1` failed or gate refused, `2` usage error, `3` ran but
proves nothing (zero tests, or unverified).

## 7. IDs

Item IDs are plain integers.

- **solo**: an atomic counter (`mkdir` lock) in the git common dir, never below the highest ID
  seen in branch names and `specs/`.
- **team**: claimed on the git remote by pushing a unique empty commit to `refs/sdd/ids/<n>`.
  A second claimant is rejected as non-fast-forward and retries with `n+1`. This works on any
  git host and needs no server.

IDs inside an item embed the item number. They never change, and gaps are fine
(spec-kit#4065).

| prefix | meaning |
|---|---|
| `US-57.1` | user story |
| `FR-57.2` | requirement. EARS sentence plus a concrete example |
| `D-57.1` | decision, with its reason |
| `Q-57.1` | open question, with a recommended answer |
| `T-57.4` | task (standard+) |
| `DOD-57.1` | observable definition of done |
| `L-12` | lesson (kb) |

`git grep -wF FR-57.2` finds the requirement, its tests and its commits. Commits use
Conventional Commits with the item as scope: `fix(57): … Refs: FR-57.2`.

## 8. Commands

| step | verbs |
|---|---|
| 1 lite | `init new status next check ship sync hook help` |
| 2 standard | `approve`, `task red/done`, `trace`, `run <role>`, `drop` |
| 3 team | team IDs, `ship` via PR, `sdd-server` (MCP), CI job |
| 4 knowledge | `kb search/links/add/accept`, `tidy`, `explain` |
| 5 strict | `trust`, env allowlist, role profiles, `upgrade` with checksums |

Every verb prints a few lines and ends with the next command to run. Only `new` and `ship`
create commits. No verb pushes, except `ship` in team PR mode.

## 9. Verification ladder

The type and profile decide how far down a change goes.

1. **Format, lint and types.** Part of the configured check.
2. **`sdd check`.** Zero tests ran counts as a failure (exit 3). A command masked with
   `|| true` is refused.
3. **Failing test first.** `task red` must fail before `task done` may pass. The test file's
   hash is pinned in between. Models do edit tests to pass (EvilGenie, ImpossibleBench).
4. **Trace.** Every FR is named by at least one test.
5. **Independent review.** A fresh context, ideally a different model or vendor, compares the
   item and the diff. It reports BLOCKER/WARN/NOTE with `file:line`. Only BLOCKERs go to
   refuters.
6. **Opt-in per FR.** `verify: pbt` (property-based), `verify: states` (a transition table
   with one test per row), and mutation testing nightly.
7. **`verify: model`.** TLA+/Quint/P, for concurrency cores only, and only with someone who can
   read the model.

## 10. Agents

```
 floor (any human, any agent with a shell)
   AGENTS.md managed block → ".sdd/bin/sdd next"
   .sdd/bin/sdd <verb>        sh + git + grep/awk (jq only for sync/hooks)
 optional, generated per developer by `sdd sync <agent>`, never committed:
   instruction stub   CLAUDE.md "@AGENTS.md" (Claude reads AGENTS.md only without CLAUDE.md)
   hooks              session-start → status as context · stop → finish gate
   subagents/skills   role definitions, where the agent supports them (step 2+)
 enforcement everyone hits: git hooks (opt-in) + CI running `sdd` gates
```

The hook contract is that the core `sdd hook <event>` returns ok, warn or block plus a
message. `agents/<agent>.sh` translates that into the agent's JSON. Claude Code and Codex
share the same shape (`decision: block` and `systemMessage`). Generated files go into
`.git/info/exclude`, so per-agent copies are never committed and cannot drift
(spec-kit#4563, #4888).

**Model routing.** The team assigns roles to tiers, and each developer maps tiers to their
own agent and model:

```
.sdd/config (team)                 ~/.config/sdd/config (each developer)
[role "builder"]  tier = medium    [tier "medium"] agent = claude  model = sonnet
[role "verifier"] tier = large     [tier "large"]  agent = codex   model = <id>
```

`sdd run verifier 57` renders the prompt. `agents/<agent>.sh` then builds the headless
command (`claude -p`, `codex exec`, `cursor-agent -p`, `copilot -p`, `opencode run`,
`gemini -p`/`agy -p`), normalising the model, sandbox and output flags.

## 11. Team mode and the MCP server

Team mode adds:

- remote-claimed IDs
- `ship` opens a PR whose body is the brief
- approval is a review by someone other than the author
- CI runs the gates, and nobody can skip them

**sdd-server** is a self-hostable coordination service with no UI.

```
 agents / humans ──MCP (Streamable HTTP, bearer token)──▶ sdd-server
                                                            │ git fetch every 60s
                                                            │ (+ optional push webhook)
                                                            ▼
                                     bare mirrors of each repo (read-only deploy key)
```

- **Read-only.** It never writes to git, and has no database. Git stays the only write path.
  If it is compromised, an attacker can read specs and nothing else.
- **Why it exists.** In plain git, items on unmerged branches are invisible to teammates. The
  server reads every branch with `git for-each-ref`, `git ls-tree`, `git show` and `git grep`.
- **Tools** (tools only; MCP prompt and resource support varies by agent):

| tool | returns |
|---|---|
| `items` | open items across all branches and repos: id, type, title, status, owner, branch, updated |
| `item` | an item's files from its branch |
| `search` | `git grep` over specs and kb on the default branch plus open item branches |
| `read` | a file at a ref |
| `trace` | where an ID appears: specs, code, tests, commit messages |
| `overlaps` | other open items touching the same files or requirement IDs |

- **Deploy.** One static Go binary (or container) plus a git-config-format config with
  listen address, repos, and token hashes. TLS comes from a reverse proxy (Caddy).
  `sdd-server stdio --repo .` serves a single local repo to MCP-only clients.
- **Clients.** The `sdd` CLI calls the same tools with `curl`.

## 12. Knowledge base

The kb is one markdown file per note in `specs/kb/`. It is reviewed in PRs and searched with
grep. The research (kb/kb-storage.md) found no evidence that a graph or vector store beats
files for curated team notes. Markdown is also the only option where every write shows up in
a diff, which is the main defence against memory poisoning.

```yaml
type: research | decision | concept | lesson
status: active | superseded
supersedes: [other-note]
review_by: 2027-04-26          # tidy flags it after this date
sources:
  - https://…  (retrieved 2026-10-26)
trust: untrusted | reviewed     # untrusted until a human has read it
```

Upgrade triggers:

- **grep misses hurt** (likely at a few thousand notes): add a derived, gitignored SQLite FTS5
  index.
- **FTS still misses**: add embeddings.
- **"What did we believe on date X" becomes a real question**: a temporal graph.

## 13. Security

Proportionate controls, ranked by likelihood × impact. Detail is in kb/security.md.

| threat | control | default |
|---|---|---|
| untrusted text (web, issues) hijacks an agent holding secrets | Rule of Two per role: researcher has web but no secrets/write; builder has write but no web; publishing is done by `ship`, not an agent | strict |
| poisoned research persists in the kb | source + `trust: untrusted`; strip invisible Unicode and HTML comments; fence untrusted notes in prompts; merge via review | step 4, always |
| a changed `.sdd/` runs on every agent action; headless runs skip the agent trust dialog | `sdd trust` content-hash gate per user | strict |
| secrets leak into specs/kb/logs/agents | gitleaks pre-commit + CI over `specs/`; env allowlist for spawned agents | gitleaks always, allowlist strict |
| destructive agent mistakes | branch protection; agents on branches; never default to skip-permission flags | always |
| supply chain | pinned version + checksums; upgrade only through a reviewed commit | step 5 |
| MCP abuse | server is read-only, bearer tokens, fixed-schema tools, no shell tool | always |

Not doing: injection classifiers, signing/SLSA, a VM per run, per-call approvals, MCP OAuth.
Prompt injection is unsolved. These controls limit the blast radius; they do not prevent a
hijack.

## 14. Customisation, upgrades, renaming

- Override any core file by placing it at the same path under `.sdd/local/`.
- Prompts can be extended with `<name>.append.md` instead of replaced (spec-kit#4065).
- `upgrade` (step 5) replaces `core/` only, and refuses if `core/` was hand-edited
  (spec-kit#3849).
- One implementation language for the CLI (spec-kit#4884). Windows is supported through WSL or
  Git Bash.
- **Renaming.** The name lives in `NAME` in `core/lib/common.sh`. Rename the `.sdd/` folder,
  `bin/sdd` and that variable. Paths and markers are derived.

## 15. Open questions

- Q-0.1 Approval in team mode: the host's PR review (GitHub/GitLab), or a signed `sdd approve`
  commit? Recommend PR review.
- Q-0.2 Living specs per capability (`specs/<capability>.md`, folded in at ship), in
  step 4 or later? Recommend later. The IDs already work without them.

## 16. Roadmap and dogfooding

Mindset: agile waterfall. Planning with the human carries the weight, building is mostly
automated behind gates, and every change leaves the code easy to change again.

| item | what | why now |
|---|---|---|
| 2 | `sdd ls` / `sdd show`, both with `--json`; spec grammar | Spec Kit's best trait is greppable progress; the app and MCP server read this |
| 3 | constitution + `amendment` type | ground truths that are hard to change, enforced, not prose |
| 4 | GitHub forge adapter (`core/forges/github.sh`, via `gh`), on automatically when `origin` is github.com and `gh` is logged in | `ship` pushes and opens a PR with the brief as body; PR and CI state in `status`/`ls`/`review`; in team mode the PR review is the approval |
| next | planning gates: clarify (an interactive discussion of the problem first, then questions one at a time with options grounded in the research and a recommendation; `Q-n.m … → decided:` written by the human; open questions block approve), research (decisions cite `kb/` notes), plan lint (FR examples, IDs, budget); levels per project in `[plan]` config | planning carries the weight, so the human's decisions and the evidence behind them are gates, not prose |
| next | contracts: `specs/contracts/<name>` (OpenAPI, JSON Schema, data model); a contract item lands only the contract; items name `Contract:` and approval pins its hash, so a contract change sends dependent open items back to planning | frontend and backend build in parallel against one agreed contract |
| next | tasks (`task red/done`) | Spec Kit parity |
| then | `sdd-server` (stdio, then HTTP with mirrors) | team coordination across branches and repos |
| then | fresh-context review for clean, easy-to-change code | ladder step 5 |

Dogfooding stages:
1. **This repo, now.** Every change goes plan → approve → build → review → ship through sdd,
   and narrow + qwen evaluate it (kb/narrow-lessons.md).
2. **Pilot.** After items 2-3, tasks and plan lint: new work in one real repo runs on sdd next
   to Spec Kit. Old specs are not migrated.
3. **Replace Spec Kit.** After the team layer: MCP server, team IDs, `ship` via PR, gates in CI.

Exit criteria for the pilot: about 10 items shipped, no gate had to be bypassed, reviews take
minutes, and the narrow + qwen evaluation stays green.

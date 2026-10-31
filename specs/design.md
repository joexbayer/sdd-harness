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
| constitution | `specs/constitution.md`: a system's ground truths, each an article `C-n` with a reason and its enforcement (a check command or human review); changed only by an amendment |

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
  constitution.md             ground truths (C-n), each enforced; changed only by amendments
  contracts/<name>[.<ext>|/]   interfaces items build against; changed only by contract items
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
| amendment | a ground truth must change | Articles affected · Current text · Proposed text · Why now · Impact · Alternatives | every gate blocks in every profile; lands no code (Impact lists the items that follow) |
| roadmap | a system in several items | Goal · Items (`R-` entries) · Done when | planned, analyzed, approved, built; only the item lands, like a spike |
| contract | an interface items build against changes | Why · Contract · Users · Compatibility · Security · Done when | planned, analyzed, approved, check, built, reviewed; lands no code; review shows the contract diff in full |
| feature | new behaviour | Why · What changes (US/FR + examples) · Not in scope · How · Questions · Done when | described, check (+ approve, tasks, trace in standard) |

**Constitution.** Articles are one line, ID first (`grep '^C-' specs/constitution.md`), with
indented `Why:` and `Enforced: review | check <command>` lines; at most 30 (`constitution.max-articles`).
`check` runs the check articles and fails on a malformed one; `next` appends the rules to plan
and build instructions; `review` lists the review articles for the human to confirm. Once the
constitution is on the base branch, a branch that changes it fails `check` and `ship` in every
profile unless it is an `amendment`. Unenforced guidance belongs in `kb/`, not here.

**Contracts** (item 26). `specs/contracts/<name>.<ext>` or `specs/contracts/<name>/` (any
format; sdd never parses it, D-26.5). Only a `contract` item changes them, from the first one on,
and a contract item changes nothing outside specs/ (`constitution_guard`, in `check` and `ship`).
An item lists `contracts: orders-api, billing` in its frontmatter (names `[A-Za-z0-9_-]+`).
`approve` refuses a contract missing on the base branch, or one whose copy on the branch differs,
and pins `approved: <plan hash>,orders-api=<git object id>,… <date> <who>` (items without
contracts keep the bare hash). The base branch's copy is the truth: one `git ls-tree <base>
specs/contracts/` per command, only for items with contracts, and a changed id or list puts the
item back in planning naming the contract (reason code `contract`); such rows are not cached.

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
| plan approved before build (not chore, hotfix) | you, content-hash pinned | you, content-hash pinned | non-author |
| failing test first (fix, feature tasks) | – | block | block |
| trace: every FR has a test naming it | – | warn | block |
| verifier ran: a `Verified by:` line under Built, not `none` (`verified`) | – | warn | block |
| code unchanged since the human's `sdd review` in this clone (`reviewed`) | warn | warn | block |
| every `depends:` ref has shipped (`depends`; not hotfix) | warn | block | block |
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
| `R-57.2` | roadmap entry: one item to open (roadmap items only) |
| `L-12` | lesson (kb) |

`git grep -wF FR-57.2` finds the requirement, its tests and its commits. Commits use
Conventional Commits with the item as scope: `fix(57): … Refs: FR-57.2`.

### Spec grammar

One fact per line, ID first, so `grep` alone answers the common questions and an app can
read specs without sdd. `sdd ls --json` and `sdd show <id> --json` give the same facts with
fixed keys; every other reader (the MCP server too) uses them instead of parsing markdown.

| fact | line | example grep |
|---|---|---|
| story | `US-<id>.<n> As a …` | `grep -h '^US-' specs/changes/*/item.md` |
| requirement | `FR-<id>.<n> WHEN … THE SYSTEM SHALL …`, continued on the next lines, then an `e.g.` line | `grep -c '^FR-41\.' specs/changes/41-*/item.md` |
| task | `- [ ] T-<id>.<n> <what>, FR-… (files: …; test: <command>; expect: fail; size: S\|M\|L; by: <role>)`; `[x]` once `task done` saw its test pass (`[X]` counts too); attributes optional (no size is M, no by: is the builder), any other attribute makes the task unreadable; `expect: fail "<text>"` counts the red run only when its output contains that text (a fixed string) | `grep -c '^- \[[xX]\] T-' specs/changes/*/item.md` |
| decision | `D-<id>.<n> … because …` | `git grep -n '^D-' specs/` |
| question | `Q-<id>.<n> … → recommend: …`; answered with `→ decided: …` | `grep '^Q-' … \| grep -v 'decided:'` |
| outcome | `DOD-<id>.<n> …` | |
| roadmap entry | `- R-<id>.<n> <type>: <title>`, optionally ` (after: R-<id>.<k>, …)` naming earlier entries only (D-24.1, so no cycles); `analyze` flags an unknown type, a bad `after:`, a duplicate and a roadmap with none | `grep '^- R-30\.' specs/archive/30-*/item.md` |
| contracts | frontmatter `contracts: orders-api, billing`: entries of `specs/contracts/` on the base branch, extension removed; outside the plan hash but pinned in the approval | `grep -l '^contracts:.*orders-api' specs/changes/*/item.md` |
| item order | frontmatter `roadmap: R-<id>.<n>` (set by `new --from`) and `depends: 31, R-30.1` (by `new --from` from `after:`, or by hand); outside the plan hash. A ref is met once that item, or the item opened from that entry, has shipped. An entry is not opened, open (item n) or shipped (item n), derived from the items (item rows sdd sees: local, remote-tracking, archive) | `grep -l '^depends:' specs/changes/*/item.md` |
| item state | frontmatter `status: open\|shipped\|dropped`; open items live on their branch, shipped ones in `specs/archive/` | `grep -l '^status: open' specs/*/*/item.md` |

A fact counts only at the start of a line and outside HTML comments, which is why template
guidance indents its examples. Facts are read from the plan part (above `## Built`).

The JSON contract. `ls --json` prints one object per line with `id` (number), `type`,
`status` (open, shipped, dropped), `phase` (plan, build, review, done, or `review?` when the
answer depends on a check run on another machine), `frs`, `tasks_done`, `tasks_total`,
`title`, `branch` (empty for archived items), `source` (archive, worktree, local,
remote or base: where the item was read), `questions_open`, `approved_by`, `opened_by` (author
of the item's open commit), `shipped` (date), `active` (shipped date, else the branch's last
commit, today with uncommitted edits) and `reason` (why the item is in its phase). `show <id> --json` prints the same fields plus the
arrays `stories`, `requirements` (with `example`), `tasks` (with `done`), `decisions`,
`questions` (with `decided`), `done_when` and `entries` (a roadmap's, with `type`, `title`,
`after`, `state`: not opened, open or shipped, and `item`), each element with `id` and `text`.
`ls --json` rows also carry `roadmap` and `depends` (the frontmatter, empty when none). The current
item is read from the working file, so uncommitted plan edits show. New keys may be added;
readers ignore keys they do not know.

## 8. Commands

| step | verbs |
|---|---|
| 1 lite | `init new status next check ship sync hook help`, `ls`, `show`, `summary`, `open`, `tidy`, `task`, `run`, `usage` |
| 2 standard | `approve`, `trace`, `drop` |
| 3 team | team IDs, `ship` via PR, `sdd-server` (MCP), CI job |
| 4 knowledge | `kb search/links/add/accept/tidy`, `explain` |
| 5 strict | `trust`, env allowlist, role profiles, `upgrade` with checksums |

Every verb prints a few lines and ends with the next command to run. Only `new`, `approve`
and `ship` create commits (constitution C-4). No verb pushes, except `tidy --remote` (deletes remote branches of shipped
items) and `ship` with `forge = github` (pushes its item branch, merges its PR); none pushes the base.

## 9. Verification ladder

The type and profile decide how far down a change goes.

1. **Format, lint and types.** Part of the configured check.
2. **`sdd check`.** Zero tests ran counts as a failure (exit 3). A command masked with
   `|| true` is refused. It says how long it took (recorded as `secs=` with the result) and
   warns, never fails, past `[check] budget` seconds (default 30, 0 off): the gate runs after
   every task, so slow tests (end-to-end, real hash cost) belong to their task's own test,
   marked and left out of `check.run` by the project's runner (D-35.1, kb/agent-testing.md).
   The plan, build and verifier prompts carry the test rules: assert the FR's example
   literally, no expected values taken from the code under test, a test that would fail if its
   FR were dropped (item 35).
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
   skills             one per step (<name>-new, -plan, -build, -review, -ship): thin, they
                      say "run sdd next / the verb and follow it", plus that agent's tool hints
   ask rules          (Claude Code) the human confirms approve and ship, even when an agent drives
   subagents          role definitions, where the agent supports them (step 2+)
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

Roles run as subagents where the agent has them: `sync claude` writes
`.claude/agents/sdd-<role>.md` (the tier's model; "run `sdd next` and do that step") for every
role on a Claude tier, and the `sdd-run` skill hands a role to its subagent. Other roles (a
coder model through narrow) run through `sdd run <role> <id>`: `agents/<agent>.sh` builds the
headless command (`claude -p`, `narrow --json` today; `codex exec`, `opencode run`, … later)
with only the tier's `args`. With usage tracking on (`[usage] track = true`; off by default), every run, either way, is one line in this clone's
`.git/sdd/runs.tsv` (tokens from the agent's final JSON, or summed from a subagent's transcript
by the SubagentStop hook), and `sdd usage` sums them per item, role and task.

Building ("now let's build", the `sdd-build` skill) is a loop the main agent runs, because only
an agent can spawn subagents (D-17.2): `sdd task next` prints the next batch, one builder
(the `sdd-builder` subagent, or `sdd run builder <id>`) works it, every task of it is ticked by
`task done` and one commit names them all, until no task is open; the first failure stops the
loop. A role run's builder does tasks only (D-28.1): `sdd run builder` refuses an item with no
open task, and the finish gate lets a builder under `SDD_RUN` stop once none is open, so the
finishing (check, security pass, verifier, Built) is the orchestrating session's. An adapter
may say an exit code is no failure (`agent_exit_note`): narrow's exit 3, "could not verify its
own work", is logged as 3 and warned about, since sdd's task tests and check decide (D-28.2).
After an accepted builder exit, `sdd run` runs `task done` for each batch task still open, in
plan order, stopping at the first failure: the tool ticks, not the model (D-31.1). It commits
nothing (C-4) and prints `ticked n of m · commit with: <kind>(<id>): <task ids> <what>` for the
orchestrator. A batch is the first open task, joined by the open `size: S` tasks right after it while it
is S too, up to `[build] batch` (3): the planner sizes tasks and the human approves them, sdd
only groups, so a batch is the same every run (D-17.1). A batch ends after an `expect: fail`
task, so the code that makes a test-first task pass is never in the same batch as that test.
A small model still writes both at once, so the test passes. Then, only if other files have
uncommitted changes, `task done` runs it again in `git worktree add --detach` of HEAD under
$TMPDIR with only the task's `files:` copied in, removed afterwards, and counts it red when it
fails there (for the plan's reason, if named): the human's tree is never stashed or reset
(D-31.2, D-31.3). Passing there too, or no other changes (the code already committed), is refused.
A task may say which role builds it (`by: planner`, item 36): small builders write hollow tests
but make a big model's red tests pass, so the planner can write the test that defines done. A
batch belongs to one role (task_batch ends it where `by:` changes); `sdd run <role>` on another
role's batch is refused and names whose turn it is, and the batch's own role gets what the
builder got before: the item file restored and the batch ticked (D-36.2). Every batch run gets
prompts/role-batch.md (write only these tasks' code and tests; sdd ticks, the orchestrator
commits; no `cd`) before the project's role-<role>.md (D-36.3).
The project knows its builder, so `[build] max-size` (S, M or L, default L; item 39, D-39.1)
says the largest task it takes. Below L, `next` renders the plan prompt's `{{max-size}}` line as a
rule to size every task for it (for S: one module or behaviour group, at most about 3 FRs, a test
it can run alone), and `plan_findings` flags each task above it, so analyze, next's plan step and
the analyzed gate all see it. Size stays the planner's label; sdd only compares (D-39.2). Any
other value warns and counts as L. The plan rules also fix names that several tasks share and
have the first task's test pin them: two builders filling in one schema from prose chose
different column names (pilot 2).

Verifying: once no task is open and the check passes, the finish steps hand the item to the
`verifier` role (its `sdd-verifier` subagent, `sdd run verifier <id>`, or a fresh subagent on
another model), whose prompt (`prompts/role-verifier.md`) is to prove each FR by running
something and report only findings, with the command and its output, never editing. Its result
goes under Built as `Verified by: <model>: <n> of <m> FRs proven; <findings>`, which the
`verified` gate asks for; it stops a forgotten step, not a forged line (the human reads it in
review, `sdd usage` shows whether a verifier ran). `sdd review` records the patch id of the
code diff from the merge base (`specs/` left out; for a contract item, which lands no code, its
`specs/contracts/` diff) in `.git/sdd/checks/<id>.reviewed`; the
`reviewed` gate compares it at ship and names the files changed since, and a rebase that keeps
the change keeps the id. The record is per clone: a teammate's review is the PR's (D-22.2).

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
review_by: 2027-04-26          # kb tidy flags it after this date
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
- Upgrading is rerunning `init` from the newer copy (item 45): it replaces `bin/` and `core/`
  only, and refuses while they have uncommitted changes (spec-kit#3849); the result is a diff the
  human reviews and commits. Checksums stay with step 5's `upgrade`.
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
automated behind gates, the human reviews what was built, and every change leaves the code easy
to change again. sdd is not aiming at an AI that runs unattended: a smaller builder model is
supported and needs more of the human's review.

| item | what | why now |
|---|---|---|
| 2 | `sdd ls` / `sdd show`, both with `--json`; spec grammar | Spec Kit's best trait is greppable progress; the app and MCP server read this |
| 3 | constitution + `amendment` type | ground truths that are hard to change, enforced, not prose |
| 4 | AI driver: one skill per step (`sdd-new`, `-plan`, `-build`, `-review`, `-ship`) installed by `sync`, and `ask` permission rules so the human confirms `approve` and `ship` | an AI drives sdd most of the time; the human's two decisions need the human's click |
| 5 | `sdd summary`: recent work as a table (item, state, who, when), `--md` for PRs and chat | a lead sees what moved and what waits for whom at a glance |
| 7 | git forge: `sdd open <id> [--worktree]` (any item, a teammate's too), ship deletes a branch whose commits are all on the base, `sdd tidy` removes what shipped items left, `tidy --remote` deletes their remote branches (C-4, item 8) | every git procedure an agent would otherwise improvise is a script, so it is correct every time |
| 10 | GitHub adapter, PR on ship: with `forge = github`, `ship` pushes the item branch and opens a PR (the item is its body), shipping again merges it with a merge commit when CI passes and the head is the checked commit; PR and CI state in `status`/`ls --pr`/`review`, asked only in the pr phase or with `--pr` (C-4, items 11, 27) | teams review and merge in PRs; on the free plan sdd's gates are the only ones |
| 12 | security in every phase: a `## Security` section (feature, fix, chore), plan and build rules, a security pass before Built, sensitive files in `review`, gitleaks in `init` (kb/security-practices.md) | agent-written code is often insecure; people decide the risks before agents build |
| 15 | tasks: `- [ ] T-n.m … (files; test; expect: fail)`, `sdd task done` runs a task's test and ticks it, `next` hands the builder one task, ship proves ticks by commits, the `tasks` gate (standard+) | plan big, build small: a small model does one checked step at a time |
| 16 | model roles + usage: `sdd run <role> <id> [task]` (planner on Opus via `claude -p`, builder on a coder model via narrow, reviewer fresh), each run logging tokens, cost, time and result; `sdd usage` reports per item, role and task | the experiment measures what each role costs and delivers |
| 17 | task batches: `size: S\|M\|L` on tasks, `sdd task next` groups consecutive small ones (`[build] batch`), `next` and `sdd run builder` show the batch, the `sdd-build` skill loops one builder per batch until no task is open; unknown task attributes are refused | "now let's build" works the whole item without a subagent per tiny task |
| 24 | multi-item plans: a `roadmap` type whose `R-` entries open items (`new --from`), `depends:` in an item's frontmatter, ready entries in `next`, entry states in `show`, what an item waits for in `next`/`status`/`ls`, and the `depends` ship gate | a complex system is many items in an order |
| later | team mode: PR review as plan approval (Q-0.1), team IDs | approval by someone other than the author |
| later | planning gates: clarify (an interactive discussion of the problem first, then questions one at a time with options grounded in the research and a recommendation; `Q-n.m … → decided:` written by the human; open questions block approve), research (decisions cite `kb/` notes), plan lint (FR examples, IDs, budget); levels per project in `[plan]` config | planning carries the weight, so the human's decisions and the evidence behind them are gates, not prose |
| 26 | contracts: `specs/contracts/<name>` (OpenAPI, JSON Schema, data model, any format); a `contract` item lands only the contract; items name `contracts:` and approval pins their ids, so a contract change sends dependent open items back to planning | frontend and backend build in parallel against one agreed contract |
| 30-40 | the experiment: a complex multi-phase app, Opus plans and a coder model builds tasks, a scripted human answers and approves, measured against an Opus-only baseline. Done 2026-10-30: Opus as builder shipped, qwen needs supervision (kb/experiment-results.md) | proves plan big, build small with numbers |
| then | `sdd-server` (stdio, then HTTP with mirrors) | team coordination across branches and repos |
| then | fresh-context review for clean, easy-to-change code | ladder step 5 |

Dogfooding stages:
1. **This repo, now.** Every change goes plan → approve → build → review → ship through sdd,
   and narrow + qwen evaluate it (kb/narrow-lessons.md).
2. **Pilot.** After items 2-3, tasks and plan lint: new work in one real repo runs on sdd next
   to Spec Kit. Old specs are not migrated.
3. **Replace Spec Kit.** After the team layer: MCP server, team IDs, `ship` via PR, gates in CI.

Exit criteria for the pilot, and for calling sdd done: a real repo other than this one ships
about 10 items through sdd, adapted to that codebase through config and `.sdd/local/`. No gate had
to be bypassed, reviews take minutes, and the human finds the problems at review rather than
after ship.

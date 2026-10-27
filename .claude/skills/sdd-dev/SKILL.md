---
name: sdd-dev
description: How to develop and test the sdd CLI in swe-harness (POSIX sh scripts in .sdd/). Use when editing anything under .sdd/bin, .sdd/core (cmd/, lib/, agents/, templates/, prompts/, config) or tests/, when adding a new sdd verb, agent adapter, change type or gate, when a test fails only under dash or only on macOS, or when hooks for Claude Code / Codex misbehave.
---

# Developing sdd

## Run
```sh
sh tests/run.sh               # macOS /bin/sh (bash 3.2 in POSIX mode)
dash tests/run.sh dash        # Linux-style /bin/sh; run both, failures differ
.sdd/bin/sdd check            # shellcheck -S warning + both suites (~50 s); this repo dogfoods sdd
```
Each `tests/t_*.sh` sources `tests/lib.sh`. That gives you a temporary dir `$T`, an isolated
`HOME` and git identity, `sdd` (the source copy; inside a repo it delegates to that repo's
vendored copy via `SDD_SH`), `new_repo`, `setcfg` (changes the config *and commits it*: ship
refuses a dirty tree), and `fill`.

## Where things go
- **A new verb:** `.sdd/core/cmd/<verb>.sh`. It is sourced by `bin/sdd`, and `"$@"` holds the
  args. Add it to `cmd/help.sh`.
- **Shared logic:** `.sdd/core/lib/common.sh`. `NAME` (the tool name) is defined only there.
  Use `$CMD`, `$DIRNAME` and `$SPECS` instead of literal `sdd` or `.sdd` in output.
- **A new agent:** `.sdd/core/agents/<agent>.sh` defining `agent_sync` and `agent_hook_reply`.
  Claude and Codex share `_hooks.sh` because their hook JSON is identical.
- **Agent skills:** step texts in `.sdd/core/agents/skills/<step>.md` (agent-neutral, thin:
  "run sdd next and follow it"), plus `<step>.<agent>.md` for one agent's tool hints;
  `install_skills` writes them on `sync`. Behaviour agents must follow goes in
  `core/prompts/`, not in skills: in headless runs agents loaded sdd-new but never sdd-plan,
  while `sdd next` output was always followed. Claude Code ask rules for approve/ship live in
  `ask_rules` in `agents/claude.sh`.
- **A new type:** add `templates/<type>.md`. A type exists when its template exists. Optional
  `[type "<t>"]` settings go in `core/config`.
- **Defaults** go in `core/config` (git-config format, read with `git config -f`). Lookup order
  is project, then user, then core.

## Gotchas
- POSIX sh only. No `local`, arrays, `[[`, `sed -i` or `echo -e`. Pass values into awk via
  `ENVIRON`, never `-v` (backslashes) or gsub replacement strings (`&`). See `render()` and
  `fm_set()`.
- In tests, `sdd` is a shell function, and POSIX sh may keep `VAR=x sdd …` assignments after a
  function returns (bash in POSIX mode does). Use `(export VAR=x; sdd …)` instead.
- A literal `done` as a value or case pattern trips shellcheck SC1010. Quote it: `'done'`.
- Tests that run things in parallel must not assume which job gets which id.
- `git config -f` edits in tests leave the tree dirty unless committed. Use `setcfg` before
  `ship`.
- The fingerprint uses a temporary copy of the index (`GIT_INDEX_FILE`) with `git add -A` and
  `git write-tree`. Never touch the real index.
- Hook commands are wrapped in `sh -c '…' # sdd-managed`. The tag is how `sync` replaces only
  its own entries. Stop output must be JSON for Codex.
- A check that writes into the tree (tests dumping files in the repo root) would pass for
  the pre-run fingerprint and then look stale. `run_check` fingerprints again after the run
  and `check` lists what changed (`CHECK_DIRTIED`). Exit 126/127 sets `CHECK_NOTRUN`, which
  is a config problem, not a test failure.
- Worktree paths: `git worktree list` prints real paths, so on macOS a test's `$T` (/var/…)
  shows up as /private/var/…. Compare with `$(cd "$T/app.1" && pwd -P)` or assert on a
  suffix. Use `main_root`, `worktree_of` and `worktree_path` (lib/common.sh), not `$ROOT`,
  which is the current worktree.
- Item files: the frontmatter must close with `---`. Without it `fm_set` adds nothing and
  `approve` fails with "could not commit". When rewriting an item with awk/head, keep line 7.
- A teammate clone in a test picks its id from what it can see: push the local item
  branches first, or both clones choose the same id (team IDs are a roadmap item).
- Pushes: `tests/constitution/c4-commits.sh` flags `git push` in code (quoted text and comments
  are dropped first, so messages telling the human what to run are fine). Allowed only on lines
  marked `# C-4: tidy --remote` (tidy.sh) and `# C-4: ship (forge)` (ship.sh).
- Tab-separated fields with empties (a PR with no review): never `IFS=<tab> read`, because tab
  is IFS whitespace and runs of tabs collapse, shifting later fields. Use `tsv <n> <line>`
  (lib/common.sh, `cut -f`) or awk -F '\t'.
- Forges: only `core/forges/<forge>.sh` calls `gh` (the C-4 check enforces it). Tests use a
  stub `gh` on PATH over a bare origin (tests/t_forge.sh); the PR jq lives in `FORGE_JQ` and
  can be tried offline with `jq -r ".[] | $FORGE_JQ" sample.json`.

## Evaluating sdd with a real agent (narrow + qwen)
Unit tests don't show whether a mid-size model can follow sdd. To find out, run narrow headless:
`~/narrowbot-bench/narrow-sdd.sh REPO OUT PROMPT_FILE`. It runs qwen3-coder-30b with
`project-check-command = .sdd/bin/sdd check`, isolated config, and the key from env or
`~/.config/narrow/api.key`. OUT gets `events.jsonl` (spec: narrow repo
`docs/design/json-events.md`), `rc` and `diff.patch`. diff.patch leaves out untracked files,
so inspect the repo itself.
- Use a fresh scratch repo per run (`git init`, `sdd init`, an item with an approved brief).
  Run one at a time, because the gateway is shared.
- Score against the real `sdd check` exit, not the model's summary. Track: rc, check events,
  whether it ran `sdd next`, which FR IDs appear in tests, whether `## Built` is written, and
  whether the plan above Built was edited.
- Lessons so far (2026-10-26): qwen never runs `sdd next` by itself. It follows the
  AGENTS.md block and the item's guidance comments, so essentials must live there or in a
  gate. In the human-role run (narrow's Claude session as the human), every prose-only rule
  (no code while planning, write Built, commit, name FRs in tests) was ignored. What worked
  was a gate, or a human note at review. Single runs lie (k≈5 per app to see ~10 pp). Judge results against design.md §1
  (learning, simple, pragmatic, no bloat), not just pass/fail.

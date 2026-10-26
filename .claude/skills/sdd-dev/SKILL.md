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
- **A new type:** add `templates/<type>.md`. A type exists when its template exists. Optional
  `[type "<t>"]` settings go in `core/config`.
- **Defaults** go in `core/config` (git-config format, read with `git config -f`). Lookup order
  is project, then user, then core.

## Gotchas
- POSIX sh only. No `local`, arrays, `[[`, `sed -i` or `echo -e`. Pass values into awk via
  `ENVIRON`, never `-v` (backslashes) or gsub replacement strings (`&`). See `render()` and
  `fm_set()`.
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

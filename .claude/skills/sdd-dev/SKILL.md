---
name: sdd-dev
description: How to develop and test the sdd CLI in swe-harness (POSIX sh scripts in .sdd/). Use when editing anything under .sdd/bin, .sdd/core (cmd/, lib/, agents/, templates/, prompts/, config) or tests/, when adding a new sdd verb, agent adapter, change type or gate, when a test fails only under dash or only on macOS, or when hooks for Claude Code / Codex misbehave.
---

# Developing sdd

## Run
```sh
sh tests/run.sh               # macOS /bin/sh (bash 3.2 in POSIX mode)
sh tests/run.sh dash          # Linux-style /bin/sh; run both, failures differ
sh tests/run.sh /bin/sh dash  # both at once (what the check runs)
SH=/bin/sh SRC=$PWD sh tests/t_x.sh   # one file
.sdd/bin/sdd check            # shellcheck -S warning + both suites (~2 min); this repo dogfoods sdd
```
run.sh starts every test file under every shell at once and prints results afterwards, per
shell in file order. `t_perf*.sh` (timing budgets on a generated 100-item repo) runs alone
after the rest; `SDD_PERF_SLACK=2` doubles its budgets on a slow machine, and
`SDD_PERF_SLACK=0.01` makes it fail on purpose so it prints every measured time.
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
- Tasks: `task_rows` field 8 is why sdd cannot read the line (empty when fine), field 9 the size
  (S|M|L, M by default), field 10 the `expect: fail "<text>"` text (field 6 is then plain
  `fail`, so `!= fail` checks keep working). next.sh splits a row by prefix stripping, not
  `tsv`: a new field goes last and next.sh must strip one more tab to reach it. A new task attribute must be added to `AWK_TASK`'s known keys (and its
  start-of-block list), or every task using it becomes unreadable (FR-17.5).
- Dogfooding a grammar change: this repo's own plan is parsed by the code being changed. Until
  the new parsing is in the working tree, `sdd next`/`task done` read the new attribute wrongly
  (item 17: `; size: M` became part of the test command). Build the parser task first, then run
  `task done` with the working-tree `.sdd/bin/sdd`.
- Role runs (item 21): `sdd run` exports `SDD_RUN` to its agent, and `human_only` (lib/common.sh)
  makes approve, ship and `tidy --remote` exit 2 while it is set. A builder running this repo's
  suite inherits it, so tests/lib.sh unsets it; a new human-only verb calls `human_only` before
  `need_repo`. Build prompt text that is only for the finisher (check, security pass, Built) goes
  in prompts/finish.md, which `next` skips while a task is open.
- A new gate: add it to `sdd.gates` in core/config as well as to each profile, because
  `gate_level` says off for any gate the type's list lacks. Types with their own `gates =`
  (hotfix, chore, spike) do not get it unless you add it there; amendment pins every gate to block.
- Ship gates from item 22: `verified` (a `Verified by:` line under Built, not `none`; off in
  lite) and `reviewed` (`sdd review` wrote `.git/sdd/checks/<id>.reviewed` with the patch id of
  the code diff, `review_print`; warn in lite). A test that ships in strict needs both: write
  the line into Built and run `sdd review` last. `setcfg` after the review is a code change
  (`.sdd/config` is outside specs/), so the gate then says the code changed since the review.
  Items with no code diff skip `reviewed`.
- Plan checks (item 19): `plan_findings` reads parse_item lines on stdin, so `next` feeds it
  `IR_FACTS` (no second read) and `analyze`/`approve` feed it `parse_item`. A new mechanical
  check goes there, and its message in tests/t_analyze.sh's exact expected output.
- Test fixtures: `fill` writes "Filled in by the test" on the line right after each heading. A
  fact you insert after the heading is followed by that text, which continues the fact (a task
  line then "cannot be read": its attributes no longer end it). End inserted facts with a blank
  line.
- sh has no local variables: lib helpers use short `_x` names (`_n`, `_f`, `_b`) and
  overwrite any caller's variable of that name. In `cmd/` scripts, keep values that must
  survive a helper call in descriptive names (`pr_num`, not `_n`); item 13 was `_n` clobbered
  by `check_articles`.

- bash 3.2 (macOS /bin/sh) fails to parse a `case … in x) …;; esac` inside `$( … )` when a
  pattern's `)` closes early (`syntax error near unexpected token ;;`); dash is fine. Use
  `[ … ] || …` inside command substitutions.
- Roadmaps (item 24): entries are parse_item facts of kind `r` (AWK_PARSE), split by
  `entry_row` (AWK_ENTRY); `shipped_roadmaps` reads them from the base branch (the working tree
  when on the base, so `next` there runs no git with no roadmap); `AWK_DEPS` over `item_rows`
  says whether a `depends:` ref has shipped and names it (`waits_for` sets WAITS). Everything
  that reads all item rows runs only when an item has `depends:` or a roadmap has shipped:
  keep it that way, `next`/`status` are on the git-count budget.

## Performance (item 18)
A git process costs ~9 ms and an awk ~2 ms on macOS; a 0.2 s budget is ~20 git calls. So:
- Config is read once per process (`cfg_load` in need_repo: `git config --list` per file into
  `CFG_TAB`); `cfg`, `cfg_all`, `cfg_every`, `cfg_mine`, `gate_level` look up in awk
  (`AWK_CFG`). A command that writes the config and then reads it must call `cfg_load` again.
- Item 23: one `git rev-parse` per command (bin/sdd's, reused by `find_repo` as `RP`; it also
  sets `GD`, the worktree's own git dir). Per-worktree caches in `GD`: `sdd-config` (CFG_TAB as
  a sourced file) and `sdd-plan` (one item's plan hash), each used only while strictly newer
  (`test -nt`) than its source files; `current_branch` reads `GD/HEAD` while `PWD = ROOT`.
  `rm -f .git/sdd-config .git/sdd-plan` changes nothing but speed. tests/t_gitcalls.sh counts
  git processes (a logging `git` first on PATH): hook stop ≤ 3, next and status ≤ 2. A new git
  call on those paths fails it on any machine, unlike t_perf. `$(func)` forks a subshell in
  dash: set a variable instead on hot paths.
- `item_phase` reads the item once (`item_read`, one awk) and leaves `IR_*` (title, approved,
  first open task, facts, …) for the command: use those instead of `fm_get`/`parse_item` again.
  `parse_item`, `task_rows`, `missing_sections` and `fm_get` still exist for other callers and
  share their grammar with `item_read` (`AWK_PARSE`, `AWK_TASK`), so change it there once.
- `ls`, `summary`, `status` go through `item_rows`: the facts an item file decides are cached in
  `.git/sdd/cache/facts.<hash of VERSION + common.sh + CMD + config>`, one line per
  `<blob>\t<origin>\t<path>`. Rows that consulted a check result (reason code check, built,
  ready) or the worktree are never cached. Branch, opened_by and active are read from git per
  ref. `rm -rf .git/sdd/cache` changes nothing but speed; tests/t_cache.sh poisons the cache to
  prove each input change misses. A new row field goes in `item_facts` (and the cache line
  width, 18 since item 24, in `AWK_CACHE`), then `item_read` (a frontmatter key: one more line
  in its printf and the `for _ln` skip list), `item_rows_finish`'s print and `row_json`. Row
  fields 18 roadmap, 19 depends; ls appends PR fields after the row ($20..$25), so a new row
  field shifts them in `row_json` and ls.sh.
- `t_perf.sh` is sensitive to machine load (other sessions running suites: load average 14 put
  `next` at 0.27 s and `ls` at 1.3 s with unchanged code). Before blaming a change, time old vs
  new in one generated repo: copy `.sdd/core` and `.sdd/bin` from a `git worktree add … main` and
  from the branch into the perf repo in turn, best of 7 each, interleaved.
- To check a refactor prints the same: run each command with the old and the new `.sdd/` in a
  copy of a repo and diff; mark `.sdd` files `git update-index --assume-unchanged` first, or the
  swapped copy itself shows up as a code change (hook stop, review).

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
- Role runs (`sdd run builder|verifier <id>`) in a scratch repo: set `[role "builder"] tier =
  small` (narrow, qwen3-coder-30b, `args = --profile local --yolo`) and `[role
  "verifier"] tier = big` (claude, claude-sonnet-5-5, `args = --allowedTools
  Bash(sh:*),Bash(.sdd/bin/sdd:*),Read,Grep,Glob`). Claude Code's auto-mode classifier refuses
  to start these runs ("Create Unsafe Agents"): the human runs them with `! cd <repo> && ...`.
  Each `sdd run builder` does one batch; loop with `;`, not `||`: narrow exits 3
  ("unverified") after a red batch though sdd's tick passed. Outputs: `.git/sdd/runs/<n>/`
  (`out` is narrow's JSON events: `jq -r 'select(.type=="tool_call") | .title'`).
- Lessons (2026-10-28, item 22 trial): qwen ignores the finish steps (security pass, verifier,
  Built) even when its prompt has them, so the orchestrator runs them; a red task batched with
  its code made qwen write both (fixed: a red task ends its batch); the Sonnet verifier found
  real bugs qwen's own tests missed (a test checking only the exit code, macOS `wc` padding).
- `sdd check` under load from other sessions (load average >10): t_perf's `hook stop` (~14
  processes, ~0.15 s idle) goes over 0.2 s. Compare against main with `SDD_PERF_SLACK=0.3` (it
  prints every time); if both match, rerun with `SDD_PERF_SLACK=1.5` and say so under Built.

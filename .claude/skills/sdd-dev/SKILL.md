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
.sdd/bin/sdd check            # shellcheck -S warning + both suites (~2 min loaded); this repo dogfoods sdd
```
run.sh runs one job per test file per shell, as many at once as there are CPUs (a mkdir-claim
queue, shells interleaved; `SDD_TEST_JOBS=n` overrides), and prints results afterwards, per
shell in file order. Starting all ~70 at once (before item 38) took 9 min against ~2 min capped:
the cost is process starts (system time is 2x user time on macOS), and they contend.
Before the jobs, run.sh builds one `new_repo` per shell and exports it as `SDD_TEMPLATE`;
`new_repo` copies it (`cp -R`, dropping the `.git/sdd-config` cache) instead of git init, sdd
init and two commits. A test run alone (no `SDD_TEMPLATE`) builds its repo as before. So a
change to what `new_repo` sets up needs no template rebuild: each run.sh builds it fresh. `t_perf*.sh` (timing budgets on a generated 100-item repo) runs only
with `SDD_PERF=1 sh tests/run.sh` (item 56: a busy machine failed the gate), alone after the rest; `SDD_PERF_SLACK=2` doubles its budgets on a slow machine, and
`SDD_PERF_SLACK=0.01` makes it fail on purpose so it prints every measured time.
Profile the suite (item 38): time each file alone with
`SRC=$PWD SH=dash dash tests/t_x.sh` and note `uptime` (the dev Mac is often loaded by other
sessions; numbers swing 2x). Per-line cost of one file: pipe `dash -x` through a timestamping
filter, e.g. `SRC=$PWD SH=dash dash -x tests/t_x.sh 2>&1 >/dev/null | perl -MTime::HiRes=time
-ne 'BEGIN{$|=1} $t=time; printf "%.3f %s", $t-$p, $l if defined $p; ($p,$l)=($t,$_)' | sort -rn
| head` (each line's time is until the next trace line). Most cost is sdd and git process starts;
a test-side `sdd` call goes through the source copy, which execs the repo's vendored copy (two
shell starts, two common.sh parses). Avoid fixtures built with one git commit per loop pass:
t_perf writes its 95 commits with one `git fast-import`.
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
- `run_check` times the `check.run` commands (`date +%s`, whole seconds) into `CHECK_SECS`,
  recorded as `secs=` in `.git/sdd/checks/<id>`; `cmd/check.sh` prints it and warns past
  `[check] budget` (item 35). This repo's own check takes ~2 min, so `.sdd/config` sets
  `[check] budget = 150` (item 38). Tests on timing assert the recorded number, not a
  fixed one: a loaded machine can tick a second over.
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
  `fail`, so `!= fail` checks keep working), field 11 `by:` (item 36; empty = the builder). next.sh splits a row by prefix stripping, not
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
  in prompts/finish.md, which `next` skips while a task is open. Item 28: a role-run builder does
  tasks only. `run.sh` refuses `run builder` when WHYCODE is not `task`, and hook stop lets a
  builder with `SDD_RUN` stop once no task is open (interactive builders are still held). An
  adapter's optional `agent_exit_note <rc>` turns an exit code into a warning (narrowbot: 3);
  run_log keeps the real rc. Item 31: after an accepted builder exit, run.sh runs `task done`
  (as a subprocess) for each batch task still open and prints `ticked n of m · commit with: …`;
  since item 36 that (and the item-file restore, item 34) is for whatever role owns the batch
  (`by:`), and run.sh refuses another role's run on it (usage_die, exit 2) before `run_slot`, so
  nothing is logged. A role run mid-build is therefore refused unless it owns the batch; a
  verifier runs once no task is open. Batch runs get prompts/role-batch.md appended.
  run.sh never commits (C-4, enforced by tests/constitution/c4-commits.sh, which fails on any
  `git commit` outside new/approve/ship). Tests with a builder run therefore tick: give the
  item enough tasks for later runs (t_run.sh), and use the narrowbot stub's `NARROWBOT_DO` for a fake
  builder that writes files.
- Red check (item 31, `red_without_code` in cmd/task.sh): an `expect: fail` test that passes,
  with uncommitted changes outside its `files:` (and the item file), is rerun in a detached
  worktree of HEAD under $TMPDIR with only those files copied; an EXIT trap removes it on a die.
  Exit 126/127 there counts as red (the same command ran in the tree, so the missing thing is the
  uncommitted code, e.g. `sh api.sh`). Its log is `.git/sdd/checks/<id>.<task>.red.log`.
- A new gate: add it to `sdd.gates` in core/config as well as to each profile, because
  `gate_level` says off for any gate the type's list lacks. Types with their own `gates =`
  (hotfix, chore, spike) do not get it unless you add it there; amendment pins every gate to block.
- Ship gates from item 22: `verified` (a `Verified by:` line under Built, not `none`; off in
  lite) and `reviewed` (`sdd review` wrote `.git/sdd/checks/<id>.reviewed` with the patch id of
  the code diff, `review_print`; warn in lite). A test that ships in strict needs both: write
  the line into Built and run `sdd review` last. `setcfg` after the review is a code change
  (`.sdd/config` is outside specs/), so the gate then says the code changed since the review.
  Items with no code diff skip `reviewed`. A contract item records its `specs/contracts/` diff
  instead (item 28), so its `reviewed` gate applies.
- Plan checks (item 19): `plan_findings` reads parse_item lines on stdin, so `next` feeds it
  `IR_FACTS` (no second read) and `analyze`/`approve` feed it `parse_item`. A new mechanical
  check goes there, and its message in tests/t_analyze.sh's exact expected output. A check that
  needs config reads it in the shell before the awk and passes it via ENVIRON (item 39:
  `max_size` sets `MAX_SIZE` once per run, warning on a bad value; cfg reads the cache, no git).
- Conditional prompt text: `render` replaces a line that is exactly `{{max-size}}` with
  `RENDER_SIZE`, or drops it when that is empty (next.sh sets it in the plan phase). Reuse the
  pattern for other config-dependent rules rather than echoing text after the prompt, so the
  rule sits where it belongs and a local/ prompt override can place or omit it.
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
- bash 3.2 (macOS /bin/sh) treats an apostrophe inside `"${var:-word}"` as opening a quote, so
  `"${hits:-✗ not in this item's changes}"` breaks the parse of the rest of the file (`syntax
  error near unexpected token (` many lines later); dash is fine. Put such text in a variable
  first: `none="… item's …"`, then `"${hits:-$none}"` (item 47).
- Roadmaps (item 24): entries are parse_item facts of kind `r` (AWK_PARSE), split by
  `entry_row` (AWK_ENTRY); `shipped_roadmaps` reads them from the base branch (the working tree
  when on the base, so `next` there runs no git with no roadmap); `AWK_DEPS` over `item_rows`
  says whether a `depends:` ref has shipped and names it (`waits_for` sets WAITS). Everything
  that reads all item rows runs only when an item has `depends:` or a roadmap has shipped:
  keep it that way, `next`/`status` are on the git-count budget.
- Contracts (item 26): `specs/contracts/<name>[.ext|/]` (`CONTRACTS`), named by an item's
  `contracts:` frontmatter (`IR_CONTRACTS`; item_load also sets `ILCONTRACTS`). Only a `contract`
  item changes them and it lands no code: both rules live in `constitution_guard` (check, ship).
  The approval token is `<plan hash>,<name>=<object id>,…` for items with contracts, the bare hash
  otherwise. Never compare `${IR_APPROVED%% *}` to `plan_hash` yourself: use `approval_ok` (from
  the file) or `approval_current` (item_phase, from IR_*), both via `approval_pin`, which sets
  APIN, PHASH and, from `contract_ids`, CROWS (`name\tid\tpath`), CPINS and CBAD (why it cannot
  pin). `contract_tree` reads `git ls-tree <base> specs/contracts/` once per process into CTREE;
  item_rows calls it in its loop before `$(item_facts)`, whose subshell would lose it. Open items
  with contracts are never cached as fixed (their phase follows the base branch). Items without
  contracts must stay at zero extra git calls (t_gitcalls). WHYCODE `contract` = a pinned contract
  changed (or cannot be pinned yet); run.sh treats it as the human's time. Tests: tests/t_contracts.sh
  (`uses` sets the frontmatter line, `ship_contract` ships a contract change from main).

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
  ref. Item 25: `item_sources` (one `ls-tree` per branch) is cached in `.git/sdd/cache/sources`,
  keyed on `cksum` of base + SPECS + one `for-each-ref` of all tips; the worktree row is spliced
  in live at the `worktree` marker line. Dependency state uses `dep_rows` (item_rows with
  `_IR_LIGHT=1`: no opened_by/active git calls), read once per process into `DEP_ROWS`. `rm -rf .git/sdd/cache` changes nothing but speed; tests/t_cache.sh poisons the cache to
  prove each input change misses. A new row field goes in `item_facts` (and the cache line
  width, 18 since item 24, in `AWK_CACHE`), then `item_read` (a frontmatter key: one more line
  in its printf and the `for _ln` skip list), `item_rows_finish`'s print and `row_json`. Row
  fields 18 roadmap, 19 depends; `ls --pr` appends PR fields after the row ($20..$25; item 27: no gh call without --pr, review asks only in the pr phase), so a new row
  field shifts them in `row_json` and ls.sh.
- `GIT_TRACE=1` misses git calls whose stderr is sent to `/dev/null` (most `ls-tree`s): count
  calls with t_gitcalls' logging `git` wrapper instead. To see every t_perf time, run it with
  `SDD_PERF_SLACK=0.001` (all over budget, so the report prints; slow, it retries each).
- `t_perf.sh` is sensitive to machine load (other sessions running suites: load average 14 put
  `next` at 0.27 s and `ls` at 1.3 s with unchanged code). Before blaming a change, time old vs
  new in one generated repo: copy `.sdd/core` and `.sdd/bin` from a `git worktree add … main` and
  from the branch into the perf repo in turn, best of 7 each, interleaved.
- To check a refactor prints the same: run each command with the old and the new `.sdd/` in a
  copy of a repo and diff; mark `.sdd` files `git update-index --assume-unchanged` first, or the
  swapped copy itself shows up as a code change (hook stop, review).

## Evaluating sdd with a real agent (narrowbot + qwen)
Unit tests don't show whether a mid-size model can follow sdd. To find out, run narrowbot headless:
`~/narrowbot-bench/narrow-sdd.sh REPO OUT PROMPT_FILE`. It runs qwen3-coder-30b with
`project-check-command = .sdd/bin/sdd check`, isolated config, and the key from env or
`~/.config/narrowbot/api.key`. OUT gets `events.jsonl` (spec: narrowbot repo
`docs/design/json-events.md`), `rc` and `diff.patch`. diff.patch leaves out untracked files,
so inspect the repo itself.
- Use a fresh scratch repo per run (`git init`, `sdd init`, an item with an approved brief).
  Run one at a time, because the gateway is shared.
- Score against the real `sdd check` exit, not the model's summary. Track: rc, check events,
  whether it ran `sdd next`, which FR IDs appear in tests, whether `## Built` is written, and
  whether the plan above Built was edited.
- Lessons so far (2026-10-26): qwen never runs `sdd next` by itself. It follows the
  AGENTS.md block and the item's guidance comments, so essentials must live there or in a
  gate. In the human-role run (narrowbot's Claude session as the human), every prose-only rule
  (no code while planning, write Built, commit, name FRs in tests) was ignored. What worked
  was a gate, or a human note at review. Single runs lie (k≈5 per app to see ~10 pp). Judge results against design.md §1
  (learning, simple, pragmatic, no bloat), not just pass/fail.
- Role runs (`sdd run builder|verifier <id>`) in a scratch repo: set `[role "builder"] tier =
  small` (narrowbot, qwen3-coder-30b, `args = --profile local --yolo`) and `[role
  "verifier"] tier = big` (claude, claude-sonnet-5-5, `args = --allowedTools
  Bash(sh:*),Bash(.sdd/bin/sdd:*),Read,Grep,Glob`). Claude Code's auto-mode classifier refuses
  to start these runs ("Create Unsafe Agents"): the human runs them with `! cd <repo> && ...`.
  Each `sdd run builder` does one batch. narrowbot exits 3 ("unverified") after a red batch though
  sdd's tick passed; since item 28 `sdd run` warns and exits 0 for it (runs.tsv still says 3). Outputs: `.git/sdd/runs/<n>/`
  (`out` is narrowbot's JSON events: `jq -r 'select(.type=="tool_call") | .title'`).
- Lessons (2026-10-28, item 22 trial): qwen ignores the finish steps (security pass, verifier,
  Built) even when its prompt has them, so the orchestrator runs them; a red task batched with
  its code made qwen write both (fixed: a red task ends its batch); the Sonnet verifier found
  real bugs qwen's own tests missed (a test checking only the exit code, macOS `wc` padding).
- `sdd check` under load from other sessions (load average >10): t_perf's `hook stop` (~14
  processes, ~0.15 s idle) goes over 0.2 s. Compare against main with `SDD_PERF_SLACK=0.3` (it
  prints every time); if both match, rerun with `SDD_PERF_SLACK=1.5` and say so under Built.

## The experiment harness (experiment/, item 30)
- `experiment/run.sh <A|B> [dir] [--dry]` drives one arm of roadmap 29 in a fresh repo; only the
  human starts a real run (`! sh experiment/run.sh B`). Test the driver for free with `--dry`
  (fake claude/narrowbot from `experiment/fake/`; `XP_FAKE_COST`, `XP_FAKE_REVISE`, `XP_FAKE_FAIL`
  exercise the caps, `XP_FAKE_LIMIT=<role>` a subscription usage-limit wait). Arm C (item 37) differs from A only in
  the planner's by: rule (`experiment/prompts/by-planner.md` vs `by-none.md`); the driver reads a
  batch's owner from `sdd task next` (`; by: <role>)` on the first `[ ]` line) and runs that role. Since item 32 an
  arm is one feature item planned whole (no roadmap); the usage-limit wording and reset parsing
  live in `experiment/lib/xp.py` (`LIMIT`, `limit_seconds`). `shellcheck -s sh experiment/run.sh` yourself: `sdd check` does not list it.
- Prove the hidden suite against the reference build:
  `python3 -m pytest -q -p no:cacheprovider experiment/acceptance --repo experiment/reference --summary <file>`.
  Change the brief, reference and suite together; every test must pass on the reference.
- `sdd run <role>` refuses every role while an item waits for approval (WHYCODE approval,
  changed, contract), so planner/human rounds are run by the driver with `claude -p` and logged
  into `.git/sdd/runs.tsv` in run_log's columns, so `sdd usage` still totals them.
- A run repo needs `.sdd/` committed on main before `sdd new`, or the item branch has no sdd.
- Tier names in a run repo are `xp-*`: a developer's own `[tier]` in ~/.config/sdd/config wins
  over the project's (tier_file), so common names like `small` could be silently replaced.
- narrowbot headless without `--yolo` denies every non-read-only shell command (`:exec` is `:ask`,
  and headless asks are refused: narrowbot lisp/security.lisp `permission-for`, runtime.go
  `AskPermission`). experiment/narrowbot/allow.lisp fixes it with `advice-add 'permission-for
  :around` from an init file (user-origin changes to sealed policy are allowed and survive
  `seal-verify`). Check without spending: put only allow.lisp in an empty dir as init.lisp, then
  `NARROWBOT_CONFIG_DIR=<dir> narrowbot --eval '(permission-for nil (command "bash") (hash :command
  "python3 -m pytest -q"))'` → `:allow` (`curl x` → `:ask`). Never --eval a config with the
  provider block: loading it makes narrowbot read the gateway key.

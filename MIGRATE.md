# Adopting sdd

One page. Pick your case, run the steps in order. `<sdd>` is a clean checkout of sdd on `main`.

## Every case

```sh
cd your-repo && git switch main          # install on the base branch: items branch from it
<sdd>/.sdd/bin/sdd init                  # copies .sdd/, writes .sdd/config, adds a block to AGENTS.md
.sdd/bin/sdd sync claude                 # skills (/sdd-new, /sdd-review, /sdd-ship …) and the stop hook
git add -A && git commit -m "chore: adopt sdd"
```

Then fix what `init` warned about:

- **Gate.** `init` uses `scripts/check.sh` or `make check` if you have one, else guesses from the
  language. Check `[check] run` in `.sdd/config` is your real gate. Slow gate? Move it to `code`
  and list your docs, so docs-only items skip it:

  ```ini
  [check]
  	run = gitleaks dir . --no-banner
  	code = scripts/check.sh
  	docs = *.md
  	docs = docs/*
  	budget = 200
  ```
- **Budget.** Set `[check] budget` to the seconds your gate really takes (0 turns the warning off).
- **Launcher ignored.** A `bin/` line in `.gitignore` also hides `.sdd/bin/`; make it `/bin/`.
- **Secret scan.** With gitleaks installed, `init` adds it to the gate and writes a `.gitleaks.toml`
  that skips agent worktrees (`.claude/worktrees/`). Fake keys in test fixtures: `gitleaks dir . -v`
  prints their fingerprints; check each is fake, then list them in `.gitleaksignore`.

## New project

Nothing else. Start with `/sdd-new` (or `.sdd/bin/sdd new feature "title"`).

## Existing repo, no spec tool

1. Do the steps above; your current tests are the gate.
2. Write down the rules you already live by as a constitution, in its own item:
   `/sdd-new` → amendment. Each article is a rule line, then `Why:` and `Enforced:`:

   ```
   C-1 Every HTTP handler checks the caller's role.
     Why: a missed check leaked tenant data (incident 2026-03).
     Enforced: review
   ```
   `Enforced: check <command>` makes `sdd check` run it. Keep it under 30 articles.
3. Don't backfill items for old work. sdd tracks changes from now on.

## Spec Kit repo

1. Do the steps above.
2. Remove Spec Kit: `.specify/`, its skills or commands (`.claude/skills/speckit-*`,
   `.claude/commands/speckit.*`) and its block in AGENTS.md or CLAUDE.md.
3. Move `.specify/memory/constitution.md` to `specs/constitution.md` and rewrite it as `C-n`
   articles (above) in an amendment item. Until then `check` warns that it has none.
4. Old `specs/NNN-*` folders stay as history. sdd's items go to `specs/changes/` and
   `specs/archive/`, numbered from 1; an old `FR-1.3` in those folders is not item 1's (review only
   counts the item's own changes).
5. Your agent now plans with `/sdd-plan`, builds with `/sdd-build`, and hands you `/sdd-review` and
   `/sdd-ship`. One `item.md` per change replaces spec, plan, tasks, research, checklist.

## Upgrading later

On `main`, between items, with a clean tree: `<sdd>/.sdd/bin/sdd init`. It replaces `.sdd/bin` and
`.sdd/core`, keeps your config and `.sdd/local/`, and stamps `.sdd/VERSION` with the source
commit. Review the diff, commit, then `sync` again. Never copy `.sdd/` by hand.

## Make it yours

Override any core file at the same path under `.sdd/local/`, or extend a prompt with
`<prompt>.append.md`, e.g. `.sdd/local/prompts/plan.append.md`:
`- A list endpoint gets a test that counts its queries.`

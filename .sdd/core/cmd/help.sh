# shellcheck shell=sh
# help: list the verbs.
cat <<EOF
$NAME: spec-driven changes. Humans plan and review; agents build.

  plan ──approve──▶ build (hands-off) ──▶ review ──ship──▶ archived

  $NAME init                        install into this repo (config, AGENTS.md block)
  $NAME new <type> "title" [--worktree]
                                   start a change: branch + specs/changes/<id>-<slug>/item.md
  $NAME new --from R-<id>.<n> [--worktree]
                                   open the item a shipped roadmap's entry describes
  $NAME status                      current item and phase, or open items on local branches
  $NAME next                        instructions for the current phase (agents call this)
  $NAME analyze [<id>]              the plan's gaps: FRs no task names, open questions, …
  $NAME approve                     the human hands the plan over to the agent (pins the plan)
  $NAME check                       run the configured checks (0 pass, 1 fail, 3 no tests ran)
  $NAME ls [--all] [--json]         every item and its progress (archive + all branches)
  $NAME show <id> [--json]          an item's stories, requirements, tasks, decisions, questions
                                   (a roadmap: its entries, not opened, open or shipped)
  $NAME task [next | done T-<id>.<n>]
                                   the item's tasks; next: the batch to build now; done runs a
                                   task's test and ticks it
  $NAME run <role> <id>             one step of an item on the role's agent and model, headless, logged
  $NAME usage [<id>] [--md]         tokens, cost and time of the logged runs, per item, role and task
  $NAME summary [--since <when>] [--last <n>] [--mine] [--md|--ascii]
                                   recent work as a table: item, state, who, when
  $NAME review                      walkthrough of what was built: commits, diff, FRs, check,
                                   verifier; remembers the code shown (ship: the reviewed gate)
  $NAME ship                        gates, archive the item, fast-forward the base branch locally
                                   (forge = github: push and open a PR; ship again merges it)
  $NAME open <id> [--worktree]      switch to an item's branch (teammates' too), or a worktree
  $NAME tidy [--remote] [--dry-run]
                                   clean up after shipped items: branches, worktrees, remotes
  $NAME sync <agent>                hooks for your agent ($(agents | paste -sd ' ' -)), never committed
  $NAME hook <event> --agent <a>    called by agent hooks

types: $(types | paste -sd ' ' -)
contracts: an item names them in its frontmatter (contracts: orders-api); only a contract item
           changes specs/contracts/, and a change sends the items using it back to planning
EOF

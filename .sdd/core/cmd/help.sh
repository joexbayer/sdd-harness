# shellcheck shell=sh
# help: list the verbs.
cat <<EOF
$NAME: spec-driven changes. Humans plan and review; agents build.

  plan ──approve──▶ build (hands-off) ──▶ review ──ship──▶ archived

  $NAME init                        install into this repo (config, AGENTS.md block)
  $NAME new <type> "title" [--worktree]
                                   start a change: branch + specs/changes/<id>-<slug>/item.md
  $NAME status                      current item and phase, or open items on local branches
  $NAME next                        instructions for the current phase (agents call this)
  $NAME approve                     the human hands the plan over to the agent (pins the plan)
  $NAME check                       run the configured checks (0 pass, 1 fail, 3 no tests ran)
  $NAME ls [--all] [--json]         every item and its progress (archive + all branches)
  $NAME show <id> [--json]          an item's stories, requirements, tasks, decisions, questions
  $NAME summary [--since <when>] [--last <n>] [--mine] [--md|--ascii]
                                   recent work as a table: item, state, who, when
  $NAME review                      walkthrough of what was built: commits, diff, FRs, check
  $NAME ship                        gates, archive the item, fast-forward the base branch locally
  $NAME open <id> [--worktree]      switch to an item's branch (teammates' too), or a worktree
  $NAME tidy [--remote] [--dry-run]
                                   clean up after shipped items: branches, worktrees, remotes
  $NAME sync <agent>                hooks for your agent ($(agents | paste -sd ' ' -)), never committed
  $NAME hook <event> --agent <a>    called by agent hooks

types: $(types | paste -sd ' ' -)
EOF

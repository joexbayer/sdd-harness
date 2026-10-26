# shellcheck shell=sh
# sync <agent>: install per-developer glue (hooks, instruction stubs). Generated files are
# listed in .git/info/exclude so they are never committed; new worktrees get them too.
[ $# -eq 1 ] || usage_die "usage: $NAME sync <agent>   (agents: $(agents | paste -sd ' ' -))"
need_repo
sync_agent "$1" || exit 1
grep -qxF "$1" "$ST/agents" 2>/dev/null || echo "$1" >>"$ST/agents"

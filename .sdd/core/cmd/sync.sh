# shellcheck shell=sh
# sync <agent>: install per-developer glue (hooks, instruction stubs). Generated files are
# listed in .git/info/exclude so they are never committed; new worktrees get them too.
[ $# -eq 1 ] || usage_die "usage: $NAME sync <agent>   (agents: $(agents | paste -sd ' ' -))"
need_repo
sync_agent "$1" || exit 1
grep -qxF "$1" "$ST/agents" 2>/dev/null || echo "$1" >>"$ST/agents"
# FR-66.4: macOS litter is never work; `exclude` anchors to the root, this must match everywhere.
_ex=$(git rev-parse --path-format=absolute --git-path info/exclude)
grep -qxF .DS_Store "$_ex" 2>/dev/null || printf '.DS_Store\n' >>"$_ex"

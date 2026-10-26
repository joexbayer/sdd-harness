#!/bin/sh
# C-1: POSIX sh, git and POSIX utilities only; jq only where agent hook JSON is unavoidable.
core=".sdd/bin/sdd .sdd/core/cmd/*.sh .sdd/core/lib/*.sh .sdd/core/agents/*.sh"
# shellcheck disable=SC2086 # the globs must expand
bad=$(grep -lw jq $core | grep -v -e '/cmd/hook\.sh$' -e '/cmd/sync\.sh$' -e '/agents/')
[ -z "$bad" ] || { echo "C-1: jq used outside hook, sync and agents: $bad"; exit 1; }
# shellcheck disable=SC2086
run=$(grep -nE '(^|[;&|(]|then|do)[[:space:]]*(python3?|perl|ruby|node)[[:space:]]' $core)
[ -z "$run" ] || { echo "C-1: runs another language: $run"; exit 1; }

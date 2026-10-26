#!/bin/sh
# C-1: the core needs only sh, git and awk; jq only where agent hook JSON is unavoidable.
bad=$(grep -lw jq .sdd/core/cmd/*.sh .sdd/core/lib/*.sh | grep -v -e '/cmd/hook\.sh$' -e '/cmd/sync\.sh$')
[ -z "$bad" ] || { echo "C-1: jq used outside hook/sync: $bad"; exit 1; }

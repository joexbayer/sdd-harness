#!/bin/sh
# C-4: only new, approve and ship create commits, and no verb pushes.
c=$(grep -lE 'git (commit|commit-tree)( |$)' .sdd/core/cmd/*.sh .sdd/core/lib/*.sh | sed 's|.*/||' | sort | paste -sd ' ' -)
[ "$c" = "approve.sh new.sh ship.sh" ] || { echo "C-4: commits made by: $c"; exit 1; }
p=$(grep -nE '^[[:space:]]*git push' .sdd/core/cmd/*.sh .sdd/core/lib/*.sh)
[ -z "$p" ] || { echo "C-4: a verb pushes: $p"; exit 1; }

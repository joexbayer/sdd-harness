#!/bin/sh
# C-4: only new, approve and ship create commits; no verb pushes, except tidy --remote.
c=$(grep -lE 'git (commit|commit-tree)( |$)' .sdd/core/cmd/*.sh .sdd/core/lib/*.sh | sed 's|.*/||' | sort | paste -sd ' ' -)
[ "$c" = "approve.sh new.sh ship.sh" ] || { echo "C-4: commits made by: $c"; exit 1; }
# Pushes in code (not comments, nor messages telling the human what to run): tidy deletes, nothing else.
p=$(grep -nE 'git push' .sdd/core/cmd/*.sh .sdd/core/lib/*.sh |
	grep -vE '^[^:]*:[0-9]+:[[:space:]]*#|(echo|say|warn|die|printf)[[:space:]].*git push' |
	grep -vE '^\.sdd/core/cmd/tidy\.sh:[0-9]+:.*git push .*--delete ')
[ -z "$p" ] || { echo "C-4: a verb pushes: $p"; exit 1; }

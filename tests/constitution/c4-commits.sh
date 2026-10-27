#!/bin/sh
# C-4: only new, approve and ship create commits; no verb pushes, except tidy --remote.
c=$(grep -lE 'git (commit|commit-tree)( |$)' .sdd/core/cmd/*.sh .sdd/core/lib/*.sh | sed 's|.*/||' | sort | paste -sd ' ' -)
[ "$c" = "approve.sh new.sh ship.sh" ] || { echo "C-4: commits made by: $c"; exit 1; }
# A push in code (quoted text and comments, such as messages telling the human what to run,
# are dropped first) is allowed only on tidy.sh's line marked "# C-4: tidy --remote".
p=$(grep -nE 'git push' .sdd/core/cmd/*.sh .sdd/core/lib/*.sh | awk '
	{
		line = $0; sub(/^[^:]*:[0-9]+:/, "", line); code = line
		gsub(/"[^"]*"/, "", code); gsub(/'\''[^'\'']*'\''/, "", code); sub(/#.*/, "", code)
		if (code !~ /git push/) next
		if ($0 ~ /^\.sdd\/core\/cmd\/tidy\.sh:/ && line ~ /# C-4: tidy --remote$/) next
		print
	}')
[ -z "$p" ] || { echo "C-4: a verb pushes: $p"; exit 1; }

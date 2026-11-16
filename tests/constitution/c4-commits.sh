#!/bin/sh
# C-4: only new, approve and ship create commits; no verb pushes, except new (its id counter ref),
# tidy --remote and ship with a forge; nothing but a forge file talks to the forge.
code=".sdd/core/cmd/*.sh .sdd/core/lib/*.sh .sdd/core/forges/*.sh"
# in_code <regex>: "file:line:text" lines where <regex> is in code, once quoted text and comments
# (such as messages telling the human what to run) are dropped.
in_code() {
	# shellcheck disable=SC2086
	grep -nE "$1" $code | R=$1 awk '{
		line = $0; sub(/^[^:]*:[0-9]+:/, "", line); c = line
		gsub(/"[^"]*"/, "", c); gsub(/'\''[^'\'']*'\''/, "", c); sub(/#.*/, "", c)
		if (c ~ ENVIRON["R"]) print }'
}
# Commits only in new, approve and ship (hints such as `git commit -m "..."` in a message are not code).
c=$(in_code 'git (commit|commit-tree)( |$)' | sed 's|:.*||; s|.*/||' | sort -u | paste -sd ' ' -)
[ "$c" = "approve.sh new.sh ship.sh" ] || { echo "C-4: commits made by: $c"; exit 1; }
# Pushes only on the lines marked "# C-4: new (id)" (common.sh), "# C-4: tidy --remote" (tidy.sh) or
# "# C-4: ship (forge)" (ship.sh).
p=$(in_code 'git push' | grep -vE '^\.sdd/core/lib/common\.sh:[0-9]+:.*git push .*\$_ref.*# C-4: new \(id\)$' |
	grep -vE '^\.sdd/core/cmd/tidy\.sh:[0-9]+:.*# C-4: tidy --remote$' |
	grep -vE '^\.sdd/core/cmd/ship\.sh:[0-9]+:.*git push .*"\$BRANCH".*# C-4: ship \(forge\)$')
[ -z "$p" ] || { echo "C-4: a verb pushes: $p"; exit 1; }
# The forge (which can merge) is reached only through core/forges/.
g=$(in_code '(^|[^[:alnum:]_.-])gh ' | grep -v '^\.sdd/core/forges/')
[ -z "$g" ] || { echo "C-4: gh called outside core/forges/: $g"; exit 1; }

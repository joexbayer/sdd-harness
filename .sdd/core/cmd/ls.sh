# shellcheck shell=sh
# ls [--all] [--json]: every item and how far along it is: shipped ones from the archive on
# the base branch, open ones from local and remote branches. --all adds dropped items.
all=
json=
for _a in "$@"; do
	case $_a in
	--all) all=1 ;;
	--json) json=1 ;;
	*) usage_die "usage: $NAME ls [--all] [--json]" ;;
	esac
done
need_repo

# Branches contribute open items only; shipped and dropped ones are read from the archive.
rows=$(item_sources | while IFS="$(printf '\t')" read -r o r p; do item_row "$o" "$r" "$p"; done |
	A=$all awk -F '\t' '($10 == "archive" || $3 == "open") && (ENVIRON["A"] != "" || $3 != "dropped")' |
	sort -t "$(printf '\t')" -k1,1n)

if [ -n "$json" ]; then
	[ -z "$rows" ] || printf '%s\n' "$rows" | awk -F '\t' "$AWK_JSON"'{ print "{" row_json() "}" }'
	exit 0
fi
if [ -z "$rows" ]; then
	echo "no items"
	echo "next    $CMD new <type> \"title\""
	exit 0
fi
printf '%s\n' "$rows" | awk -F '\t' '{
	t = ($7 > 0) ? $6 "/" $7 : "-"
	printf "%-4s %-9s %-8s %-8s FR %-3s T %-6s %s%s\n", $1, $2, $3, $4, $5, t, $8, ($9 == "" ? "" : "   " $9)
}'
echo "next    $CMD show <id>"

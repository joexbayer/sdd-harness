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

# Branches contribute open items (and items shipped into a PR) only; shipped and dropped ones are
# read from the archive.
rows=$(item_rows | A=$all awk -F '\t' '($10 == "archive" || $3 == "open" || $17 == "pr") && (ENVIRON["A"] != "" || $3 != "dropped")' |
	sort -t "$(printf '\t')" -k1,1n)

# With a forge, each item branch's newest PR joins its row as fields 20-25 (number, state,
# review, ci, url, words; see pr_table). One forge call for all items.
prs=
prwhy=
if forge_load; then
	prs=$(pr_table) || { prwhy=$prs && prs=; }
fi
if [ -n "$prs" ] && [ -n "$rows" ]; then
	rows=$(printf '%s\n' "$rows" | P=$prs awk -F '\t' '
		BEGIN { n = split(ENVIRON["P"], l, "\n")
			for (i = n; i >= 1; i--) { b = l[i]; sub(/\t.*/, "", b); r = l[i]; sub(/^[^\t]*\t/, "", r); pr[b] = r } }
		{ b = ($10 == "remote") ? substr($9, index($9, "/") + 1) : $9; print $0 ((b != "" && (b in pr)) ? "\t" pr[b] : "") }')
fi

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
	printf "%-4s %-9s %-8s %-8s FR %-3s T %-6s %s%s%s\n", $1, $2, $3, $4, $5, t, $8, ($9 == "" ? "" : "   " $9), ($25 == "" ? "" : " · " $25)
}'
[ -z "$prwhy" ] || echo "pr      state unknown: $prwhy"
echo "next    $CMD show <id>"

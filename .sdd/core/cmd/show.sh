# shellcheck shell=sh
# show <id> [--json]: one item's stories, requirements, tasks, decisions, questions and
# outcomes, read from its branch or the archive. Each fact starts with its ID.
id=
json=
for _a in "$@"; do
	case $_a in
	--json) json=1 ;;
	*[!0-9]* | '') usage_die "usage: $NAME show <id> [--json]" ;;
	*) id=$_a ;;
	esac
done
[ -n "$id" ] || usage_die "usage: $NAME show <id> [--json]"
need_repo

src=$(item_sources | while IFS="$(printf '\t')" read -r o r p; do
	[ "$(id_of "${p%/item.md}")" = "$id" ] && printf '%s\t%s\t%s\n' "$o" "$r" "$p"
done | head -n 1)
[ -n "$src" ] || die "no item $id (see: $CMD ls)"
o=$(printf '%s' "$src" | cut -f1)
r=$(printf '%s' "$src" | cut -f2)
p=$(printf '%s' "$src" | cut -f3)
row=$(item_row "$o" "$r" "$p")
item_load "$o" "$r" "$p"
facts=$(parse_item "$IFILE" "$ID")
[ -z "$ITMP" ] || rm -f "$ITMP"

if [ -n "$json" ]; then
	{ printf 'row\t%s\n' "$row"; [ -z "$facts" ] || printf '%s\n' "$facts"; } | awk -F '\t' "$AWK_ESC"'
	$1 == "row" {
		printf "{\"id\":%d,\"type\":\"%s\",\"status\":\"%s\",\"phase\":\"%s\",\"title\":\"%s\",\"branch\":\"%s\",\"source\":\"%s\"", $2, esc($3), esc($4), esc($5), esc($9), esc($10), esc($11)
		next
	}
	{ n[$1]++; e = "{\"id\":\"" esc($2) "\",\"text\":\"" esc($4) "\""
	  if ($1 == "fr" || $1 == "us") e = e ",\"example\":\"" esc($5) "\""
	  if ($1 == "task") e = e ",\"done\":" ($3 == "done" ? "true" : "false")
	  if ($1 == "q") e = e ",\"decided\":" ($3 == "decided" ? "true" : "false")
	  a[$1] = a[$1] (n[$1] > 1 ? "," : "") e "}" }
	END {
		split("us stories fr requirements task tasks d decisions q questions dod done_when", m, " ")
		for (i = 1; i < 12; i += 2) printf ",\"%s\":[%s]", m[i + 1], a[m[i]]
		print "}"
	}'
	exit 0
fi
printf '%s\n' "$row" | awk -F '\t' '{ printf "%s %s · %s · %s · %s%s\n", $1, $2, $8, $3, $4, ($9 == "" ? "" : " · " $9) }'
[ -z "$facts" ] || printf '%s\n' "$facts" | awk -F '\t' '{
	mark = ($1 == "task") ? ($3 == "done" ? "[x] " : "[ ] ") : ($1 == "q" ? "[" $3 "] " : "")
	printf "%-9s %s%s\n", $2, mark, $4
	if ($5 != "") printf "%-9s e.g. %s\n", "", $5
}'
echo "next    $CMD ls"

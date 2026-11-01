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

# The id from the folder name, as id_of has it (item_sources gives each id once).
src=$(item_sources | I=$id awk -F '\t' '{ d = $3; sub(/\/item\.md$/, "", d); sub(/.*\//, "", d); i = d; sub(/-.*/, "", i)
	if (i == ENVIRON["I"]) { print $1 "\t" $2 "\t" $3 "\t" $5; exit } }')
[ -n "$src" ] || die "no item $id (see: $CMD ls)"
o=$(tsv 1 "$src")
r=$(tsv 2 "$src")
p=$(tsv 3 "$src")
row=$(item_row "$o" "$r" "$p" "$(tsv 4 "$src")") && item_load "$o" "$r" "$p" || die "could not read item $id from $r"
facts=$(parse_item "$IFILE" "$ID")
[ -z "$ITMP" ] || rm -f "$ITMP"
# A roadmap's entries say where each stands (FR-24.5), from the items opened from them.
rows=
case $facts in r"$(printf '\t')"* | *"
r$(printf '\t')"*) rows=$(item_rows) ;; esac

if [ -n "$json" ]; then
	# The item_row fields, then one array per fact kind, in a fixed order.
	{ printf '%s\n' "$row"; [ -z "$facts" ] || printf '%s\n' "$facts"; } | ROWS=$rows awk -F '\t' "$AWK_JSON$AWK_ENTRY$AWK_DEPS$AWK_TASK"'
	BEGIN { deps_load() }
	NR == 1 { head = row_json(); next }
	{
		e = "{\"id\":\"" esc($2) "\",\"text\":\"" esc($4) "\""
		if ($1 == "fr" || $1 == "us") e = e ",\"example\":\"" esc($5) "\""
		if ($1 == "task") {
			# FR-53.2: its files: as task done reads them (task_row), split on commas and trimmed.
			split(task_row($2, $3, $4), tr, "\t"); m = split(tr[4], a, ","); fs = ""
			for (j = 1; j <= m; j++) { gsub(/^[ \t]+|[ \t]+$/, "", a[j]); if (a[j] != "") fs = fs (fs == "" ? "" : ",") "\"" esc(a[j]) "\"" }
			e = e ",\"done\":" ($3 == "done" ? "true" : "false") ",\"files\":[" fs "]"
		}
		if ($1 == "q") e = e ",\"decided\":" ($3 == "decided" ? "true" : "false")
		if ($1 == "r") {
			split(entry_row($2, $4), x, "\t"); m = split(x[4], a, " "); af = ""
			for (j = 1; j <= m; j++) af = af (j > 1 ? "," : "") "\"" a[j] "\""
			it = entry_item($2)
			e = e ",\"type\":\"" esc(x[2]) "\",\"title\":\"" esc(x[3]) "\",\"after\":[" af "]" \
				",\"state\":\"" (it == "" ? "not opened" : est[$2]) "\",\"item\":" (it == "" ? "null" : it)
		}
		list[$1] = list[$1] (list[$1] == "" ? "" : ",") e "}"
	}
	END {
		n = split("us:stories fr:requirements task:tasks d:decisions q:questions dod:done_when r:entries", kinds, " ")
		out = "{" head
		for (i = 1; i <= n; i++) {
			split(kinds[i], kv, ":")
			out = out ",\"" kv[2] "\":[" list[kv[1]] "]"
		}
		print out "}"
	}'
	exit 0
fi
printf '%s\n' "$row" | awk -F '\t' '{ printf "%s %s · %s · %s · %s%s\n", $1, $2, $8, $3, $4, ($9 == "" ? "" : " · " $9) }'
[ -z "$facts" ] || printf '%s\n' "$facts" | ROWS=$rows awk -F '\t' "$AWK_DEPS"'
BEGIN { deps_load() }
{
	mark = ($1 == "task") ? ($3 == "done" ? "[x] " : "[ ] ") : ($1 == "q" ? "[" $3 "] " : "")
	if ($1 == "r") mark = "[" (entry_item($2) == "" ? "not opened" : est[$2] " (item " eid[$2] ")") "] "
	printf "%-9s %s%s\n", $2, mark, $4
	if ($5 != "") printf "%-9s e.g. %s\n", "", $5
}'
echo "next    $CMD ls"

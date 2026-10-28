# shellcheck shell=sh
# analyze [<id>]: the problems in an item's plan that need no judgement (plan_findings), one line
# each, exit 1; or exit 0 when there are none. The current item, or item <id> read from its
# branch or the archive.
usage="usage: $NAME analyze [<id>]"
[ $# -le 1 ] || usage_die "$usage"
[ $# -eq 0 ] || case $1 in '' | *[!0-9]*) usage_die "$usage" ;; esac
need_repo
if [ $# -eq 0 ]; then
	current_item || die "not on an item branch (give an id, or see: $CMD status)"
	ITMP=
else
	src=$(item_sources | while IFS="$(printf '\t')" read -r o r p _; do
		[ "$(id_of "${p%/item.md}")" = "$1" ] && printf '%s\t%s\t%s\n' "$o" "$r" "$p"
	done | head -n 1)
	[ -n "$src" ] || die "no item $1 (see: $CMD ls)"
	item_load "$(tsv 1 "$src")" "$(tsv 2 "$src")" "$(tsv 3 "$src")" || die "could not read item $1"
fi
found=$(parse_item "$IFILE" "$ID" | plan_findings | findings_lines)
[ -z "$ITMP" ] || rm -f "$ITMP"
if [ -n "$found" ]; then
	printf '%s\n' "$found"
	exit 1
fi
echo "✓ item $ID: no problems found in the plan"

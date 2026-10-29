# shellcheck shell=sh
# status: the current item and its phase, or the open items on local branches.
[ $# -eq 0 ] || usage_die "usage: $NAME status"
need_repo

# open_items: "<id>\t<type>\t<title>\t<branch>\t<what it waits for>" for every open item on its own
# local branch. Every item is read only when one of them has a depends: (FR-24.6).
open_items() {
	_oi=$(item_rows local | awk -F '\t' -v OFS='\t' '$3 == "open" { print $1, $2, $8, $9, $19 }' | sort -n)
	if ! printf '%s\n' "$_oi" | awk -F '\t' '$5 != "" { f = 1 } END { exit !f }'; then
		printf '%s\n' "$_oi"
		return 0
	fi
	printf '%s\n' "$_oi" | ROWS=$(item_rows) awk -F '\t' -v OFS='\t' "$AWK_DEPS"'BEGIN { deps_load() } { $5 = deps_unmet($5); print }'
}

if current_item; then
	item_phase
	echo "$ID $ITYPE · $IR_TITLE · $BRANCH"
	echo "phase   $PHASE   ($WHY)"
	waits_for "$IR_DEPENDS"
	[ -z "$WAITS" ] || echo "waits   for $WAITS (ship waits until they have shipped)"
	# Only in a PR: status also runs at every agent session start, so no network call otherwise.
	pr=
	[ "$PHASE" != pr ] || pr=$(pr_note "$BRANCH")
	[ -z "$pr" ] || echo "pr      $pr"
	case $PHASE in
	plan) echo "next    plan with the human in $IFILE ($CMD next)" ;;
	build) echo "next    the agent builds hands-off ($CMD next)" ;;
	review) echo "next    $CMD review, then $CMD ship" ;;
	pr) echo "next    $CMD ship merges it once CI passes (the human runs it)" ;;
	esac
else
	items=$(open_items)
	if [ -z "$items" ]; then
		echo "no open items"
	else
		echo "open items:"
		printf '%s\n' "$items" | awk -F '\t' '{ printf "  %-5s %-9s %s   (git switch %s)%s\n", $1, $2, $3, $4, ($5 == "" ? "" : "   waits for " $5) }'
	fi
	echo "next    $CMD new <type> \"title\"   (types: $(types | paste -sd ' ' -))"
fi

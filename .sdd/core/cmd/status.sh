# shellcheck shell=sh
# status: the current item and its phase, or the open items on local branches.
[ $# -eq 0 ] || usage_die "usage: $NAME status"
need_repo

# open_items: "<id>\t<type>\t<title>\t<branch>" for every open item on its own local branch.
open_items() {
	item_sources | while IFS="$(printf '\t')" read -r o r p; do
		[ "$o" = local ] && item_row "$o" "$r" "$p"
	done | awk -F '\t' '$3 == "open" { print $1 "\t" $2 "\t" $8 "\t" $9 }' | sort -n
}

if current_item; then
	item_phase
	echo "$ID $ITYPE · $(fm_get title "$IFILE") · $BRANCH"
	echo "phase   $PHASE   ($WHY)"
	pr=$(pr_note "$BRANCH")
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
		printf '%s\n' "$items" | awk -F '\t' '{ printf "  %-5s %-9s %s   (git switch %s)\n", $1, $2, $3, $4 }'
	fi
	echo "next    $CMD new <type> \"title\"   (types: $(types | paste -sd ' ' -))"
fi

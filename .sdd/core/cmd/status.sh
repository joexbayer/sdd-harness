# shellcheck shell=sh
# status: the current item and its phase, or the open items on local branches.
[ $# -eq 0 ] || usage_die "usage: $NAME status"
need_repo

# open_items: "<id>\t<type>\t<title>\t<branch>" for every open item on its own local branch.
open_items() {
	git for-each-ref --format='%(refname:short)' refs/heads | while IFS= read -r b; do
		bid=$(id_of "$b") || continue
		git ls-tree -r --name-only "$b" -- "$SPECS/changes" 2>/dev/null | grep '/item\.md$' |
			while IFS= read -r p; do
				d=${p%/item.md}
				[ "$(id_of "$d")" = "$bid" ] || continue
				body=$(git show "$b:$p")
				[ "$(printf '%s\n' "$body" | fm_get status)" = open ] || continue
				printf '%s\t%s\t%s\t%s\n' "$bid" "$(printf '%s\n' "$body" | fm_get type)" \
					"$(printf '%s\n' "$body" | fm_get title)" "$b"
			done
	done | sort -n
}

if current_item; then
	item_phase
	echo "$ID $ITYPE · $(fm_get title "$IFILE") · $BRANCH"
	echo "phase   $PHASE   ($WHY)"
	case $PHASE in
	plan) echo "next    plan with the human in $IFILE ($CMD next)" ;;
	build) echo "next    the agent builds hands-off ($CMD next)" ;;
	review) echo "next    $CMD review, then $CMD ship" ;;
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

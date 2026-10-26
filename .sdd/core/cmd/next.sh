# shellcheck shell=sh
# next: agent-facing instructions for the current phase. Prints prompts/<phase>.md and then
# prompts/<phase>.<type>.md; a file under local/ replaces its core twin, and
# local/prompts/<name>.append.md is added after it.
[ $# -eq 0 ] || usage_die "usage: $NAME next"
need_repo

# prompt <name> <id> <title> <type>: print a prompt and its local .append.md, if any.
prompt() {
	_p=$(sdd_path "prompts/$1.md") && render "$_p" "$2" "$3" "$4"
	_x="$SDD_HOME/local/prompts/$1.append.md"
	[ -f "$_x" ] && render "$_x" "$2" "$3" "$4"
	return 0
}

if ! current_item; then
	prompt none '' '' ''
	exit 0
fi

item_phase
title=$(fm_get title "$IFILE")
echo "Item $ID ($ITYPE): $title"
echo "File: $IFILE"
echo "Phase: $PHASE ($WHY)"
echo
prompt "$PHASE" "$ID" "$title" "$ITYPE"
prompt "$PHASE.$ITYPE" "$ID" "$title" "$ITYPE"
case $PHASE in
plan | build)
	rules=$(articles | awk -F '\t' '$1 != "!" { print $1 " " $4 }')
	if [ -n "$rules" ]; then
		echo
		echo "Constitution (ground truths; changing one needs: $CMD new amendment \"…\"):"
		printf '%s\n' "$rules"
	fi
	;;
esac

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
# One task at a time: the current task first, with the requirements it serves.
if [ "$WHYCODE" = task ]; then
	t=$(task_rows | awk -F '\t' '$2 == "open" { print; exit }')
	tid=$(tsv 1 "$t")
	echo "Current task: $tid $(tsv 3 "$t")"
	[ -z "$(tsv 4 "$t")" ] || echo "  files   $(tsv 4 "$t")"
	if [ -n "$(tsv 5 "$t")" ]; then
		echo "  test    $(tsv 5 "$t")"
	else
		echo "  test    the full check ($CMD check)"
	fi
	[ "$(tsv 6 "$t")" != fail ] || echo "  expect  fail: write the test first: it must fail (the next task makes it pass)"
	for fr in $(tsv 7 "$t"); do
		parse_item "$IFILE" "$ID" | F=$fr awk -F '\t' '$1 == "fr" && $2 == ENVIRON["F"] {
			print "  serves  " $2 " " $4; if ($5 != "") print "          e.g. " $5 }'
	done
	case $ITYPE in feature) kind=feat ;; hotfix) kind=fix ;; *) kind=$ITYPE ;; esac
	echo
	echo "Do only this task. When its test passes, run: $CMD task done $tid, then commit the code and"
	echo "$IFILE together with the task in the subject, e.g. $kind($ID): $tid $(tsv 3 "$t")"
	echo
fi
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

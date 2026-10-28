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
title=$IR_TITLE
echo "Item $ID ($ITYPE): $title"
echo "File: $IFILE"
echo "Phase: $PHASE ($WHY)"
echo
# One batch at a time (task_batch): its tasks first, each with the requirements it serves.
if [ "$WHYCODE" = task ]; then
	batch=$(ir_batch)
	nl='
'
	ids=
	whats=
	tab=$(printf '\t')
	# The task_rows fields of each task, split without a process per field.
	while IFS= read -r t; do
		tid=${t%%"$tab"*}
		t=${t#*"$tab"}
		t=${t#*"$tab"}
		what=${t%%"$tab"*}
		t=${t#*"$tab"}
		files=${t%%"$tab"*}
		t=${t#*"$tab"}
		test=${t%%"$tab"*}
		t=${t#*"$tab"}
		expect=${t%%"$tab"*}
		t=${t#*"$tab"}
		frs=${t%%"$tab"*}
		t=${t#*"$tab"}
		bad=${t%%"$tab"*}
		case $batch in
		*"$nl"*)
			[ -n "$ids" ] || echo "Current batch: $(printf '%s\n' "$batch" | cut -f1 | paste -sd ' ' -) (small tasks, worked together, in order)"
			echo "Task: $tid $what"
			;;
		*) echo "Current task: $tid $what" ;;
		esac
		ids="${ids:+$ids }$tid"
		whats="${whats:+$whats; }$what"
		[ -z "$files" ] || echo "  files   $files"
		if [ -n "$test" ]; then
			echo "  test    $test"
		else
			echo "  test    the full check ($CMD check)"
		fi
		[ "$expect" != fail ] || echo "  expect  fail: write the test first: it must fail (the next task makes it pass)"
		[ -z "$bad" ] || echo "  ✗       $bad: the human fixes the plan and approves it again"
		for fr in $frs; do
			printf '%s\n' "$IR_FACTS" | F=$fr awk -F '\t' '$1 == "fr" && $2 == ENVIRON["F"] {
				print "  serves  " $2 " " $4; if ($5 != "") print "          e.g. " $5 }'
		done
	done <<BATCH
$batch
BATCH
	case $ITYPE in feature) kind=feat ;; hotfix) kind=fix ;; *) kind=$ITYPE ;; esac
	echo
	if [ "$ids" = "$tid" ]; then
		echo "Do only this task. When its test passes, run: $CMD task done $tid, then commit the code and"
		echo "$IFILE together with the task in the subject, e.g. $kind($ID): $tid $what"
	else
		echo "Do only these tasks, in order. As each one's test passes, run: $CMD task done <its id>. Then"
		echo "commit the code and $IFILE together, all the tasks in the subject, e.g. $kind($ID): $ids $whats"
	fi
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

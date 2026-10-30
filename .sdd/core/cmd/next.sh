# shellcheck shell=sh
# next: agent-facing instructions for the current phase. Prints prompts/<phase>.md and then
# prompts/<phase>.<type>.md; a file under local/ replaces its core twin, and
# local/prompts/<name>.append.md is added after it.
[ $# -eq 0 ] || usage_die "usage: $NAME next"
need_repo

# prompt <name> <id> <title> <type>: print a prompt and its local .append.md, if any.
prompt() {
	_p=$(sdd_path "prompts/$1.md") && render "$_p" "$2" "$3" "$4"
	# The finish steps (check, security pass, Built) close the build rules once no task is open;
	# a batch builder gets only its tasks (FR-21.2). Before build's .append.md, as when they were one.
	if [ "$1" = build ] && [ "$WHYCODE" != task ]; then
		_p=$(sdd_path prompts/finish.md) && render "$_p" "$2" "$3" "$4"
	fi
	_x="$SDD_HOME/local/prompts/$1.append.md"
	[ -f "$_x" ] && render "$_x" "$2" "$3" "$4"
	return 0
}

if ! current_item; then
	prompt none '' '' ''
	# The entries of shipped roadmaps that can be opened now (FR-24.5): not opened on any branch sdd
	# sees, every after: shipped. No roadmap on the base branch: nothing more is read.
	if rms=$(shipped_roadmaps); then
		dep_rows
		ready=$(printf '%s\n' "$rms" | ROWS=$DEP_ROWS C=$CMD awk -F '\t' "$AWK_DEPS"'
			BEGIN { deps_load() }
			$7 != "" || entry_item($3) != "" { next }
			{ n = split($6, a, " "); for (i = 1; i <= n; i++) if (!dep_met(a[i])) next
				print "Ready in roadmap " $1 " (" $2 "): " $3 " " $4 ": " $5 " → " ENVIRON["C"] " new --from " $3 }')
		if [ -n "$ready" ]; then
			echo
			printf '%s\n' "$ready"
		fi
	fi
	exit 0
fi

item_phase
title=$IR_TITLE
echo "Item $ID ($ITYPE): $title"
echo "File: $IFILE"
echo "Phase: $PHASE ($WHY)"
# FR-24.6: what this item waits for; it blocks only ship (D-24.2).
waits_for "$IR_DEPENDS"
[ -z "$WAITS" ] || echo "Waits for: $WAITS (plan and build on; ship waits until they have shipped)"
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
		t=${t#*"$tab"}
		t=${t#*"$tab"}
		reason=${t%%"$tab"*}
		by=${t#*"$tab"}
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
		if [ "$expect" = fail ] && [ -n "$reason" ]; then
			echo "  expect  fail: write the test first: it must fail with \"$reason\" in its output (the next task makes it pass)"
		elif [ "$expect" = fail ]; then
			echo "  expect  fail: write the test first: it must fail (the next task makes it pass)"
		fi
		# FR-36.1: the role that builds it, when not the builder.
		[ -z "$by" ] || echo "  by      $by ($CMD run $by $ID)"
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
# FR-26.6: the contracts the item builds against are fixed input for the builder.
if [ "$PHASE" = build ] && [ -n "$IR_CONTRACTS" ]; then
	contract_ids "$IR_CONTRACTS"
	echo "Contracts (read them; they change only through a contract item): $(joinlist "$(printf '%s\n' "$CROWS" | cut -f3)")"
	echo
fi
# FR-39.1, FR-39.2: a builder that takes less than L gets plans sized for it.
if [ "$PHASE" = plan ]; then
	max_size
	# shellcheck disable=SC2034 # read by render (common.sh)
	case $MAX_SIZE in
	S) RENDER_SIZE="- Every task is size S: the builder ([build] max-size S) is a small model. An S task is
  one module or behaviour group, at most about 3 FRs, with a test it can run alone. Split
  anything bigger; \`{{cmd}} analyze\` flags every task above S." ;;
	M) RENDER_SIZE="- Every task is size S or M: the builder ([build] max-size M) takes no L task. Split
  anything bigger; \`{{cmd}} analyze\` flags every task above M." ;;
	esac
fi
prompt "$PHASE" "$ID" "$title" "$ITYPE"
prompt "$PHASE.$ITYPE" "$ID" "$title" "$ITYPE"
# A filled-in plan waiting for approval: what analyze finds, for the agent to fix first (FR-19.3).
case $WHYCODE in
approval | changed | contract)
	found=$(printf '%s\n' "$IR_FACTS" | plan_findings | findings_lines)
	if [ -n "$found" ]; then
		echo
		echo "Before asking for approval, fix:"
		printf '%s\n' "$found"
	fi
	;;
esac
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

# shellcheck shell=sh
# task [done <T-id>]: the current item's tasks, each with its test and whether a commit names it.
# `task done` runs one task's test (the check, if it names none) and, when it passes, ticks the
# task's box. It never commits (C-4): the agent commits the code and the tick, naming the task.
usage="usage: $NAME task [done T-<id>.<n>]"
need_repo
current_item || die "not on an item branch (see: $CMD status)"
fm_closed "$IFILE" || die "item $ID: $FM_OPEN"

if [ $# -eq 0 ]; then
	rows=$(task_rows)
	[ -n "$rows" ] || { echo "item $ID has no tasks (add - [ ] T-$ID.1 … to the plan)"; exit 0; }
	printf '%s\n' "$rows" | while IFS= read -r r; do
		t=$(tsv 1 "$r")
		box="[ ]"
		[ "$(tsv 2 "$r")" = 'done' ] && box="[x]"
		c=$(task_commit "$t")
		echo "$box $t $(tsv 3 "$r")"
		ex=
		[ "$(tsv 6 "$r")" != fail ] || ex=" (expect: fail)"
		[ -z "$(tsv 5 "$r")" ] || echo "      test: $(tsv 5 "$r")$ex"
		[ -z "$(tsv 7 "$r")" ] || echo "      serves: $(tsv 7 "$r")"
		if [ -n "$c" ]; then echo "      commit $c"; else echo "      no commit names it yet"; fi
	done
	exit 0
fi
[ "$1" = 'done' ] && [ $# -eq 2 ] || usage_die "$usage"
tid=$2

row=$(task_rows | T=$tid awk -F '\t' '$1 == ENVIRON["T"]')
[ -n "$row" ] || die "no task $tid in item $ID (see: $CMD task)"
[ "$(tsv 2 "$row")" = open ] || die "$tid is already ticked"
# The test is a shell command from the item: run it only for the plan the human approved.
[ "$(gate_level approved "$ITYPE")" = off ] || approval_ok ||
	die "the plan is not approved, or changed since: the human runs $CMD approve first (a task's test runs only for the approved plan)"

test=$(tsv 5 "$row")
expect=$(tsv 6 "$row")
if [ -z "$test" ]; then
	[ "$expect" != fail ] || die "$tid says expect: fail but names no test"
	run_check "$ID"
	rc=$?
	how="the check passed"
	[ "$rc" -eq 0 ] || { echo "✗ $tid: the check did not pass (log: $CHECK_LOG)"; exit 1; }
else
	log="$ST/checks/$ID.$tid.log"
	sh -c "$test" </dev/null >"$log" 2>&1
	rc=$?
	if [ "$rc" -eq 126 ] || [ "$rc" -eq 127 ]; then
		tail -n 5 "$log"
		die "$tid: its test could not run (exit $rc: command not found or not executable)"
	elif [ "$expect" = fail ]; then
		[ "$rc" -ne 0 ] || { tail -n 20 "$log"; echo "✗ $tid expected its test to fail, but it passed: write the test first (log: $log)"; exit 1; }
		how="its test fails, as expected"
	else
		[ "$rc" -eq 0 ] || { tail -n 20 "$log"; echo "✗ $tid: its test failed (exit $rc; log: $log)"; exit 1; }
		how="its test passed"
	fi
fi

T=$tid awk '!d && index($0, "- [ ] " ENVIRON["T"] " ") == 1 { $0 = "- [x]" substr($0, 6); d = 1 } { print }' "$IFILE" >"$IFILE.tmp.$$" &&
	mv "$IFILE.tmp.$$" "$IFILE" || die "could not tick $tid in $IFILE"
case $ITYPE in feature) kind=feat ;; hotfix) kind=fix ;; *) kind=$ITYPE ;; esac
echo "✓ $tid done ($how) · commit with: $kind($ID): $tid $(tsv 3 "$row")"
echo "next    commit the code and $IFILE together, then: $CMD next"

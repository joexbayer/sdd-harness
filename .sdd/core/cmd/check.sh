# shellcheck shell=sh
# check: run the configured checks and record the result for the current item.
[ $# -eq 0 ] || usage_die "usage: $NAME check"
need_repo

id=
current_item && id=$ID
if [ -n "$id" ] && ! guard=$(constitution_guard); then
	echo "✗ $guard"
	exit 1
fi
run_check "$id"
rc=$?
case $rc in
0)
	echo "✓ check passed$([ -n "$id" ] && echo " for item $id") ($CHECK_SECS s)"
	if [ -n "$CHECK_DIRTIED" ]; then
		echo "! the check itself created or changed files, so the tree now differs from what passed:"
		printf '%s\n' "$CHECK_DIRTIED" | head -n 5 | sed 's/^/    /'
		echo "next    make the tests write to a temp dir (or ignore that output in .gitignore), then $CMD check again"
	elif [ -n "$id" ]; then
		item_phase
		echo "next    $([ "$PHASE" = review ] && echo "$CMD review" || echo "$WHY")"
	fi
	;;
3)
	echo "✗ check proves nothing: the output shows zero tests ran ($CHECK_SECS s; log: $CHECK_LOG)"
	;;
*)
	tail -n 40 "$CHECK_LOG"
	[ -z "$CHECK_ARTICLES" ] || printf '%s\n' "$CHECK_ARTICLES" | sed 's/^/✗ constitution: /'
	if [ -n "$CHECK_NOTRUN" ]; then
		echo "✗ check could not run \`$CHECK_NOTRUN\` (command not found or not executable)"
		echo "next    this is the check config, not your code: fix 'run' under [check] in $DIRNAME/config"
	else
		echo "✗ check failed ($CHECK_SECS s; full log: $CHECK_LOG)"
		[ -z "$id" ] || echo "next    fix the failures and run $CMD check again (rules for this step: $CMD next)"
	fi
	;;
esac
# FR-35.2: a slow gate is a cost, not wrong code: warn, never fail.
budget=$(cfg check.budget 30)
case $budget in '' | *[!0-9]*) warn "[check] budget is not a number of seconds: $budget"; budget=0 ;; esac
if [ "$budget" -gt 0 ] && [ "$CHECK_SECS" -gt "$budget" ]; then
	echo "⚠ the check took $CHECK_SECS s (budget $budget s): keep the gate fast. Slow tests (end-to-end, real hash cost, sleeps, network) belong to their task's test: mark them and leave them out of check.run; make cost settings (hash rounds, timeouts) configurable and minimal in tests, with one test on the real values"
fi
no_articles
exit $rc

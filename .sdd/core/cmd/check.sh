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
	echo "✓ check passed$([ -n "$id" ] && echo " for item $id")"
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
	echo "✗ check proves nothing: the output shows zero tests ran (log: $CHECK_LOG)"
	;;
*)
	tail -n 40 "$CHECK_LOG"
	[ -z "$CHECK_ARTICLES" ] || printf '%s\n' "$CHECK_ARTICLES" | sed 's/^/✗ constitution: /'
	if [ -n "$CHECK_NOTRUN" ]; then
		echo "✗ check could not run \`$CHECK_NOTRUN\` (command not found or not executable)"
		echo "next    this is the check config, not your code: fix 'run' under [check] in $DIRNAME/config"
	else
		echo "✗ check failed (full log: $CHECK_LOG)"
		[ -z "$id" ] || echo "next    fix the failures and run $CMD check again (rules for this step: $CMD next)"
	fi
	;;
esac
exit $rc

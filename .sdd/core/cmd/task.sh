# shellcheck shell=sh
# task [next | done <T-id>]: the current item's tasks, each with its test and whether a commit names
# it. `task next` prints the next batch: the tasks the builder works at once (task_batch).
# `task done` runs one task's test (the check, if it names none) and, when it passes, ticks the
# task's box and notes it in this clone's state (.git/sdd/checks/<id>.tasks), which ship asks
# for. It never commits (C-4): the agent commits the code and the tick, naming the task.
usage="usage: $NAME task [next | done T-<id>.<n>]"
need_repo
current_item || die "not on an item branch (see: $CMD status)"
fm_closed "$IFILE" || die "item $ID: $FM_OPEN"
record="$ST/checks/$ID.tasks"

if [ $# -eq 0 ]; then
	rows=$(task_rows)
	[ -n "$rows" ] || { echo "item $ID has no tasks (add - [ ] T-$ID.1 … to the plan)"; exit 0; }
	printf '%s\n' "$rows" | while IFS= read -r r; do
		t=$(tsv 1 "$r")
		box="[ ]"
		[ "$(tsv 2 "$r")" = 'done' ] && box="[x]"
		c=$(task_commit "$t")
		printf '%s %s %s\n' "$box" "$t" "$(tsv 3 "$r")"
		ex=
		[ "$(tsv 6 "$r")" != fail ] || ex=" (expect: fail$(tsv 10 "$r" | sed 's/..*/ "&"/'))"
		[ -z "$(tsv 5 "$r")" ] || printf '      test: %s%s\n' "$(tsv 5 "$r")" "$ex"
		[ -z "$(tsv 7 "$r")" ] || printf '      serves: %s\n' "$(tsv 7 "$r")"
		[ -z "$(tsv 8 "$r")" ] || echo "      ✗ $(tsv 8 "$r")"
		if [ -n "$c" ]; then echo "      commit $c"; else echo "      no commit names it yet"; fi
		[ "$box" = "[ ]" ] || grep -qx "$t" "$record" 2>/dev/null || echo "      ticked without $NAME task done in this clone"
	done
	exit 0
fi
if [ "$1" = next ] && [ $# -eq 1 ]; then
	rows=$(task_rows)
	[ -n "$rows" ] || { echo "item $ID has no tasks (add - [ ] T-$ID.1 … to the plan)"; exit 0; }
	batch=$(printf '%s\n' "$rows" | task_batch)
	[ -n "$batch" ] || { echo "no open tasks: the check and \"## Built\" are next (see: $CMD next)"; exit 0; }
	echo "batch   $(printf '%s\n' "$batch" | cut -f1 | paste -sd ' ' -)"
	printf '%s\n' "$batch" | while IFS= read -r r; do
		printf '[ ] %s %s (size: %s%s)\n' "$(tsv 1 "$r")" "$(tsv 3 "$r")" "$(tsv 9 "$r")" "$(tsv 11 "$r" | sed 's/..*/; by: &/')"
		[ -z "$(tsv 4 "$r")" ] || printf '      files: %s\n' "$(tsv 4 "$r")"
		ex=
		[ "$(tsv 6 "$r")" != fail ] || ex=" (expect: fail$(tsv 10 "$r" | sed 's/..*/ "&"/'))"
		if [ -n "$(tsv 5 "$r")" ]; then printf '      test: %s%s\n' "$(tsv 5 "$r")" "$ex"; else echo "      test: the full check ($CMD check)"; fi
		[ -z "$(tsv 7 "$r")" ] || printf '      serves: %s\n' "$(tsv 7 "$r")"
		[ -z "$(tsv 8 "$r")" ] || echo "      ✗ $(tsv 8 "$r")"
	done
	exit 0
fi
[ "$1" = 'done' ] && [ $# -eq 2 ] || usage_die "$usage"
tid=$2

# red_without_code: FR-31.2, D-31.2, D-31.3. A test written together with its code passes. When
# there are uncommitted changes besides the task's files, run the test once more in a throwaway
# checkout of HEAD with only those files copied in: failing there is red. Sets rc, log and
# without; refuses (FR-31.3) when that cannot prove it. The working tree is never touched.
red_without_code() {
	# files: entries, one per line, without surrounding blanks or trailing slashes.
	red_files=$(tsv 4 "$row" | tr ',' '\n' | sed 's/^[[:space:]]*//; s/[[:space:]]*$//; s:/*$::' | grep -v '^$')
	red_other=$({
		git -c core.quotePath=false diff --name-only HEAD --
		git -c core.quotePath=false ls-files --others --exclude-standard
	} | F=$red_files I=$IFILE awk '
		BEGIN { n = split(ENVIRON["F"], f, "\n") }
		$0 == ENVIRON["I"] { next }
		{ for (i = 1; i <= n; i++) if ($0 == f[i] || index($0, f[i] "/") == 1) next; print }')
	if [ -z "$red_other" ]; then
		tail -n 20 "$log"
		echo "✗ $tid expected its test to fail, but it passed: the code is already committed (or there is none), so $NAME cannot see the test fail; write the test before its code. Already committed? git revert the code commit, run task done while the test fails, commit, then revert the revert (log: $log)"
		exit 1
	fi
	red_dir=$(mktemp -d "${TMPDIR:-/tmp}/$NAME-red.XXXXXX") || die "could not make a temporary folder"
	# Removed on every way out from here, a die included.
	trap 'git worktree remove --force "$red_dir/wt" >/dev/null 2>&1; rm -rf "$red_dir"' EXIT
	git worktree add -q --detach "$red_dir/wt" HEAD >/dev/null 2>&1 || die "$tid: could not check out HEAD in $red_dir to run its test without the uncommitted code"
	printf '%s\n' "$red_files" | while IFS= read -r p; do
		d=$(dirname -- "$p")
		mkdir -p -- "$red_dir/wt/$d" && cp -R -- "$p" "$red_dir/wt/$d/" || exit 1
	done || die "$tid: could not copy its files into $red_dir"
	log="$ST/checks/$ID.$tid.red.log"
	(cd "$red_dir/wt" && sh -c "$test" </dev/null >"$log" 2>&1)
	rc=$?
	git worktree remove --force "$red_dir/wt" >/dev/null 2>&1
	rm -rf "$red_dir"
	trap - EXIT
	if [ "$rc" -eq 0 ]; then
		tail -n 20 "$log"
		echo "✗ $tid expected its test to fail, but it passes even without the uncommitted code: the test does not test the change; fix the test (log: $log)"
		exit 1
	fi
	without=" without the uncommitted code"
}

row=$(task_rows | T=$tid awk -F '\t' '$1 == ENVIRON["T"]')
[ -n "$row" ] || die "no task $tid in item $ID (see: $CMD task)"
[ "$(tsv 2 "$row")" = open ] || die "$tid is already ticked"
bad=$(tsv 8 "$row")
[ -z "$bad" ] || die "$tid: $bad"
# The test is a shell command from the item: run it only for the plan the human approved. Types
# without an approval step (hotfix, chore) trust it like the check commands in config.
[ "$(gate_level approved "$ITYPE")" = off ] || approval_ok ||
	die "the plan is not approved, or changed since: the human runs $CMD approve first (a task's test runs only for the approved plan)"

test=$(tsv 5 "$row")
expect=$(tsv 6 "$row")
reason=$(tsv 10 "$row")
if [ -z "$test" ]; then
	[ "$expect" != fail ] || die "$tid says expect: fail but names no test"
	run_check "$ID"
	rc=$?
	how="the check passed"
	[ "$rc" -eq 0 ] || { echo "✗ $tid: the check did not pass (log: $CHECK_LOG)"; exit 1; }
else
	bad=$(printf '%s\n' "$test" | masked)
	[ -z "$bad" ] || die "$tid: its test hides failures ($bad)"
	if [ "$expect" = fail ]; then
		# A test written first must exist: "fails" because a file is missing proves nothing.
		for p in $(tsv 4 "$row" | tr ',' ' '); do
			[ -e "$p" ] || die "$tid: $p (in files:) does not exist yet: write the test first"
		done
	fi
	log="$ST/checks/$ID.$tid.log"
	sh -c "$test" </dev/null >"$log" 2>&1
	rc=$?
	if [ "$rc" -eq 126 ] || [ "$rc" -eq 127 ]; then
		tail -n 5 "$log"
		die "$tid: its test could not run (exit $rc: command not found or not executable)"
	elif [ "$expect" = fail ]; then
		without=
		# Exit 126/127 there is red too: the same command ran in the tree, so what is missing is the
		# uncommitted code (e.g. `sh api.sh`).
		[ "$rc" -ne 0 ] || red_without_code
		# A red test that ran no tests proves nothing either (the check's no-tests patterns).
		nt=$(cfg_all check.no-tests | paste -sd '|' -)
		[ -z "$nt" ] || ! grep -qiE "$nt" "$log" ||
			die "$tid: its test ran no tests (log: $log): a failing test must run"
		# FR-22.1: a red run counts only when it fails for the reason the plan names (a fixed string:
		# an argument to grep -F, never part of a shell string).
		if [ -n "$reason" ] && ! grep -qF -- "$reason" "$log"; then
			tail -n 20 "$log"
			echo "✗ $tid failed$without, but not for the expected reason ($reason); log: $log"
			exit 1
		fi
		how="its test fails${without:-, as expected}"
		[ -z "$reason" ] || how="$how: $reason"
	else
		[ "$rc" -eq 0 ] || { tail -n 20 "$log"; echo "✗ $tid: its test failed (exit $rc; log: $log)"; exit 1; }
		how="its test passed"
	fi
fi

# Tick the task's own line: in the plan part, outside code fences, the whole ID.
T=$tid awk '
	$0 == "## Built" { past = 1 }
	/^```/ { fence = !fence }
	!past && !fence && !d && index($0, "- [ ] " ENVIRON["T"]) == 1 {
		c = substr($0, length("- [ ] " ENVIRON["T"]) + 1, 1)
		if (c == "" || c == " " || c == "\t") { $0 = "- [x]" substr($0, 6); d = 1 }
	}
	{ print }
	END { exit !d }' "$IFILE" >"$IFILE.tmp.$$" && mv "$IFILE.tmp.$$" "$IFILE" ||
	{ rm -f "$IFILE.tmp.$$"; die "could not find the line of $tid to tick in $IFILE"; }
echo "$tid" >>"$record"
case $ITYPE in feature) kind=feat ;; hotfix) kind=fix ;; *) kind=$ITYPE ;; esac
printf '✓ %s done (%s) · commit with: %s(%s): %s %s\n' "$tid" "$how" "$kind" "$ID" "$tid" "$(tsv 3 "$row")"
# FR-51.3: an earlier tick its commit did not name, while an amend still fixes it.
unnamed_note
echo "next    commit the code and $IFILE together, then: $CMD next"

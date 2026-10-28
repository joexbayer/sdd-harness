# Item 18 (performance): the commands agents call constantly stay fast as a repo grows. On a
# generated repo with 100 items (95 shipped, 5 open on their own branches, one of them checked
# out mid-build): next, status, hook stop and hook session-start under 0.2s; ls, ls --json and
# summary under 1s. SDD_PERF_SLACK multiplies every budget, for slow machines (default 1).
# Each time is the best of three runs after one warm-up run (which fills the cache); one over
# budget is measured again, twice at most, after a pause.
. "$SRC/tests/lib.sh"
new_repo

# item <id> <status>: a feature item the size of a real one, with requirements, decisions, a
# question, tasks and Built.
item() {
	I=$1 S=$2 D=$(date +%F) awk 'BEGIN {
		i = ENVIRON["I"]; s = ENVIRON["S"]
		print "---"; print "id: " i; print "type: feature"; print "title: Item " i; print "status: " s
		print "created: " ENVIRON["D"]
		if (s == "shipped") { print "approved: 0123456789abcdef " ENVIRON["D"] " test"; print "shipped: " ENVIRON["D"] }
		print "---"; print "# " i " Item " i; print ""
		print "## Why"; print "Generated for the performance test: item " i " has a plan the size of a real one."; print ""
		print "## What changes"
		for (n = 1; n <= 6; n++) {
			print "FR-" i "." n " WHEN step " n " runs THE SYSTEM SHALL do part " n " of item " i ","
			print "and say what it did."
			print "  e.g. `step " n "` → part " n " done"
		}
		print ""; print "## How"
		for (n = 1; n <= 3; n++) print "D-" i "." n " Do part " n " this way, because it is the simplest."
		print ""; print "## Security"; print "none: generated text."; print ""
		print "## Questions (optional)"; print "Q-" i ".1 How many parts? → recommend: six, decided: six"; print ""
		print "## Done when"; print "DOD-" i ".1 every part works."; print ""
		print "## Tasks (optional)"
		for (n = 1; n <= 4; n++) print "- [" (s == "shipped" || n == 1 ? "x" : " ") "] T-" i "." n " Part " n ", FR-" i "." n " (files: src/p" n ".sh; test: true)"
		print ""; print "## Built"
		if (s == "shipped") for (n = 1; n <= 6; n++) print "FR-" i "." n ": src/p" n ".sh:1, tests/t_p" n ".sh proves it."
		print ""; print "## Review (optional)"
	}'
}

i=0
while [ $i -lt 95 ]; do
	i=$((i + 1))
	mkdir -p "specs/archive/$i-item-$i"
	item "$i" shipped >"specs/archive/$i-item-$i/item.md"
	git add specs/archive && git commit -qm "docs($i): open feature \"Item $i\"" || fail "commit $i failed"
done
for i in 96 97 98 99 100; do
	git switch -q -c "feature/$i-item-$i" main
	mkdir -p "specs/changes/$i-item-$i"
	item "$i" open >"specs/changes/$i-item-$i/item.md"
	git add specs && git commit -qm "docs($i): open feature \"Item $i\"" || fail "commit $i failed"
done
# Item 100 is approved, mid-build, with code changed: next shows a task, hook stop judges it.
sdd approve >/dev/null 2>&1 || fail "approve failed"
echo code >src.txt && git add src.txt && git commit -qm "feat(100): T-100.1 Part 1"
assert_contains "$(sdd next)" "Current task: T-100.2 Part 2"
assert_eq "$(sdd ls | grep -c '^[0-9]')" 100
assert_eq "$(sdd summary --md | grep -c '^| [0-9]')" 100

# secs <command>: wall seconds of the best of three runs, after a warm-up run (POSIX time -p).
secs() {
	"$SH" -c "$1" >/dev/null 2>&1
	for _r in 1 2 3; do
		command time -p "$SH" -c "$1 >/dev/null 2>&1" 2>&1 >/dev/null | awk '$1 == "real" { print $2 }'
	done | sort -n | head -n 1
}

s="$SH .sdd/bin/sdd"
hook_in=$(printf '{"cwd":"%s","stop_hook_active":false}' "$PWD")
report=
over=
# A time over budget is measured again after a pause, twice at most: other work on the machine
# (often the rest of the suite, just finished) slows every command for a while, a regression
# slows it every time.
while IFS='|' read -r budget cmd; do
	for _try in 1 2 3; do
		[ "$_try" = 1 ] || sleep 3
		took=$(secs "$cmd")
		[ -n "$took" ] || fail "could not time: $cmd"
		ok=$(B=$budget X=${SDD_PERF_SLACK:-1} S=$took awk 'BEGIN { print (ENVIRON["S"] + 0 < ENVIRON["B"] * ENVIRON["X"]) ? "ok" : "over" }')
		[ "$ok" = over ] || break
	done
	report="$report
  $ok $took s (budget $budget s × ${SDD_PERF_SLACK:-1}): $cmd"
	[ "$ok" = ok ] || over=1
done <<EOF
0.2|$s next
0.2|$s status
0.2|printf '%s' '$hook_in' | $s hook stop --agent claude
0.2|printf '%s' '$hook_in' | $s hook session-start --agent claude
1|$s ls
1|$s ls --json
1|$s summary
EOF
[ -z "$over" ] || fail "over budget:$report"

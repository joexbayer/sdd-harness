# FR-21.1 an agent sdd run starts cannot approve, ship or tidy --remote (SDD_RUN); FR-21.2 the
# finish steps only once no task is open; FR-21.3 the build rules name the human-only verbs;
# FR-21.4 sdd usage keeps a batch's row aligned.
. "$SRC/tests/lib.sh"
new_repo
setcfg usage.track true
setcfg role.builder.tier small && setcfg tier.small.agent narrow && setcfg tier.small.model m

# A careless builder: it tries every human-only verb (item 17's trial chained ship after a commit).
mkdir -p "$T/bin" "$T/stub"
cat >"$T/bin/narrow" <<'EOF'
#!/bin/sh
echo "${SDD_RUN:-}" >"$STUB/run"
for v in approve ship tidy; do
	a=$v
	[ "$v" != tidy ] || a="tidy --remote"
	# shellcheck disable=SC2086 # the verb and its flag, split on purpose
	"$SDD_SH" .sdd/bin/sdd $a >"$STUB/$v.out" 2>&1
	echo $? >"$STUB/$v.rc"
done
echo '{"type":"finish","exit":0,"verdict":"passed","tokens":{"in":10,"out":1}}'
EOF
chmod +x "$T/bin/narrow"

sdd new feature "Guard" >/dev/null 2>&1
f=specs/changes/1-guard/item.md
fill "$f" plan
awk '/^## What changes$/ { print; print "FR-1.1 WHEN x THE SYSTEM SHALL y."; next }
/^## Tasks \(optional\)$/ { print
	print "- [ ] T-1.1 One, FR-1.1 (test: true; size: S)"
	print "- [ ] T-1.2 Two, FR-1.1 (test: true; size: S)"
	print "- [ ] T-1.3 Three, FR-1.1 (test: true; size: L)"
	print ""; next } { print }' "$f" >"$T/f" && cp "$T/f" "$f"
git commit -qam "docs(1): plan" && sdd approve >/dev/null 2>&1 || fail "approve failed"

# FR-21.2: a batch builder gets its tasks and the build rules, not the finish steps.
out=$(sdd next)
assert_contains "$out" 'Current batch: T-1.1 T-1.2'
assert_contains "$out" 'Build exactly what the plan says'
assert_not_contains "$out" 'security pass'
assert_not_contains "$out" 'You are done when'
# FR-21.3: the build rules say approve, ship and tidy --remote are the human's.
assert_contains "$out" 'Never run `.sdd/bin/sdd approve`, `.sdd/bin/sdd ship` or `.sdd/bin/sdd tidy --remote`: they are the human'"'"'s.'

# FR-21.1: the run number is in the agent's environment, and the three verbs refuse with exit 2.
head=$(git rev-parse HEAD)
out=$( (export PATH="$T/bin:$PATH" STUB="$T/stub"; sdd run builder 1) 2>&1) || fail "run failed: $out"
assert_eq "$(cat "$T/stub/run")" 1 "(SDD_RUN)"
for v in approve ship tidy; do assert_eq "$(cat "$T/stub/$v.rc")" 2 "($v under sdd run: $(cat "$T/stub/$v.out"))"; done
assert_contains "$(cat "$T/stub/approve.out")" "sdd: approve is the human's: a role run (run 1) cannot approve"
assert_contains "$(cat "$T/stub/ship.out")" "sdd: ship is the human's: a role run (run 1) cannot ship"
assert_contains "$(cat "$T/stub/tidy.out")" "sdd: tidy --remote is the human's: a role run (run 1) cannot tidy --remote"
assert_eq "$(git rev-parse HEAD)" "$head" "(no commit)"
assert_eq "$(git symbolic-ref --short HEAD)" feature/1-guard "(still on the item branch)"
# FR-31.1: sdd ticked the batch the careless builder left open; it commits nothing (C-4).
assert_contains "$out" 'ticked 2 of 2 · commit with: feat(1): T-1.1 T-1.2'
git commit -qam "feat(1): T-1.1 T-1.2"
# With usage tracking off a run has no number ("-"); the refusal says just "a role run".
out=$( (export SDD_RUN=-; sdd ship) 2>&1)
assert_eq $? 2 "(ship, untracked run)"
assert_contains "$out" "sdd: ship is the human's: a role run cannot ship"
# Everything else still works under a role run; tidy without --remote too.
(export SDD_RUN=7; sdd tidy --dry-run >/dev/null 2>&1) || fail "tidy without --remote refused under SDD_RUN"


# FR-28.2: while a task is open, the finish gate holds a role run's builder, as it holds anyone.
echo work >work.txt && git add work.txt && git commit -qm "feat(1): work"
(export SDD_RUN=3 SDD_ROLE=builder; sdd hook stop </dev/null >/dev/null 2>&1)
assert_eq $? 2 "(role-run builder, task open)"

# FR-21.2: once no task is open, the finish steps are back (as today), with the same rule.
sdd task 'done' T-1.3 >/dev/null 2>&1 || fail "task done T-1.3 failed"
git commit -qam "feat(1): work"
# FR-28.2: its tasks ticked, a role run's builder may stop (Built is the orchestrator's); an
# interactive builder (no SDD_RUN) is still held.
out=$( (export SDD_RUN=3 SDD_ROLE=builder; sdd hook stop </dev/null) 2>&1) || fail "the finish gate held a role-run builder with no open task: $out"
assert_eq "$out" "" "(no message)"
sdd hook stop </dev/null >/dev/null 2>&1
assert_eq $? 2 "(interactive builder, Built empty)"
out=$(sdd next)
assert_not_contains "$out" 'Current task'
assert_contains "$out" 'run a security pass over this item'"'"'s diff, in a fresh context'
assert_contains "$out" 'You are done when the check passes and "## Built" is written'
assert_contains "$out" 'tidy --remote`: they are the human'"'"'s.'

# FR-21.4: the run above logged the batch "T-1.1 T-1.2"; with a one-task row the columns line up.
log=$(git rev-parse --git-common-dir)/sdd/runs.tsv
printf '9\tt\t1\tbuilder\tnarrow\tm\tbuild\tT-1.3\t5000\t500\t\t10\t0\tpassed\n' >>"$log"
out=$(sdd usage 1)
assert_contains "$out" "$(printf '%-6s %-10s %-11s %5s' item role task runs)"
assert_contains "$out" "$(printf '%-6s %-10s %-11s %5d' 1 builder 'T-1.1 T-1.2' 1)"
assert_contains "$out" "$(printf '%-6s %-10s %-11s %5d' 1 builder T-1.3 1)"
assert_eq "$(printf '%s\n' "$out" | awk '{ print length($0) }' | sort -u | wc -l | tr -d ' ')" 1 "(rows of one width: $out)"
exit 0

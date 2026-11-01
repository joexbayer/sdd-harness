# FR-35.1 check says how long it took and records it; FR-35.2 a check over [check] budget warns
# without failing, and budget 0 turns the warning off.
. "$SRC/tests/lib.sh"
new_repo
planned_item fix "Slow gate"
id=$(sed -n 's/^id: //p' "$ITEM")

# FR-35.1: the time is shown with the result and recorded with it.
out=$(sdd check 2>&1) || fail "check failed: $out"
s=$(sed -n 's/^secs=//p' "$(git rev-parse --git-path sdd/checks/"$id")")
case $s in '' | *[!0-9]*) fail "no secs= in the check record: [$s]" ;; esac
assert_contains "$out" "✓ check passed for item $id ($s s)"
assert_not_contains "$out" '⚠ the check took'

# FR-35.2: a 2 s check with budget 1 warns, and still passes.
setcfg --add check.run 'sleep 2'
setcfg check.budget 1
out=$(sdd check 2>&1) || fail "a slow check must still pass: $out"
assert_contains "$out" "✓ check passed for item $id ("
s=$(sed -n 's/^secs=//p' "$(git rev-parse --git-path sdd/checks/"$id")")
[ "$s" -ge 2 ] || fail "expected secs >= 2 in the record, got [$s]"
assert_contains "$out" "($s s)"
assert_contains "$out" "⚠ the check took $s s (budget 1 s): keep the gate fast. Slow tests (end-to-end, real hash cost, sleeps, network) belong to their task's test: mark them and leave them out of check.run; make cost settings (hash rounds, timeouts) configurable and minimal in tests, with one test on the real values"

# FR-35.2: budget 0 turns the warning off. The sleep has made its point: drop it (item 56).
setcfg --unset check.run '^sleep 2$'
setcfg check.budget 0
out=$(sdd check 2>&1) || fail "check failed: $out"
assert_not_contains "$out" '⚠ the check took'

# FR-35.1: a failing check shows its time too.
setcfg --add check.run 'false'
out=$(sdd check 2>&1) && fail "check should fail: $out"
assert_contains "$out" '✗ check failed ('
echo ok

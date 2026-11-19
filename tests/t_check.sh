# FR-76.1 the third failed check in a row says to stop and tell the human; a pass resets the count.
. "$SRC/tests/lib.sh"
new_repo
planned_item fix "Stuck"
stop='✗ check failed 3 times in a row: stop and tell the human what fails and what you tried'
setcfg --add check.run 'false'
out=$(sdd check 2>&1) && fail "check should fail: $out"
assert_not_contains "$out" 'in a row'
out=$(sdd check 2>&1) && fail "check should fail: $out"
assert_not_contains "$out" 'in a row'
out=$(sdd check 2>&1) && fail "check should fail: $out"
assert_contains "$out" "$stop"

# A pass resets: two more failures after it do not print the line.
setcfg --unset check.run '^false$'
out=$(sdd check 2>&1) || fail "check should pass: $out"
setcfg --add check.run 'false'
out=$(sdd check 2>&1) && fail "check should fail: $out"
out=$(sdd check 2>&1) && fail "check should fail: $out"
assert_not_contains "$out" 'in a row'
echo ok

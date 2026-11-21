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
# FR-83.5: a failed command shows its own output even when later commands pass.
setcfg --replace-all check.run 'echo shellwarn; exit 1'
setcfg --add check.run 'i=0; while [ $i -lt 60 ]; do echo pass$i; i=$((i+1)); done'
out=$(sdd check 2>&1) && fail "check should fail: $out"
assert_contains "$out" "\$ echo shellwarn; exit 1"
assert_contains "$out" shellwarn
assert_contains "$out" '[exit 1]'
assert_not_contains "$out" pass50
echo ok

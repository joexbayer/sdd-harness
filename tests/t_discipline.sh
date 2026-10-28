# FR-20.1 two failed fixes on one assumption: state it and stop, FR-20.2 tests check behaviour.
. "$SRC/tests/lib.sh"
new_repo
planned_item feature "Discipline"
sdd approve >/dev/null 2>&1 || fail "approve failed"
out=$(sdd next)
assert_contains "$out" 'After two fixes resting on the same assumption fail'
assert_contains "$out" 'still pass if every function returned nothing'
exit 0

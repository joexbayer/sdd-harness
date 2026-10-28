# FR-20.1 two failed fixes on one assumption: state it and stop, FR-20.2 tests check behaviour,
# FR-20.3 subtract before adding, FR-20.5 probe before asking.
. "$SRC/tests/lib.sh"
new_repo
planned_item feature "Discipline"
sdd approve >/dev/null 2>&1 || fail "approve failed"
out=$(sdd next)
assert_contains "$out" 'After two fixes resting on the same assumption fail'
assert_contains "$out" 'still pass if every function returned nothing'
# FR-20.3 subtract before adding, redesign rather than bolt on; FR-20.5 probe before asking.
git switch -q main && sdd new feature "Planning" >/dev/null 2>&1
out=$(sdd next)
assert_contains "$out" 'Subtract before you add'
assert_contains "$out" 'had the requirement been there from the start'
assert_contains "$out" 'Before writing a question for the human, check whether running something'
exit 0

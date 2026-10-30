# FR-35.3 the plan rules carry the test rules; FR-35.4 the build rules forbid hollow tests,
# expected values taken from the code, and unasked-for code; FR-35.5 the verifier asks, per FR,
# whether some test would fail if it were dropped. FR-36.6 a test-first task can be by: planner.
# FR-39.3 the plan rules fix shared names and pin them by a test.
# FR-41.1 the approval ask is plain, and approve is a command on its own.
. "$SRC/tests/lib.sh"
new_repo

# FR-35.3: plan rules.
sdd new feature "Orders list" >/dev/null 2>&1 || fail "new failed"
out=$(sdd next 2>&1)
assert_contains "$out" 'Phase: plan'
assert_contains "$out" 'The gate (check) stays fast'
assert_contains "$out" "A task's own test may
  be deep (end-to-end, real cost settings): mark it"
assert_contains "$out" 'so
  check.run leaves it out'
assert_contains "$out" 'Make cost settings (hash rounds, timeouts) configurable and minimal
  in tests'
assert_contains "$out" "Each task's test asserts its FR's example literally"
assert_contains "$out" 'A list endpoint gets a test
  that counts its queries'
# FR-36.6: a test-first task can be the planner's.
assert_contains "$out" 'A test-first task can be `by: planner`'
assert_contains "$out" "the planner writes the test that defines done from the FR's example, and the builder
  makes it pass"

# FR-39.3: names several tasks share are fixed in the plan and pinned by a test.
assert_contains "$out" 'Names several tasks share (schema tables and columns, routes, function signatures, file
  paths) are fixed in the plan'
assert_contains "$out" 'pinned by a test in the task that
  first defines them'

# FR-41.1: the approval ask is a plain summary with an ASCII sketch, and approve runs alone.
assert_contains "$out" 'a command on its own'
assert_contains "$out" 'ASCII'
assert_contains "$out" 'a yes in words'
assert_contains "$out" 'never chained to other commands'

# FR-35.4: build rules.
git checkout -q main
planned_item fix "Retry"
out=$(sdd next 2>&1)
assert_contains "$out" 'Phase: build'
assert_contains "$out" 'still pass if every function returned nothing'
assert_contains "$out" 'never from the code under
  test'
assert_contains "$out" 'Write just enough code to pass the test, without abstractions, options or defensive code
  nothing asked for'
assert_not_contains "$out" 'The gate (check) stays fast'

# FR-35.5: the verifier's prompt.
setcfg role.verifier.tier big && setcfg tier.big.agent claude && setcfg tier.big.model opus
out=$(sdd sync claude 2>&1) || fail "sync failed: $out"
v=$(cat .claude/agents/sdd-verifier.md)
assert_contains "$v" 'Per FR, ask: is there a test that would fail if
   that FR were dropped?'
assert_contains "$v" 'or that
   no test would fail if it were dropped'
echo ok

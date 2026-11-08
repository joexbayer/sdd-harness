# FR-35.3 the plan rules carry the test rules; FR-35.4 the build rules forbid hollow tests,
# expected values taken from the code, and unasked-for code; FR-35.5 the verifier asks, per FR,
# whether some test would fail if it were dropped. FR-36.6 a test-first task can be by: planner.
# FR-39.3 the plan rules fix shared names and pin them by a test.
# FR-41.1 the approval ask is plain, and approve is a command on its own.
# FR-42.1 a test's setup tells the right rule from a plausible wrong one; FR-42.2 the verifier runs
# the tests the check leaves out and reports parts nothing calls or reads.
# FR-51.1 hand-offs to the human name the skill first; FR-51.2 so does the AGENTS.md block.
# FR-55.1-55.7 lean prompts: the review shape, big questions first, chat reviews, fewer tests.
. "$SRC/tests/lib.sh"
new_repo

# FR-35.3: plan rules.
sdd new feature "Orders list" >/dev/null 2>&1 || fail "new failed"
out=$(sdd next 2>&1)
assert_contains "$out" 'Phase: plan'
# FR-55.1 the review shape; FR-55.2 big questions first; FR-55.5 test rules; FR-55.7 a loose word ceiling.
assert_contains "$out" 'Critical parts'
assert_contains "$out" 'Assumptions to check'
assert_contains "$out" 'load-bearing questions first'
assert_contains "$out" 'Cases that share one rule share one FR'
w=$(printf '%s\n' "$out" | wc -w | tr -d ' ')
[ "$w" -le 800 ] || fail "plan step is $w words (ceiling 800)"
# One phrase per rule (D-55.1): FR-35.3 test rules, FR-36.6 by: planner, FR-39.3 shared names,
# FR-41.1 the approval ask, FR-42.1 a setup that tells the rules apart; FR-20.3 subtract before
# adding, FR-20.5 probe before asking (were t_discipline.sh).
for p in 'so keep it fast' 'mark deep tests so check.run' 'make cost settings minimal in tests' \
	"asserts its FR's example" 'can be `by: planner`' 'pinned by a test in the task that first defines them' \
	'a command on its own' 'ASCII' 'Only after a yes in' 'never chained to other commands' 'a plausible wrong rule' \
	'Subtract before you add' 'had the requirement been there from the start' \
	'Before writing a question for the human, check whether running something' \
	'how this change can be fully verified' 'flags that can contradict each other become one status' 'write its size in a year' 'no query in a loop (N+1)' 'No cache, queue or new service until a number asks' \
	'A list endpoint gets a test that counts its queries'; do
	assert_contains "$out" "$p"
done

# FR-35.4: build rules.
git checkout -q main
planned_item fix "Retry"
out=$(sdd next 2>&1)
assert_contains "$out" 'Phase: build'
# One phrase per rule: FR-42.2 the verifier hand-off, FR-51.1 the review hand-off names the skill,
# FR-35.4 test rules, FR-55.5 duplicates may go, FR-20.1 stop after two failed fixes, FR-20.2
# tests check behaviour (were t_discipline.sh); FR-55.7 a loose word ceiling.
for p in 'tests the check leaves out' 'nothing calls or reads' 'ready for review: `/sdd-review`' \
	'still pass if every function returned nothing' 'never from the code under test' \
	'After two fixes resting on the same assumption fail' \
	'Write just enough code to pass the test' 'extend an existing test' \
	'a bare ID marks where a requirement lives' 'never repeat one that passed for this code' \
	'Report only commands you ran' 'the control crossed' 'No unbounded list or query'; do
	assert_contains "$out" "$p"
done
assert_contains "$out" "A test that only repeats another's case may be deleted"
assert_not_contains "$out" 'so keep it fast'
w=$(printf '%s\n' "$out" | wc -w | tr -d ' ')
[ "$w" -le 750 ] || fail "build step is $w words (ceiling 750)"

# FR-35.5: the verifier's prompt.
setcfg role.verifier.tier big && setcfg tier.big.agent claude && setcfg tier.big.model opus
out=$(sdd sync claude 2>&1) || fail "sync failed: $out"
v=$(cat .claude/agents/sdd-verifier.md)
# FR-35.5, FR-55.6: the verifier proves an FR by undoing its code; FR-42.2 its other rules.
for p in "undo that FR's code in a scratch copy" 'report the FR unproven if the test still passes' \
	'no test would fail if it were dropped' 'tests the check leaves out' 'nothing calls or reads' \
	"only repeats another" 'a list with no limit, a query inside a loop' 'combinations nothing prevents'; do
	assert_contains "$v" "$p"
done
# FR-51.1: the build skill's hand-off, and the review step's ship hand-off.
assert_contains "$(cat .claude/skills/sdd-build/SKILL.md)" 'Then tell the user it is ready
for review: `/sdd-review` (or `.sdd/bin/sdd review`)'
fill "$ITEM" built
awk '/^## Review/ { print "Verified by: test: 1 of 1 FRs proven; no findings" } { print }' "$ITEM" >"$T/v" && cp "$T/v" "$ITEM"
git add -A && git commit -qm "docs: built" && sdd check >/dev/null 2>&1
out=$(sdd next 2>&1)
assert_contains "$out" 'Phase: review'
assert_contains "$out" 'they run `/sdd-ship` (or `.sdd/bin/sdd ship`)'
# FR-55.3: the review is presented in chat; the human never opens a file.
assert_contains "$out" 'never send the human to read a file'
assert_contains "$(cat .claude/skills/sdd-review/SKILL.md)" 'never send the human to read a file'
# FR-55.4: the AGENTS.md block says be brief.
assert_contains "$(cat AGENTS.md)" 'Never send the human to read a file: summarise it in chat with an example.'
# FR-51.2: the AGENTS.md block init writes.
assert_contains "$(cat AGENTS.md)" '- Handing the human a step: name its skill (`/sdd-new`, `/sdd-review`, `/sdd-ship`) when this
  agent has them (`.sdd/bin/sdd sync <agent>`), with the command as fallback.'
echo ok

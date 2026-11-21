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
[ "$w" -le 820 ] || fail "plan step is $w words (ceiling 820)"
# One phrase per rule (D-55.1): FR-35.3 test rules, FR-36.6 by: planner, FR-39.3 shared names,
# FR-41.1 the approval ask, FR-42.1 a setup that tells the rules apart; FR-20.3 subtract before
# adding, FR-20.5 probe before asking (were t_discipline.sh).
for p in 'so keep it fast' 'mark deep tests so check.run' 'make cost settings minimal in tests' \
	"asserts its FR's example" 'can be `by: planner`' 'pinned by a test in the task that first defines them' \
	'a command on its own' 'ASCII' 'Only after a yes in' 'never chained to other commands' 'a plausible wrong rule' \
	'Subtract before you add' 'had the requirement been there from the start' \
	'Before writing a question for the human, check whether running something' \
	'how this change can be fully verified' 'flags that can contradict each other become one status' 'write its size in a year' 'no query in a loop (N+1)' 'No cache, queue or new service until a number asks' \
	'A list endpoint gets a test that counts its queries' \
	'expect: fail "goldens 0"'; do
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
for p in 'ready for review: `/sdd-review`' \
	'still pass if every function returned nothing' 'never from the code under test' \
	'After two fixes resting on the same assumption fail' \
	'Write just enough code to pass the test' 'extend an existing test' \
	'a bare ID marks where a requirement lives' 'Never re-run a passed check on unchanged code' \
	'Report only commands you ran' 'the control crossed' 'No unbounded list or query'; do
	assert_contains "$out" "$p"
done
# FR-65.4 a wrong test command: stop and ask; FR-65.5 no claim of approval.
# FR-69.5 one stopping rule: hands-off, stop only where a rule says so; no "without questions".
assert_contains "$out" 'stop only where a rule says so'
# One list of stop cases, stated once (the two-failures rule is not a stop).
assert_eq "$(printf '%s\n' "$out" | grep -c 'top and ask')" 1 "(stop cases listed once)"
assert_contains "$out" "Stop and ask the human only when a task's test command proves wrong"
assert_contains "$out" 'a box cannot be ticked'
assert_not_contains "$out" 'stop and write that assumption'
assert_not_contains "$out" 'without questions'
assert_not_contains "$out" 'if truly stuck'
assert_contains "$out" 'voids any approval'
# FR-69.7: no verifier role: the fresh subagent is given the brief by path, not a summary of it.
assert_contains "$out" 'given the item id and the text of .sdd/core/prompts/role-verifier.md
(or .sdd/local/prompts/role-verifier.md, which wins)'
assert_not_contains "$out" 'reports parts nothing calls or reads'
assert_contains "$(cat "$SRC/.sdd/core/prompts/role-verifier.md")" 'in the plan part of the item file'
assert_not_contains "$(cat "$SRC/.sdd/core/prompts/role-verifier.md")" 'under "## What changes"'
# The brief is read raw by the subagent: no unrendered {{ }} in it.
assert_not_contains "$(cat "$SRC/.sdd/core/prompts/role-verifier.md")" '{{'
assert_contains "$out" 'The plan is settled and the human is not watching.'
# FR-67.6 never tick by hand; FR-67.8 ship refuses Verified by: none where the verified gate blocks.
assert_contains "$out" 'ship refuses it where the `verified` gate blocks'
assert_not_contains "$out" 'approved the plan'
assert_contains "$out" "A test that only repeats another's case may be deleted"
assert_not_contains "$out" 'so keep it fast'
# FR-76.2 no flaky workarounds; FR-76.3 act on the tags.
for p in 'rerun' 'sleep' 'delete the test' 'must-fix' 'should-fix' 'pre-existing'; do
	assert_contains "$out" "$p"
done
# Chore 80: targeted tests while building, the full check once at finish.
assert_contains "$out" "Run only the current task's test"
assert_contains "$out" 'once at finish'
# FR-76.3 the verifier tags findings; FR-76.4 a later round checks the earlier fixes first.
for p in 'must-fix' 'should-fix' 'nit' 'pre-existing' 'earlier round'; do
	assert_contains "$(cat "$SRC/.sdd/core/prompts/role-verifier.md")" "$p"
done
w=$(printf '%s\n' "$out" | wc -w | tr -d ' ')
[ "$w" -le 820 ] || fail "build step is $w words (ceiling 820)"

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
# FR-66.5: the docs stage what init made by name, never git add -A.
for d in README.md MIGRATE.md; do
	grep -q 'git add -A' "$SRC/$d" && fail "$d stages with git add -A"
	grep -q '\[ -f .gitleaks.toml \] && git add .gitleaks.toml' "$SRC/$d" || fail "$d leaves .gitleaks.toml unstaged"
	grep -q 'git add .sdd AGENTS.md' "$SRC/$d" || fail "$d does not stage .sdd AGENTS.md by name"
	grep -q '\.gitleaks\.toml' "$SRC/$d" || fail "$d does not name .gitleaks.toml"
done

# FR-69.1: {{if <fact>}} blocks print only when the fact holds for the type; FR-69.2: the type's own
# prompt comes first. No block, no change.
new_repo blocks
mkdir -p .sdd/local/prompts
{
	for f in frs tasks security approval code verify nonsense; do printf '{{if %s}}\nHAS-%s\n{{end}}\n' "$f" "$f"; done
	printf 'ALWAYS\n'
} >.sdd/local/prompts/plan.append.md
printf 'TYPE-FIRST\n' >.sdd/local/prompts/plan.hotfix.md
sdd new hotfix "Down" >/dev/null 2>&1 || fail "new hotfix failed"
out=$(sdd next 2>&1)
for f in frs tasks security approval code verify; do
	case $f in code) assert_contains "$out" "HAS-code" ;; *) assert_not_contains "$out" "HAS-$f" ;; esac
done
assert_not_contains "$out" 'HAS-nonsense'
assert_not_contains "$out" '{{'
assert_contains "$out" 'ALWAYS'
before=${out%%TYPE-FIRST*}
case $before in *'PLAN:'*) fail "type prompt not first: $before" ;; esac
git checkout -q -b other main
printf 'TYPE-FIRST\n' >.sdd/local/prompts/plan.feature.md
sdd new feature "Wide" >/dev/null 2>&1 || fail "new feature failed"
out=$(sdd next 2>&1)
before=${out%%TYPE-FIRST*}
case $out in *TYPE-FIRST*) ;; *) fail "no type prompt: $out" ;; esac
case $before in *'PLAN:'*) fail "feature: type prompt not first: $before" ;; esac
for f in frs tasks security approval code verify; do assert_contains "$out" "HAS-$f"; done
assert_not_contains "$out" 'HAS-nonsense'
git checkout -q -b spike-b main
sdd new spike "Look" >/dev/null 2>&1 || fail "new spike failed"
out=$(sdd next 2>&1)
assert_not_contains "$out" 'HAS-code'
assert_contains "$out" 'HAS-approval'
# FR-69.3: `next` prints only the rules the type uses. Each type, plan and build, as the agent reads it.
new_repo types
typed() { # <type>: plan output in $P, build output in $Bd
	git checkout -q main
	sdd new "$1" "T $1" >/dev/null 2>&1 || fail "new $1 failed"
	P=$(sdd next 2>&1)
	f=$(set -- specs/changes/*-t-"$1"/item.md; echo "$1")
	fill "$f" plan
	git add -A && git commit -qm "docs: plan"
	sdd approve >/dev/null 2>&1
	git add -A && git commit -qm "docs: approve" >/dev/null 2>&1
	Bd=$(sdd next 2>&1)
}
typed hotfix
case $P in *'Hotfix: production is broken: fix first'*) ;; *) fail "hotfix plan: $P" ;; esac
for p in 'write no code' 'FR-' 'Tasks' 'Security' 'approv' 'size:'; do assert_not_contains "$P" "$p"; done
assert_not_contains "$Bd" 'verifier'
assert_contains "$Bd" 'security pass'
assert_not_contains "$Bd" 'sdd approve'
assert_contains "$Bd" 'Never run `.sdd/bin/sdd ship`'
typed chore
assert_not_contains "$Bd" 'sdd approve'
assert_not_contains "$P" 'approve'
assert_not_contains "$P" 'The ask'
assert_contains "$P" '## Security'
assert_not_contains "$Bd" 'verifier'
typed spike
for p in 'Write just enough code' 'security pass' 'verifier' 'Add no dependency' 'Verify with'; do assert_not_contains "$Bd" "$p"; done
assert_contains "$Bd" 'Spike: explore the plan'"'"'s question freely'
for p in 'FR-' '## Tasks' 'size:' '## Security'; do assert_not_contains "$P" "$p"; done
typed roadmap
assert_not_contains "$Bd" 'file:line'
for p in 'Write just enough code' 'security pass' 'verifier' 'Verify with'; do assert_not_contains "$Bd" "$p"; done
for p in 'FR-' '## Tasks' 'size:' '## Security'; do assert_not_contains "$P" "$p"; done
typed refactor
for p in 'FR-' '## Tasks' 'size:' '## Security'; do assert_not_contains "$P" "$p"; done
assert_contains "$Bd" 'stop and ask the human: the change is not a pure refactor'
assert_contains "$Bd" 'verifier'
assert_contains "$Bd" 'stop only where a rule says so'
typed contract
assert_not_contains "$Bd" 'verifier'
for p in 'Write just enough code' 'Add no dependency' 'No unbounded list'; do assert_not_contains "$Bd" "$p"; done
assert_contains "$Bd" 'Write "## Built"'
assert_contains "$Bd" 'Contract: write the files'
typed fix
assert_contains "$P" 'skip the regression task'
assert_contains "$Bd" 'none when "## Test" starts with `none:`'
assert_contains "$P" 'Scale: for each table'
assert_contains "$Bd" 'verifier'
typed feature
assert_contains "$P" 'size:'
assert_contains "$P" 'Each mitigation is an FR'
assert_contains "$Bd" 'security pass'
assert_contains "$Bd" 'Say it per FR'
assert_contains "$Bd" "never bend the test to fit"
assert_contains "$Bd" 'never tick one by hand; the human may waive it'
assert_contains "$Bd" 'Never run `.sdd/bin/sdd approve`'
typed amendment
for p in 'Write just enough code' 'Add no dependency' 'No unbounded list'; do assert_not_contains "$Bd" "$p"; done
assert_contains "$Bd" 'Amendment: edit specs/constitution.md'

# FR-69.12: with no item open, every type is offered; the new skill also offers roadmap.
new_repo none
sdd sync claude >/dev/null 2>&1
out=$(sdd next 2>&1)
assert_contains "$out" 'amendment change a constitution rule (specs/constitution.md)'
assert_contains "$out" 'contract  change an interface items build against'
assert_contains "$(cat .claude/skills/sdd-new/SKILL.md)" 'amendment
   (change a constitution rule), contract (change an interface items build against), roadmap'
# FR-69.13: the Review section reads the same in templates, review prompt and review skill.
sdd new feature "Wording" >/dev/null 2>&1 || fail "new failed"
assert_contains "$(cat specs/changes/*-wording/item.md)" 'to change, one per line (the agent writes what the human asks)'
assert_not_contains "$(cat specs/changes/*-wording/item.md)" "The human's review notes"
rv=$(cat .claude/skills/sdd-review/SKILL.md)
assert_contains "$rv" 'say under Built
what you changed'
assert_contains "$rv" 'call out every deviation, risk and doubt'
assert_contains "$rv" 'write what they ask under "## Review"'
assert_contains "$(cat .sdd/core/prompts/review.md)" 'write what they ask under "## Review"'
echo ok

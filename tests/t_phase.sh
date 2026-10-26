# FR-1.5 phases plan → build → review, FR-1.6 next prompts (with local overrides),
# FR-1.7 check, FR-1.13 approve pins the plan.
. "$SRC/tests/lib.sh"
new_repo

sdd new feature "Device login" >/dev/null 2>&1 || fail "new failed"
f=specs/changes/1-device-login/item.md

out=$(sdd status)
assert_contains "$out" 'phase   plan'
assert_contains "$out" 'to fill: Why, What changes, How, Done when'
out=$(sdd next)
assert_contains "$out" 'PLAN: this is the human'"'"'s time'
assert_contains "$out" 'FR-1.1'
sdd approve >/dev/null 2>&1
assert_eq $? 1 "(approve refuses an incomplete plan)"

fill "$f" plan
awk '{ print } /^## What changes$/ { print "FR-1.1 WHEN asked THE SYSTEM SHALL log in."; print "FR-1.2 WHEN idle THE SYSTEM SHALL log out." }' "$f" >"$T/plan.md" && cp "$T/plan.md" "$f"
assert_contains "$(sdd status)" 'waiting for the human to approve'
out=$(sdd approve) || fail "approve failed: $out"
assert_contains "$out" 'approved by test'
assert_eq "$(git log -1 --format=%s)" 'docs(1): approve plan'
assert_contains "$(cat "$f")" 'approved: '
assert_contains "$(sdd status)" 'phase   build'
out=$(sdd next)
assert_contains "$out" 'BUILD: this is your time'

# Editing the plan after approval sends it back to the human; reverting restores it.
cp "$f" "$T/approved.md"
awk '{ print } /^## How$/ { print "A new idea after approval." }' "$T/approved.md" >"$f"
assert_contains "$(sdd status)" 'the plan changed after approval'
cp "$T/approved.md" "$f"
assert_contains "$(sdd status)" 'phase   build'

# Check passes → still build until "## Built" is written; writing it does not void the check.
out=$(sdd check) || fail "check should pass: $out"
assert_contains "$out" 'check passed for item 1'
assert_contains "$(sdd status)" '"## Built" is not written yet'
# The human's review notes are not the agent's write-up.
awk '{ print } /^## Review/ { print "Rename the flag." }' "$f" >"$T/rev.md" && cp "$T/rev.md" "$f"
assert_contains "$(sdd status)" '"## Built" is not written yet'
assert_contains "$(sdd review)" 'Rename the flag.'
# An agent's own "## " headings inside Built are part of Built, not new sections.
cp "$f" "$T/before-built.md"
awk '{ print } /^## Built$/ { print "## Changes made:"; print "Added the login form." }' "$f" >"$T/b.md" && cp "$T/b.md" "$f"
assert_contains "$(sdd status)" 'phase   review'
assert_contains "$(sdd review)" 'Added the login form.'
cp "$T/before-built.md" "$f"
fill "$f" built
out=$(sdd status)
assert_contains "$out" 'phase   review'
assert_contains "$(sdd next)" 'REVIEW: this is the human'"'"'s time again'
echo change >>README.md
assert_contains "$(sdd status)" 'no passing check for the current code'
git checkout -q README.md

# review: walkthrough with plan, check, FR → where it is named.
echo 'x // FR-1.1' >code.txt
sdd check >/dev/null 2>&1
out=$(sdd review)
assert_contains "$out" 'plan    approved'
assert_contains "$out" 'check   ✓ passed'
assert_contains "$out" 'untracked: code.txt'
assert_contains "$out" 'FR-1.1     code.txt:1'
assert_contains "$out" 'FR-1.2     ✗ not named anywhere'
assert_contains "$out" 'ship does not check it'
assert_contains "$out" 'Filled in by the test (built).'
rm code.txt

# Failing check: exit 1. Zero tests: exit 3. Masked failure: refused. Stdin is closed,
# so a command that reads it cannot swallow the remaining checks.
git config -f .sdd/config --replace-all check.run 'echo boom; exit 4'
out=$(sdd check 2>&1)
assert_eq $? 1
assert_contains "$out" 'rules for this step: .sdd/bin/sdd next'
# A check that writes into the tree says so instead of claiming the next step.
git config -f .sdd/config --replace-all check.run 'echo ok >out.txt'
out=$(sdd check 2>&1)
assert_eq $? 0
assert_contains "$out" 'the check itself created or changed files'
assert_contains "$out" '    out.txt'
rm -f out.txt
# A check that cannot start is a config problem, and says so.
git config -f .sdd/config --replace-all check.run 'no-such-tool -q'
out=$(sdd check 2>&1)
assert_eq $? 1
assert_contains "$out" 'could not run `no-such-tool -q`'
assert_contains "$out" "fix 'run' under [check] in .sdd/config"
git config -f .sdd/config --replace-all check.run 'echo "collected 0 items"'
sdd check >/dev/null 2>&1
assert_eq $? 3
git config -f .sdd/config --replace-all check.run 'echo "10 examples, 0 failures"'
sdd check >/dev/null 2>&1
assert_eq $? 0 "(10 examples is not zero tests)"
git config -f .sdd/config --replace-all check.run 'echo "running 0 tests"; echo "running 12 tests"'
sdd check >/dev/null 2>&1
assert_eq $? 0 "(cargo doc-tests print running 0 tests in healthy runs)"
git config -f .sdd/config --replace-all check.run 'read -r x; echo first'
git config -f .sdd/config --add check.run 'echo second; exit 1'
sdd check >/dev/null 2>&1
assert_eq $? 1 "(the second check must still run)"
git config -f .sdd/config --replace-all check.run 'make test || true'
out=$(sdd check 2>&1)
assert_eq $? 1
assert_contains "$out" 'hides failures'
git config -f .sdd/config --replace-all check.run 'echo ok'

# local/ overrides and extends core prompts.
echo change >>README.md
mkdir -p .sdd/local/prompts
echo "Team rule: pair on every feature." >.sdd/local/prompts/build.append.md
assert_contains "$(sdd next)" 'Team rule: pair on every feature.'
echo "Replaced." >.sdd/local/prompts/build.md
out=$(sdd next)
assert_contains "$out" 'Replaced.'
assert_not_contains "$out" 'BUILD: this is your time'
exit 0

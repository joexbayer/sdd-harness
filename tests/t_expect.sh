# FR-22.1 expect: fail "<text>": a test written first counts as red only when its output says why
# it should fail; plain expect: fail keeps the old rule.
. "$SRC/tests/lib.sh"
new_repo

sdd new feature "Word frequencies" >/dev/null 2>&1
f=specs/changes/1-word-frequencies/item.md
fill "$f" plan
awk '/^## What changes$/ { print; print "FR-1.1 WHEN a text is given THE SYSTEM SHALL count its words."; print "  e.g. \"a b a\" → a 2, b 1"; print ""; next }
/^## Tasks \(optional\)$/ { print
	print "- [ ] T-1.1 Count test first, FR-1.1 (files: t1.sh; test: sh t1.sh; expect: fail \"wordfreq: not found\")"
	print "- [ ] T-1.2 Plain red test, FR-1.1 (files: t2.sh; test: sh t2.sh; expect: fail)"
	print "- [ ] T-1.3 Count words, FR-1.1 (files: wf.sh; test: sh t1.sh)"
	print "- [ ] T-1.4 Odd reason, FR-1.1 (files: t4.sh; test: sh t4.sh; expect: fail \"$(rm -f ran) `touch ran` ; x\")"
	print ""; next } { print }' "$f" >"$T/f" && cp "$T/f" "$f"
git commit -qam "docs(1): plan with tasks"

# FR-22.1: the plan check reads the quoted form; a malformed one is unreadable, not guessed.
out=$(sdd analyze 2>&1)
assert_not_contains "$out" 'T-1.1'
assert_not_contains "$out" 'cannot read'
cp "$f" "$T/item.bak"
sed 's/expect: fail)/expect: fail wrongly)/' "$T/item.bak" >"$f"
out=$(sdd analyze 2>&1)
assert_contains "$out" 'T-1.2'
assert_contains "$out" 'expect must be fail or fail "<text>", not fail wrongly'
cp "$T/item.bak" "$f"
sdd approve >/dev/null 2>&1 || fail "approve failed"

# FR-22.1: sdd task, sdd task next and sdd next show the expected text.
assert_contains "$(sdd task)" 'test: sh t1.sh (expect: fail "wordfreq: not found")'
assert_contains "$(sdd task)" 'test: sh t2.sh (expect: fail)'
assert_contains "$(sdd task next)" 'test: sh t1.sh (expect: fail "wordfreq: not found")'
assert_contains "$(sdd next)" 'it must fail with "wordfreq: not found" in its output'

# FR-22.1: failing for another reason (a typo) is not red: not ticked.
printf 'echo "syntax error near unexpected token"\nexit 2\n' >t1.sh
out=$(sdd task 'done' T-1.1 2>&1)
assert_eq $? 1 "(wrong reason)"
assert_contains "$out" '✗ T-1.1 failed, but not for the expected reason (wordfreq: not found)'
grep -q '^- \[ \] T-1.1 ' "$f" || fail "a red test failing for the wrong reason must stay unticked"

# FR-22.1: failing with the expected text ticks it.
printf 'sh wf.sh 2>/dev/null || { echo "wordfreq: not found"; exit 1; }\n' >t1.sh
out=$(sdd task 'done' T-1.1 2>&1) || fail "red task with the expected text failed: $out"
assert_contains "$out" '✓ T-1.1 done (its test fails, as expected: wordfreq: not found)'
grep -q '^- \[x\] T-1.1 ' "$f" || fail "T-1.1 not ticked"
git add -A && git commit -qm "test(1): T-1.1 count test first"

# FR-22.1: plain expect: fail keeps today's rule: any failure counts.
printf 'echo "syntax error"\nexit 2\n' >t2.sh
out=$(sdd task 'done' T-1.2 2>&1) || fail "plain red task failed: $out"
assert_contains "$out" '✓ T-1.2 done (its test fails, as expected)'
git add -A && git commit -qm "test(1): T-1.2 plain red test"

printf 'echo "a 2"\n' >wf.sh
out=$(sdd task 'done' T-1.3 2>&1) || fail "T-1.3 failed: $out"
git add -A && git commit -qm "feat(1): T-1.3 count words"

# FR-22.1: a passing test is still refused, text or not.
printf 'echo "wordfreq: not found"\nexit 0\n' >t4.sh
out=$(sdd task 'done' T-1.4 2>&1)
assert_eq $? 1 "(passing red test)"
assert_contains "$out" 'expected its test to fail, but it passed'
# FR-22.1: the text goes to grep -F as an argument: shell syntax in it never runs.
printf 'echo "wrong"\nexit 1\n' >t4.sh
out=$(sdd task 'done' T-1.4 2>&1)
assert_eq $? 1 "(text with shell syntax, not in the output)"
assert_contains "$out" 'not for the expected reason ($(rm -f ran) `touch ran` ; x)'
assert_no_file ran
printf "echo '\$(rm -f ran) \`touch ran\` ; x'\nexit 1\n" >t4.sh
out=$(sdd task 'done' T-1.4 2>&1) || fail "red task with shell syntax in its text failed: $out"
assert_contains "$out" '✓ T-1.4 done'
assert_no_file ran

# A test written first ends its batch: the code that turns it green is in the next batch, so the
# builder ticks it while it is still red.
git add -A && git commit -qm "feat(1): T-1.4 odd reason" && git switch -q main
sdd new feature "Batches" >/dev/null 2>&1
f=specs/changes/2-batches/item.md
fill "$f" plan
awk '/^## What changes$/ { print; print "FR-2.1 WHEN x THE SYSTEM SHALL y."; print "  e.g. x → y"; print ""; next }
/^## Tasks \(optional\)$/ { print
	print "- [ ] T-2.1 Red first, FR-2.1 (files: r1.sh; test: sh r1.sh; expect: fail; size: S)"
	print "- [ ] T-2.2 Code (test: true; size: S)"
	print "- [ ] T-2.3 More code (test: true; size: S)"
	print "- [ ] T-2.4 Red again (files: r4.sh; test: sh r4.sh; expect: fail \"red\"; size: S)"
	print "- [ ] T-2.5 Its code (test: true; size: S)"
	print ""; next } { print }' "$f" >"$T/f" && cp "$T/f" "$f"
git commit -qam "docs(2): plan" && sdd approve >/dev/null 2>&1 || fail "approve 2 failed"
out=$(sdd task next)
assert_contains "$out" 'batch   T-2.1'
assert_not_contains "$out" 'T-2.2'
printf 'echo red\nexit 1\n' >r1.sh
sdd task 'done' T-2.1 >/dev/null 2>&1 || fail "T-2.1 failed"
out=$(sdd task next)
assert_contains "$out" 'batch   T-2.2 T-2.3 T-2.4'
assert_not_contains "$out" 'T-2.5'

# FR-31.2: a small builder writes a test and its code together, so the test passes. With other
# uncommitted changes, task done runs it again in a throwaway checkout of HEAD with only the task's
# files: failing there is red. The working tree is left as it was, the checkout removed.
git add -A && git commit -qm "feat(2): batches" && git switch -q main
sdd new feature "Red without code" >/dev/null 2>&1
f=specs/changes/3-red-without-code/item.md
fill "$f" plan
awk '/^## What changes$/ { print; print "FR-3.1 WHEN x THE SYSTEM SHALL y."; print "  e.g. x → y"; print ""; next }
/^## Tasks \(optional\)$/ { print
	print "- [ ] T-3.1 Api test, FR-3.1 (files: tests3/t31.sh; test: sh tests3/t31.sh; expect: fail \"api: missing\")"
	print "- [ ] T-3.2 Vacuous test (files: t32.sh; test: sh t32.sh; expect: fail)"
	print "- [ ] T-3.3 Late test (files: t33.sh; test: sh t33.sh; expect: fail)"
	print ""; next } { print }' "$f" >"$T/f" && cp "$T/f" "$f"
git commit -qam "docs(3): plan" && sdd approve >/dev/null 2>&1 || fail "approve 3 failed"
mkdir -p "$T/tmp" tests3
red() { (export TMPDIR="$T/tmp"; sdd task 'done' "$1" 2>&1); }
clean_after() {
	[ -z "$(ls "$T/tmp")" ] || fail "the throwaway checkout was left in TMPDIR $1: $(ls "$T/tmp")"
	assert_eq "$(git worktree list | wc -l | tr -d ' ')" 1 "(worktrees left $1)"
}

# FR-31.3: passing without the uncommitted code too means the test does not test the change.
echo 'exit 0' >t32.sh
echo 'code' >other.txt
out=$(red T-3.2)
assert_eq $? 1 "(a test that passes without the code)"
assert_contains "$out" '✗ T-3.2 expected its test to fail, but it passes even without the uncommitted code: the test does not test the change; fix the test'
grep -q '^- \[ \] T-3.2 ' "$f" || fail "T-3.2 ticked"
clean_after "(refused)"
rm -f other.txt t32.sh

# FR-31.2: failing without the code, but not for the plan's reason, is not red.
printf 'sh api.sh 2>/dev/null && exit 0\necho boom\nexit 1\n' >tests3/t31.sh
echo 'echo api ok' >api.sh
echo changed >README.md
before=$(git status --porcelain)
out=$(red T-3.1)
assert_eq $? 1 "(red without the code, wrong reason)"
assert_contains "$out" '✗ T-3.1 failed without the uncommitted code, but not for the expected reason (api: missing)'
clean_after "(wrong reason)"

# FR-31.2: failing without the code for the plan's reason ticks it; the tree is untouched.
printf 'sh api.sh 2>/dev/null && exit 0\necho "api: missing"\nexit 1\n' >tests3/t31.sh
before=$(git status --porcelain | grep -v "$f")
out=$(red T-3.1) || fail "red without the code failed: $out"
assert_contains "$out" '✓ T-3.1 done (its test fails without the uncommitted code: api: missing)'
grep -q '^- \[x\] T-3.1 ' "$f" || fail "T-3.1 not ticked"
assert_eq "$(git status --porcelain | grep -v "$f")" "$before" "(the working tree changed)"
assert_eq "$(cat api.sh)" 'echo api ok' "(api.sh)"
assert_eq "$(cat README.md)" changed "(README.md)"
clean_after "(ticked)"
git add -A && git commit -qm "feat(3): T-3.1 api test"

# FR-31.3: with the code already committed there is nothing to take away: refused, saying why.
echo 'sh api.sh' >t33.sh
out=$(red T-3.3)
assert_eq $? 1 "(code already committed)"
assert_contains "$out" '✗ T-3.3 expected its test to fail, but it passed: the code is already committed'
grep -q '^- \[ \] T-3.3 ' "$f" || fail "T-3.3 ticked"
clean_after "(committed)"
echo ok

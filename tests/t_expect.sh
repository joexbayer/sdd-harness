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
echo ok

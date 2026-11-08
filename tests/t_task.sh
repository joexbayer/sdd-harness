# FR-15.1 task attributes, FR-15.2 task done runs the task's test and ticks it, FR-15.3 refusals,
# FR-15.4 ticks do not void approval, FR-15.5 the current task in the phase and next, FR-15.6
# sdd task lists tasks and their commits, FR-15.7 ship's drift check and tasks gate, FR-15.8 the
# template and plan prompt ask for tasks. FR-51.3 task done and review show a committed tick no
# commit names; FR-51.4 not before the commit, nor for a named one. FR-58.1-58.3 a planner's test
# changed later is shown in review and refused at ship, unless Built names the file.
. "$SRC/tests/lib.sh"
new_repo

sdd new feature "Orders paging" >/dev/null 2>&1
f=specs/changes/1-orders-paging/item.md
fill "$f" plan
# FR-15.8: the template has a Tasks section and the plan prompt asks for small tasks.
grep -q '^## Tasks (optional)$' "$f" || fail "feature template has no Tasks section"
assert_contains "$(sdd next)" 'End the plan with small, ordered tasks'
awk '/^## What changes$/ { print; print "FR-1.1 WHEN a page is asked for THE SYSTEM SHALL return 20 orders."; print "  e.g. page 2 → orders 21-40"; next }
/^## Tasks \(optional\)$/ { print
	print "- [ ] T-1.1 Page test first, FR-1.1 (files: t1.sh; test: sh t1.sh; expect: fail)"
	print "- [ ] T-1.2 Page the orders query, FR-1.1 (files: q.sh; test: sh t1.sh && echo ran >ran.txt)"
	print "- [ ] T-1.3 Docs (files: README.md)"; print ""; next } { print }' "$f" >"$T/f" && cp "$T/f" "$f"
git commit -qam "docs(1): plan with tasks"

# FR-15.1, FR-15.6: sdd task lists each task with its test and whether a commit names it.
out=$(sdd task)
assert_contains "$out" '[ ] T-1.1 Page test first'
assert_contains "$out" 'test: sh t1.sh (expect: fail)'
assert_contains "$out" 'serves: FR-1.1'
assert_contains "$out" 'no commit names it yet'

# FR-15.3: before approval nothing runs.
out=$(sdd task 'done' T-1.2 2>&1)
assert_eq $? 1 "(not approved)"
assert_contains "$out" 'not approved'
assert_no_file ran.txt
sdd approve >/dev/null 2>&1 || fail "approve failed"
sdd task 'done' T-9.9 >/dev/null 2>&1
assert_eq $? 1 "(unknown task)"

# FR-15.5: the phase names the current task; next shows it first, with the FR and its example.
assert_contains "$(sdd status)" 'task T-1.1 of 3: Page test first'
out=$(sdd next)
assert_contains "$out" 'Current task: T-1.1 Page test first'
assert_contains "$out" 'FR-1.1 WHEN a page is asked for THE SYSTEM SHALL return 20 orders.'
assert_contains "$out" 'e.g. page 2 → orders 21-40'
assert_contains "$out" 'write the test first: it must fail'
assert_contains "$out" '.sdd/bin/sdd task 'done' T-1.1'

# FR-15.2: expect: fail ticks only when the test fails; then a normal task must pass.
echo 'exit 0' >t1.sh
out=$(sdd task 'done' T-1.1 2>&1)
assert_eq $? 1 "(a red task whose test passes)"
assert_contains "$out" 'expected its test to fail'
echo 'grep -q page q.sh 2>/dev/null; r=$?; echo goldens 0; exit $r' >t1.sh
out=$(sdd task 'done' T-1.1 2>&1) || fail "red task failed: $out"
# FR-65.2: no expected text: the red run's last line is shown, with a note.
assert_contains "$out" '  red for: goldens 0 (no expected text: check this is the bug)'
assert_contains "$out" '✓ T-1.1 done (its test fails, as expected)'
assert_contains "$out" 'commit with: feat(1): T-1.1 Page test first'
grep -q '^- \[x\] T-1.1 ' "$f" || fail "T-1.1 not ticked"
# FR-15.4: the tick did not void the approval.
assert_not_contains "$(sdd status)" 'changed after approval'
git add -A && git commit -qm "test(1): T-1.1 page test first"
out=$(sdd task 'done' T-1.2 2>&1)
assert_eq $? 1 "(failing test)"
grep -q '^- \[ \] T-1.2 ' "$f" || fail "a failing task must stay unticked"
echo page >q.sh
# FR-65.1: the line is shown as the test printed it: backslashes kept, a NUL byte dropped.
cat >t1.sh <<'EOF'
grep -q page q.sh || exit 1
printf 'C:\\new \\c x\000y\n'
EOF
out=$(sdd task 'done' T-1.2 2>&1) || fail "T-1.2 failed: $out"
assert_contains "$out" '✓ T-1.2 done (its test passed)'
# FR-65.1: a pass shows the last line of the test's output.
assert_contains "$out" '  last line: C:\new \c xy'
assert_contains "$out" "$(printf '\nnext    commit the code')"
assert_file ran.txt
rm ran.txt
sdd task 'done' T-1.2 >/dev/null 2>&1
assert_eq $? 1 "(already ticked)"
assert_contains "$(sdd status)" 'task T-1.3 of 3: Docs'

# FR-15.7: a tick no commit names is refused at ship, in lite too.
fill "$f" built && git add -A && git commit -qm "docs(1): built"
# FR-51.3: committed under a subject that does not name it: said in review, before ship.
# FR-51.4: T-1.1, named in its own commit, is not listed.
line='⚠ ticked and committed, but no commit subject names them: T-1.2. Ship refuses this: name each task ID in a commit subject (amend that commit while it is the last one).'
assert_contains "$(sdd review 2>&1)" "$line"
out=$(sdd ship 2>&1)
assert_eq $? 1 "(ticked, unnamed)"
assert_contains "$out" 'ticked, but no commit names them: T-1.2'
git commit -q --amend -m "feat(1): T-1.2 page the orders query, and Built"
assert_contains "$(sdd task)" "commit $(git rev-parse --short HEAD)"
assert_not_contains "$(sdd task)" "$(git rev-parse --short HEAD)$(git rev-parse --short HEAD)"

# FR-15.2 (no test: the check runs), FR-15.7 (the tasks gate): standard blocks open tasks.
setcfg sdd.profile standard
out=$(sdd ship 2>&1)
assert_eq $? 1 "(open task in standard)"
assert_contains "$out" 'tasks not done: T-1.3'
out=$(sdd task 'done' T-1.3 2>&1) || fail "T-1.3 failed: $out"
assert_contains "$out" '✓ T-1.3 done (the check passed)'
git commit -qam "docs(1): T-1.3 docs"
out=$(sdd ship 2>&1) || fail "ship failed: $out"
assert_contains "$out" 'shipped 1 into main'

# Review cases, on a second item (standard profile from above).
# This plan is meant to reach the build with a task sdd cannot read (T-2.3), which the analyzed
# gate (FR-19.2) blocks at approve in standard: let it only warn here.
setcfg profile.standard.analyzed warn
sdd new feature "Hard cases" >/dev/null 2>&1
f=specs/changes/2-hard-cases/item.md
fill "$f" plan
awk '/^## Tasks \(optional\)$/ { print
	print "```"; print "- [ ] T-2.1 an example in a fence"; print "```"
	print "- [ ] T-2.1 Red first (files: t2.sh; test: sh other.sh; expect: fail)"
	print "- [ ] T-2.2 Hides failures (test: false || true)"
	print "- [ ] T-2.3 Wrapped (test: true)"; print "  and more words"
	print "- [ ] T-2.4 Plain (test: true)"; print ""; next } { print }' "$f" >"$T/f" && cp "$T/f" "$f"
git commit -qam "docs(2): plan" && sdd approve >/dev/null 2>&1 || fail "approve 2 failed"
# FR-15.2: a red task's files must exist, and a red test that ran no tests is not red.
assert_contains "$(sdd task 'done' T-2.1 2>&1)" 't2.sh (in files:) does not exist yet'
printf 'echo "No tests found"\nexit 1\n' >other.sh
echo x >t2.sh
assert_contains "$(sdd task 'done' T-2.1 2>&1)" 'its test ran no tests'
# FR-15.2: a test that hides failures, and attributes that do not end the line, are refused.
assert_contains "$(sdd task 'done' T-2.2 2>&1)" 'its test hides failures'
assert_contains "$(sdd task 'done' T-2.3 2>&1)" 'its attributes must end its line'
# The fenced example is never ticked; the real line is.
sdd task 'done' T-2.4 >/dev/null 2>&1 || fail "T-2.4 failed"
grep -q '^- \[x\] T-2.4 ' "$f" || fail "T-2.4 not ticked"
git add -A && git commit -qm "feat(2): T-2.4 plain"
# FR-15.7: a tick by hand is refused at ship, even with a commit naming it.
sed 's/^- \[ \] T-2.1 Red/- [x] T-2.1 Red/' "$f" >"$T/f" && cp "$T/f" "$f"
grep -c '^- \[ \] T-2.1 an example' "$f" >/dev/null || fail "the fenced example changed"
fill "$f" built && git commit -qam "feat(2): T-2.1 red first, by hand"
assert_contains "$(sdd ship 2>&1)" 'ticked without .sdd/bin/sdd task done: T-2.1'
# A teammate's tick was proven on their machine: only the commit is asked for.
git commit -q --amend --author="kari <kari@example.com>" --no-edit
out=$(sdd ship 2>&1)
assert_not_contains "$out" 'ticked without'
assert_contains "$out" 'tasks not done: T-2.2, T-2.3'
# FR-15.4: any other plan edit still voids the approval.
sed 's/^- \[ \] T-2.2 Hides failures/- [ ] T-2.2 Hides nothing/' "$f" >"$T/f" && cp "$T/f" "$f"
assert_contains "$(sdd status)" 'changed after approval'
# FR-36.1: `by: <role>` names the role that builds a task; task next and next show it after size,
# a task without it reads as before, and a role that is not a lowercase word is refused.
git commit -qam "docs(2): hides nothing" && git switch -q main
sdd new feature "Login" >/dev/null 2>&1
f=specs/changes/3-login/item.md
fill "$f" plan
awk '/^## What changes$/ { print; print "FR-3.1 WHEN a user logs in THE SYSTEM SHALL greet them."; print "  e.g. login ann → hi ann"; next }
/^## Tasks \(optional\)$/ { print
	print "- [ ] T-3.1 Login test, FR-3.1 (files: tests/test_login.py; test: pytest -q tests/test_login.py; expect: fail; size: S; by: planner)"
	print "- [ ] T-3.2 Login, FR-3.1 (test: true; size: S)"
	print "- [ ] T-3.3 Shout (test: true; size: S; by: Planner!)"; print ""; next } { print }' "$f" >"$T/f" && cp "$T/f" "$f"
git commit -qam "docs(3): plan" && sdd approve >/dev/null 2>&1 || fail "approve 3 failed"
out=$(sdd task next)
assert_contains "$out" '[ ] T-3.1 Login test (size: S; by: planner)'
assert_contains "$out" 'test: pytest -q tests/test_login.py (expect: fail)'
assert_contains "$(sdd next)" '  by      planner'
out=$(sdd task 'done' T-3.3 2>&1)
assert_eq $? 1 "(by: not a role)"
assert_contains "$out" 'T-3.3: by: must be a role name (a lowercase word)'
# Without by: the line is as before.
sed 's/^- \[ \] T-3.1 /- [x] T-3.1 /' "$f" >"$T/f" && cp "$T/f" "$f"
out=$(sdd task next)
assert_contains "$out" '[ ] T-3.2 Login (size: S)
'

# FR-51.3: the next task done says when the last batch's commit did not name its task;
# FR-51.4: the tick just made (not committed yet) is not listed.
new_repo unnamed
sdd new feature "Batch" >/dev/null 2>&1
f=specs/changes/1-batch/item.md
fill "$f" plan
awk '/^## Tasks \(optional\)$/ { print; print "- [ ] T-1.1 One (test: true)"; print "- [ ] T-1.2 Two (test: true)"; print ""; next } { print }' "$f" >"$T/f" && cp "$T/f" "$f"
git commit -qam "docs(1): plan" && sdd approve >/dev/null 2>&1 || fail "approve failed"
out=$(sdd task 'done' T-1.1 2>&1) || fail "T-1.1 failed: $out"
assert_not_contains "$out" 'no commit subject names them'
git add -A && git commit -qm "feat(1): the batch"
out=$(sdd task 'done' T-1.2 2>&1) || fail "T-1.2 failed: $out"
assert_contains "$out" '⚠ ticked and committed, but no commit subject names them: T-1.1. Ship refuses this'

# FR-58.1: a planner's test, changed after it was written, is shown in review and refused at ship.
new_repo bent
sdd new feature "Paging" >/dev/null 2>&1
f=specs/changes/1-paging/item.md
fill "$f" plan
awk '/^## Tasks \(optional\)$/ { print
	print "- [ ] T-1.1 Page test, FR-1.1 (files: t1.sh; test: sh t1.sh; expect: fail; size: S; by: planner)"
	print "- [ ] T-1.2 Page, FR-1.1 (files: q.sh; test: sh t1.sh; size: S)"
	print "- [ ] T-1.3 Own test (files: b.sh; test: sh b.sh; size: S)"; print ""; next } { print }' "$f" >"$T/f" && cp "$T/f" "$f"
git commit -qam "docs(1): plan" && sdd approve >/dev/null 2>&1 || fail "approve failed"
echo 'grep -q page q.sh' >t1.sh && sdd task 'done' T-1.1 >/dev/null 2>&1 && git add -A && git commit -qm "test(1): T-1.1 page test" || fail "T-1.1 failed"
echo page >q.sh && sdd task 'done' T-1.2 >/dev/null 2>&1 && git add -A && git commit -qm "feat(1): T-1.2 page" || fail "T-1.2 failed"
echo 'exit 0' >b.sh && sdd task 'done' T-1.3 >/dev/null 2>&1 && git add -A && git commit -qm "test(1): T-1.3 own test" || fail "T-1.3 failed"
# Must not change: the builder may change its own test later.
echo '# tidied' >>b.sh && git commit -qam "fix(1): T-1.3 tidy own test"
fill "$f" built && git commit -qam "docs(1): built"
assert_not_contains "$(sdd review 2>&1)" 'written by the planner'
# The planner's test is bent.
echo 'exit 0' >t1.sh && git commit -qam "fix(1): T-1.2 make it pass"
line='item 1: T-1.1'"'"'s test t1.sh (written by the planner) changed after it was written: undo it, or say why under "## Built" naming the file'
assert_contains "$(sdd review 2>&1)" "⚠ $line"   # FR-58.3
out=$(sdd ship 2>&1)
assert_eq $? 1 "(a bent planner test must not ship)"
assert_contains "$out" "$line"
# FR-58.2: Built names the file and says why: ship goes on.
awk '/^## Review/ { print "- t1.sh: the planner sample was wrong (no page check needed)." } { print }' "$f" >"$T/f" && cp "$T/f" "$f"
git commit -qam "docs(1): say why t1.sh changed"
out=$(sdd ship 2>&1)
assert_not_contains "$out" 'written by the planner'

# FR-67.1-67.4, 67.7: a waiver ticks a task the human cannot run, and says so.
new_repo waive
sdd new feature "Waivers" >/dev/null 2>&1
f=specs/changes/1-waivers/item.md
fill "$f" plan
awk '/^## Tasks \(optional\)$/ { print
	print "- [ ] T-1.1 Waived (files: tests/x.sh, .args; test: true)"
	print "- [ ] T-1.2 Ticked by hand (test: true)"
	print "- [ ] T-1.3 Normal (test: true)"; print ""; next } { print }' "$f" >"$T/f" && cp "$T/f" "$f"
git commit -qam "docs(1): plan" && sdd approve >/dev/null 2>&1 || fail "approve failed"
# FR-67.7: a suffix typed as a file warns on the current item, exit 0, no plan finding.
out=$(sdd analyze 2>&1)
assert_eq $? 0 "(analyze warns, does not fail)"
assert_contains "$out" 'T-1.1 files: .args looks like a suffix, not a path'
assert_not_contains "$(sdd analyze 1 2>&1)" 'looks like a suffix'
touch .args
assert_not_contains "$(sdd analyze 2>&1)" 'looks like a suffix'
rm .args
# FR-67.4: no reason, an unknown task, a reason with a newline.
out=$(sdd task waive T-1.1 "" 2>&1)
assert_eq $? 1 "(empty reason)"
assert_contains "$out" 'a waiver needs a reason'
sdd task waive T-9.9 "why" >/dev/null 2>&1
assert_eq $? 1 "(unknown task)"
sdd task waive T-1.1 "one
two" >/dev/null 2>&1
assert_eq $? 1 "(newline)"
assert_not_contains "$(cat "$f")" '## Waived'
# FR-67.1: the box is ticked, the reason, who and when recorded; nothing is committed.
head=$(git rev-parse HEAD)
r='files: had a typo; test passes on main \n $(touch pwned) & `x` \1'
sdd task waive T-1.1 "$r" >/dev/null 2>&1 || fail "waive failed"
assert_eq "$(git rev-parse HEAD)" "$head" "(no commit)"
grep -q '^- \[x\] T-1.1 ' "$f" || fail "T-1.1 not ticked"
assert_no_file pwned
line="- T-1.1: $r ($(git config user.name), $(date +%F))"
assert_contains "$(cat "$f")" "$line"
# Before "## Review (optional)", below "## Built".
assert_eq "$(L="$line" awk '/^## /{h=$0} $0==ENVIRON["L"]{print h}' "$f")" '## Waived'
# FR-67.3: review shows it.
assert_contains "$(sdd review 2>&1)" "waived  ${line#- }"
# A tick by hand with no waiver is still refused at ship; a waived task is not asked for.
sed 's/^- \[ \] T-1.2 /- [x] T-1.2 /' "$f" >"$T/f" && cp "$T/f" "$f"
sdd task 'done' T-1.3 >/dev/null 2>&1 || fail "T-1.3 failed"
# Must not change: a waiver is not "## Built" written (the plan is filled, Built is not).
sdd check >/dev/null 2>&1
assert_contains "$(sdd status 2>&1)" '"## Built" is not written yet'
fill "$f" built
git add -A && git commit -qm "feat(1): T-1.2 by hand, T-1.3 normal"
out=$(sdd ship 2>&1)
assert_eq $? 1 "(unwaived hand-tick)"
assert_contains "$out" 'ticked without .sdd/bin/sdd task done: T-1.2'
assert_not_contains "$out" 'T-1.1'
# FR-67.2: waive T-1.2 too (already ticked): ship accepts both, with no receipt or commit naming them.
sdd task waive T-1.2 "ticked before the test could run" >/dev/null 2>&1 || fail "waive T-1.2 failed"
git commit -qam "docs(1): waivers"
out=$(sdd ship 2>&1) || fail "ship failed: $out"
assert_contains "$out" 'shipped 1 into main'
exit 0

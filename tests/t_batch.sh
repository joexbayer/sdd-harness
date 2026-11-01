# Item 17: FR-17.1 task sizes, FR-17.2 sdd task next prints the next batch, FR-17.3 next and
# sdd run builder show the batch, FR-17.5 unknown task attributes make the task unreadable.
. "$SRC/tests/lib.sh"
new_repo

sdd new feature "Orders paging" >/dev/null 2>&1
f=specs/changes/1-orders-paging/item.md
fill "$f" plan
# FR-17.1: the template and the plan prompt ask for a size per task.
grep -q 'size: S)' "$f" || fail "feature template has no sized task example"
assert_contains "$(sdd next)" 'size: S|M|L'
awk '/^## What changes$/ { print; print "FR-1.1 WHEN a page is asked for THE SYSTEM SHALL return 20 orders."; next }
/^## Tasks \(optional\)$/ { print
	print "- [ ] T-1.1 Field, FR-1.1 (files: a.sh; test: true; size: S)"
	print "- [ ] T-1.2 Query (test: true; size: S)"
	print "- [ ] T-1.3 Page (test: true; size: L)"
	print "- [ ] T-1.4 Docs (size: S)"
	print "- [ ] T-1.5 Unsized (test: true)"
	print "- [ ] T-1.6 Tiny (test: true; size: S)"; print ""; next } { print }' "$f" >"$T/f" && cp "$T/f" "$f"
git commit -qam "docs(1): plan with sized tasks" && sdd approve >/dev/null 2>&1 || fail "approve failed"

# FR-17.1: sdd reads the size, and the size is not part of the test.
out=$(sdd task next)
assert_contains "$out" '[ ] T-1.1 Field (size: S)'
assert_contains "$out" 'test: true'
assert_not_contains "$out" 'test: true; size'
# FR-17.2: the first open task with the S tasks right after it; an L task runs alone.
assert_contains "$out" 'batch   T-1.1 T-1.2'
assert_not_contains "$out" 'T-1.3'
sdd task 'done' T-1.1 >/dev/null 2>&1 && sdd task 'done' T-1.2 >/dev/null 2>&1 || fail "T-1.1, T-1.2 failed"
git add -A && git commit -qm "feat(1): T-1.1 T-1.2 field and query"
out=$(sdd task next)
assert_contains "$out" 'batch   T-1.3'
assert_contains "$out" '(size: L)'
assert_not_contains "$out" 'T-1.4'
sdd task 'done' T-1.3 >/dev/null 2>&1 && git add -A && git commit -qm "feat(1): T-1.3 page" || fail "T-1.3 failed"
# FR-17.1, FR-17.2: no size counts as M, and an M task runs alone: an S task before it is alone too.
out=$(sdd task next)
assert_contains "$out" 'batch   T-1.4'
assert_contains "$out" 'test: the full check'
assert_not_contains "$out" 'T-1.5'
sdd task 'done' T-1.4 >/dev/null 2>&1 && git add -A && git commit -qm "feat(1): T-1.4 docs" || fail "T-1.4 failed"
out=$(sdd task next)
assert_contains "$out" 'batch   T-1.5'
assert_contains "$out" '(size: M)'
assert_not_contains "$out" 'T-1.6'
sdd task 'done' T-1.5 >/dev/null 2>&1 && sdd task 'done' T-1.6 >/dev/null 2>&1 || fail "T-1.5, T-1.6 failed"
git add -A && git commit -qm "feat(1): T-1.5 T-1.6 rest"
assert_contains "$(sdd task next)" 'no open tasks'

# FR-17.2: up to [build] batch S tasks (default 3), then the next batch.
git switch -q main
sdd new feature "Smalls" >/dev/null 2>&1
f=specs/changes/2-smalls/item.md
fill "$f" plan
awk '/^## What changes$/ { print; print "FR-2.1 WHEN x THE SYSTEM SHALL y."; next }
/^## Tasks \(optional\)$/ { print
	for (i = 1; i <= 5; i++) print "- [ ] T-2." i " Small " i ", FR-2.1 (test: true; size: S)"
	print ""; next } { print }' "$f" >"$T/f" && cp "$T/f" "$f"
git commit -qam "docs(2): plan" && sdd approve >/dev/null 2>&1 || fail "approve 2 failed"
assert_contains "$(sdd task next)" 'batch   T-2.1 T-2.2 T-2.3'
git config -f .sdd/config build.batch 2
assert_contains "$(sdd task next)" 'batch   T-2.1 T-2.2'
assert_not_contains "$(sdd task next)" 'T-2.3'
git checkout -q -- .sdd/config

# FR-17.3: next shows the whole batch, each task as for one task, and how to commit it.
out=$(sdd next)
assert_contains "$out" 'Current batch: T-2.1 T-2.2 T-2.3'
assert_contains "$out" 'Task: T-2.1 Small 1'
assert_contains "$out" 'Task: T-2.3 Small 3'
assert_not_contains "$out" 'T-2.4'
assert_contains "$out" 'serves  FR-2.1 WHEN x THE SYSTEM SHALL y.'
assert_contains "$out" 'e.g. feat(2): T-2.1 T-2.2 T-2.3 Small 1; Small 2; Small 3'
# FR-17.3: sdd run builder (item 16) runs on that batch: its prompt is next's, its log names it.
mkdir -p "$T/bin" "$T/stub"
cat >"$T/bin/narrowbot" <<'EOF'
#!/bin/sh
while [ $# -gt 0 ]; do [ "$1" = -p ] && printf '%s\n' "$2" >"$STUB/narrowbot.prompt"; shift; done
echo '{"type":"finish","exit":0,"verdict":"passed","tokens":{"in":1000,"out":100}}'
EOF
chmod +x "$T/bin/narrowbot"
setcfg role.builder.tier small && setcfg tier.small.agent narrowbot && setcfg tier.small.model m
out=$(export PATH="$T/bin:$PATH" STUB="$T/stub"; sdd run builder 2 2>&1) || fail "run failed: $out"
assert_contains "$out" 'item 2 T-2.1 T-2.2 T-2.3 · started'
assert_contains "$(cat "$T/stub/narrowbot.prompt")" 'Current batch: T-2.1 T-2.2 T-2.3'
# FR-31.1: the stub ticked nothing; the run ticked the batch and left the commit to us.
assert_contains "$out" 'ticked 3 of 3 · commit with: feat(2): T-2.1 T-2.2 T-2.3'
git commit -qam "feat(2): T-2.1 T-2.2 T-2.3"

# FR-17.5: an attribute sdd does not know makes the task unreadable, instead of being read into
# the attribute before it; so does a size other than S, M or L. task done and the tasks gate refuse.
git switch -q main
sdd new feature "Colours" >/dev/null 2>&1
f=specs/changes/3-colours/item.md
fill "$f" plan
awk '/^## What changes$/ { print; print "FR-3.1 WHEN x THE SYSTEM SHALL y."; next }
/^## Tasks \(optional\)$/ { print
	print "- [ ] T-3.1 Paint, FR-3.1 (test: echo ran >ran.txt; colour: red)"
	print "- [ ] T-3.2 Huge (test: true; size: XL)"
	print "- [ ] T-3.3 Semicolons stay in tests (test: true; echo ok; size: S)"
	print ""; next } { print }' "$f" >"$T/f" && cp "$T/f" "$f"
git commit -qam "docs(3): plan" && sdd approve >/dev/null 2>&1 || fail "approve 3 failed"
out=$(sdd task 'done' T-3.1 2>&1)
assert_eq $? 1 "(unknown attribute)"
assert_contains "$out" 'T-3.1: unknown attribute colour'
assert_no_file ran.txt
assert_contains "$(sdd task 'done' T-3.2 2>&1)" 'T-3.2: size must be S, M or L, not XL'
out=$(sdd task)
assert_contains "$out" '✗ unknown attribute colour'
assert_not_contains "$out" 'test: echo ran >ran.txt; colour'
sdd task 'done' T-3.3 >/dev/null 2>&1 || fail "T-3.3 (a test with ;) failed"
assert_contains "$(sdd task next)" '✗ unknown attribute colour'
setcfg sdd.profile standard
fill "$f" built && git add -A && git commit -qm "feat(3): T-3.3 semicolons"
out=$(sdd ship 2>&1)
assert_contains "$out" "tasks not done: T-3.1, T-3.2; tasks sdd cannot read: T-3.1 (unknown attribute colour"
assert_contains "$out" "T-3.2 (size must be S, M or L, not XL)"

# FR-36.2: a batch belongs to one role: it ends where `by:` changes (no by: is the builder).
git switch -q main
sdd new feature "Roles" >/dev/null 2>&1
f=specs/changes/4-roles/item.md
fill "$f" plan
awk '/^## What changes$/ { print; print "FR-4.1 WHEN x THE SYSTEM SHALL y."; next }
/^## Tasks \(optional\)$/ { print
	print "- [ ] T-4.1 Test, FR-4.1 (test: true; size: S; by: planner)"
	print "- [ ] T-4.2 Code (test: true; size: S)"
	print "- [ ] T-4.3 More (test: true; size: S; by: builder)"
	print "- [ ] T-4.4 Docs (test: true; size: S; by: writer)"
	print ""; next } { print }' "$f" >"$T/f" && cp "$T/f" "$f"
git commit -qam "docs(4): plan" && sdd approve >/dev/null 2>&1 || fail "approve 4 failed"
assert_contains "$(sdd task next)" 'batch   T-4.1
'
assert_contains "$(sdd next)" 'Current task: T-4.1 Test'
sdd task 'done' T-4.1 >/dev/null 2>&1 || fail "T-4.1 failed"
assert_contains "$(sdd task next)" 'batch   T-4.2 T-4.3
'
sdd task 'done' T-4.2 >/dev/null 2>&1 && sdd task 'done' T-4.3 >/dev/null 2>&1 || fail "T-4.2, T-4.3 failed"
assert_contains "$(sdd task next)" 'batch   T-4.4
'
exit 0

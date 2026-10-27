# FR-1.8 ship: gates, archive, fast-forward base (checked out elsewhere or not), rollback on
# failure, never push. FR-1.9 a spike lands only its item. FR-1.13 no code before approval.
# FR-7.4 a branch pushed before the rebase is still deleted.
. "$SRC/tests/lib.sh"
new_repo
git init -q --bare "$T/remote.git"
git remote add origin "$T/remote.git"
git push -q origin main
remote_before=$(git ls-remote origin)

# --- the whole loop in one checkout: plan, approve, build, write up, ship
planned_item fix "Off by one"
echo fixed >code.txt
git add code.txt && git commit -qm "fix(1): code"
fill "$ITEM" built
git commit -qam "docs(1): built"
out=$(sdd ship 2>&1) || fail "ship failed: $out"
assert_contains "$out" 'shipped 1 into main'
assert_eq "$(git symbolic-ref --short HEAD)" main
git rev-parse -q --verify refs/heads/fix/1-off-by-one >/dev/null && fail "item branch should be deleted"
assert_file code.txt
a=specs/archive/1-off-by-one/item.md
assert_file "$a"
assert_contains "$(cat "$a")" 'status: shipped'
assert_eq "$(git log -1 --format=%s)" 'docs(1): ship fix "Off by one"'

# --- gates: unapproved, code before approval, untracked files, failing check
sdd new feature "Unapproved" >/dev/null 2>&1
fill specs/changes/2-unapproved/item.md
git commit -qam "docs(2): plan and built"
out=$(sdd ship 2>&1)
assert_eq $? 1
assert_contains "$out" 'not approved'

echo early >early.txt
git add early.txt && git commit -qm "feat(2): code before approval"
sdd approve >/dev/null 2>&1 || fail "approve failed"
out=$(sdd ship 2>&1)
assert_eq $? 1
assert_contains "$out" 'code was committed before the plan was approved'
git switch -q main

planned_item chore "Bump"
fill "$ITEM" built
git commit -qam "docs(3): built"
echo "not added" >helper.sh
out=$(sdd ship 2>&1)
assert_eq $? 1 "(untracked files would ship unchecked)"
assert_contains "$out" 'commit, stash or ignore'
rm helper.sh
setcfg --replace-all check.run 'exit 1'
out=$(sdd ship 2>&1)
assert_eq $? 1 "(failing check blocks)"
assert_eq "$(git symbolic-ref --short HEAD)" chore/3-bump
assert_file specs/changes/3-bump/item.md
setcfg --replace-all check.run 'echo ok'

# --- rollback: a failure after archiving leaves the item open, and ship can run again.
# main is checked out in another worktree with an uncommitted edit the item conflicts with.
git worktree add -q "$T/base" main
echo "conflicting edit" >>"$T/base/README.md"
echo "change" >>README.md
git commit -qam "chore(3): touch README"
out=$(sdd ship 2>&1)
assert_eq $? 1 "(base worktree has a conflicting uncommitted edit)"
assert_contains "$out" 'could not fast-forward'
assert_eq "$(git log -1 --format=%s)" 'chore(3): touch README' "(ship rolled back)"
assert_file specs/changes/3-bump/item.md
git -C "$T/base" checkout -q README.md
out=$(sdd ship 2>&1) || fail "second ship failed: $out"
assert_contains "$out" 'shipped 3 into main'
assert_file "$T/base/specs/archive/3-bump/item.md"
git worktree remove --force "$T/base"
git switch -q main

# --- worktree: base checked out in the main checkout, rebased because main moved
sdd new feature "Wider" --worktree >/dev/null 2>&1 || fail "new --worktree failed"
cd "$T/app.4" || exit 1
fill specs/changes/4-wider/item.md plan
git commit -qam "docs(4): plan"
sdd approve >/dev/null 2>&1 || fail "approve in worktree failed"
echo wide >wide.txt
git add -A && git commit -qm "feat(4): wide"
fill specs/changes/4-wider/item.md built
git commit -qam "docs(4): built"
echo "main moved" >"$R/moved.txt"
git -C "$R" add moved.txt && git -C "$R" commit -qm "unrelated"
out=$(sdd ship 2>&1) || fail "worktree ship failed: $out"
assert_contains "$out" 'rebased onto main'
assert_contains "$out" 'this worktree and branch feature/4-wider stay until tidy'   # FR-7.5
assert_file "$R/wide.txt"
assert_file "$R/moved.txt"
assert_file "$R/specs/archive/4-wider/item.md"
assert_eq "$(git -C "$R" symbolic-ref --short HEAD)" main

# --- rebase conflict: refused, branch left as it was
cd "$R" || exit 1
planned_item feature "Clash"
fill "$ITEM" built
echo "mine" >moved.txt
git add -A && git commit -qm "feat(5): conflicting"
git switch -q main
echo "theirs" >moved.txt
git commit -qam "main changes moved.txt"
git switch -q feature/5-clash
before=$(git rev-parse HEAD)
out=$(sdd ship 2>&1)
assert_eq $? 1
assert_contains "$out" 'rebase onto main hit conflicts'
assert_eq "$(git rev-parse HEAD)" "$before"
git switch -q main

# --- spike: only the item lands, and afterwards it is no longer open
planned_item spike "Try queue"
fill "$ITEM" built
echo hack >spike-code.txt
git add -A && git commit -qm "spike code"
out=$(sdd ship 2>&1) || fail "spike ship failed: $out"
assert_contains "$out" 'findings archived on main'
git show main:specs/archive/6-try-queue/item.md | grep -q 'status: shipped' || fail "spike item not on main"
git cat-file -e main:spike-code.txt 2>/dev/null && fail "spike code must not land on main"
out=$(sdd ship 2>&1)
assert_eq $? 1 "(a shipped spike cannot ship twice)"
git switch -q main
assert_not_contains "$(sdd status)" 'Try queue'

assert_eq "$(git ls-remote origin)" "$remote_before" "(ship must never push)"

# --- FR-7.4: a branch pushed before ship rebased it differs from its pushed copy (git branch -d
# would refuse), yet every commit is on main, so ship deletes it.
new_repo pushed
git init -q --bare "$T/pushed.git" && git remote add origin "$T/pushed.git" && git push -q origin main
planned_item fix "Pushed early"
echo fixed >fix.txt && git add fix.txt && git commit -qm "fix(1): code"
fill "$ITEM" built && git commit -qam "docs(1): built" && git push -q -u origin HEAD
git switch -q main && echo other >other.txt && git add other.txt && git commit -qm "main moves"
git switch -q fix/1-pushed-early
out=$(sdd ship 2>&1) || fail "ship failed: $out"
assert_contains "$out" "rebased onto main"
assert_contains "$out" "branch fix/1-pushed-early deleted"
git rev-parse -q --verify refs/heads/fix/1-pushed-early >/dev/null && fail "pushed branch should be deleted"
exit 0

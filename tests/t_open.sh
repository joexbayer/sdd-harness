# FR-7.1 open switches to an item's branch, tracking a teammate's remote one; FR-7.2 --worktree;
# FR-7.3 refusals.
. "$SRC/tests/lib.sh"
new_repo
git init -q --bare "$T/origin.git" && git remote add origin "$T/origin.git"
git push -q origin main

# 1: an item on a local branch (pushed, so a teammate's clone picks the next id).
sdd new feature "Local thing" >/dev/null 2>&1
git push -q origin HEAD
git switch -q main

# 2: a teammate's item, seen here only as origin/feature/2-...
git clone -q "$T/origin.git" "$T/mate"
(cd "$T/mate" && git config user.name kari && sdd new feature "Karis thing" >/dev/null 2>&1 && git push -q origin HEAD) ||
	fail "teammate setup failed"
git fetch -q origin

# FR-7.1: a local branch, then a remote-only one gets a local branch that tracks it.
out=$(sdd open 1) || fail "open 1 failed: $out"
assert_contains "$out" 'switched to feature/1-local-thing'
assert_eq "$(git branch --show-current)" feature/1-local-thing
assert_contains "$(sdd open 1)" 'already on feature/1-local-thing'
out=$(sdd open 2) || fail "open 2 failed: $out"
assert_contains "$out" 'switched to feature/2-karis-thing (tracking origin/feature/2-karis-thing)'
assert_eq "$(git rev-parse --abbrev-ref '@{upstream}')" origin/feature/2-karis-thing
git switch -q main

# FR-7.3: refuses to switch a dirty checkout, an unknown id, a shipped item, bad usage.
echo x >dirty.txt
out=$(sdd open 1 2>&1)
assert_eq $? 1 "(dirty tree)"
assert_contains "$out" 'commit, stash or ignore your changes first'
rm dirty.txt
out=$(sdd open 99 2>&1)
assert_eq $? 1 "(unknown id)"
assert_contains "$out" 'no item 99'
sdd open x >/dev/null 2>&1
assert_eq $? 2 "(not an id)"
sdd open >/dev/null 2>&1
assert_eq $? 2 "(no id)"

sdd new chore "Done thing" >/dev/null 2>&1
fill specs/changes/3-done-thing/item.md
git commit -qam "docs(3): done" && sdd ship >/dev/null 2>&1 || fail "ship 3 failed"
out=$(sdd open 3 2>&1)
assert_eq $? 1 "(shipped)"
assert_contains "$out" 'item 3 is shipped (specs/archive/3-done-thing)'

# FR-7.2: a worktree next to the main checkout; asked again, it says where the branch is.
out=$(sdd open 1 --worktree) || fail "open --worktree failed: $out"
assert_contains "$out" 'app.1'
assert_file "$T/app.1/specs/changes/1-local-thing/item.md"
assert_eq "$(git -C "$T/app.1" branch --show-current)" feature/1-local-thing
assert_contains "$(sdd open 1 --worktree)" 'feature/1-local-thing is checked out in'
assert_contains "$(sdd open 1)" 'feature/1-local-thing is checked out in'
# From inside a worktree, the next one still goes next to the main checkout (not app.1.2).
out=$(cd "$T/app.1" && sdd open 2 --worktree) || fail "open 2 --worktree from a worktree failed: $out"
assert_file "$T/app.2/specs/changes/2-karis-thing/item.md"
exit 0

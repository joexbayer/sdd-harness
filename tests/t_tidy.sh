# FR-7.5 ship in a worktree keeps it; FR-7.6 tidy removes what is provably safe; FR-7.7 keeps
# the rest with a reason; FR-7.8 lists remote branches; FR-7.9 tidy --remote deletes them, but
# not one with changes the base lacks; FR-7.11 --remote only first.
. "$SRC/tests/lib.sh"
new_repo
git init -q --bare "$T/origin.git" && git remote add origin "$T/origin.git"
git push -q origin main
assert_contains "$(sdd tidy)" 'nothing to tidy'

# shipped_from_worktree <n> "title": a feature planned, built, pushed and shipped from its own
# worktree; the shell stays in the main checkout.
shipped_from_worktree() {
	sdd new feature "$2" --worktree >/dev/null 2>&1 || fail "new $2 failed"
	(
		cd "$T/app.$1" || exit 1
		f=$(ls specs/changes/"$1"-*/item.md)
		fill "$f" plan && git commit -qam "docs($1): plan" && sdd approve >/dev/null 2>&1 &&
			echo "$1" >"code$1.txt" && git add "code$1.txt" && git commit -qm "feat($1): code" &&
			fill "$f" built && git commit -qam "docs($1): built" && git push -q -u origin HEAD &&
			sdd ship
	) >"$T/ship.out" 2>&1 || fail "ship $2 failed: $(cat "$T/ship.out")"
}

# 1 and 2: shipped from worktrees. FR-7.5: ship keeps the worktree and points at tidy.
shipped_from_worktree 1 "First"
assert_contains "$(cat "$T/ship.out")" 'this worktree and branch feature/1-first stay until tidy'
assert_contains "$(cat "$T/ship.out")" '&& .sdd/bin/sdd tidy'
assert_file "$T/app.1"
shipped_from_worktree 2 "Second"
echo wip >"$T/app.2/wip.txt"

# 3: a spike: its code never lands, so its branch is never safe to delete.
planned_item spike "Learn"
echo try >try.txt && git add try.txt && git commit -qm "spike(3): try"
fill "$ITEM" built && git commit -qam "docs(3): findings" && sdd ship >/dev/null 2>&1 || fail "ship spike failed"
git switch -q main

# 4: still open: tidy never touches it.
sdd new feature "Open work" >/dev/null 2>&1 && git push -q origin HEAD && git switch -q main

# FR-7.7: inside a shipped item's worktree, tidy keeps that worktree.
out=$(cd "$T/app.1" && sdd tidy --dry-run)
assert_contains "$out" "worktree $(cd "$T/app.1" && pwd -P)"
assert_contains "$out" 'you are in it'

# FR-7.7: a shipped branch checked out in the main checkout is kept; a branch that only shares
# an id with a done item (another slug) is not sdd's to judge.
git switch -q spike/3-learn
assert_contains "$(sdd tidy --dry-run)" 'kept     branch spike/3-learn (item 3, shipped): checked out in the main checkout'
git switch -q main
git branch fix/1-typo main

# FR-7.6 --dry-run lists without removing.
out=$(sdd tidy --dry-run) || fail "dry run failed: $out"
assert_contains "$out" 'would remove worktree'
assert_contains "$out" 'and branch feature/1-first (item 1, shipped)'
assert_not_contains "$out" fix/1-typo
git rev-parse -q --verify refs/heads/feature/1-first >/dev/null || fail "dry run deleted a branch"
assert_file "$T/app.1"

# FR-7.6, FR-7.7, FR-7.8: the real run. main is not pushed yet, so no remote branch counts as done.
out=$(sdd tidy) || fail "tidy failed: $out"
assert_contains "$out" 'removed  worktree'
assert_contains "$out" 'and branch feature/1-first (item 1, shipped)'
assert_no_file "$T/app.1"
git rev-parse -q --verify refs/heads/feature/1-first >/dev/null && fail "branch 1 should be gone"
assert_contains "$out" 'uncommitted changes · git worktree remove --force'
assert_file "$T/app.2/wip.txt"
assert_contains "$out" "kept     branch spike/3-learn (item 3, shipped): a spike's code never lands on main · git branch -D spike/3-learn"
assert_not_contains "$out" 'feature/4-open-work'
assert_not_contains "$out" 'remote   '
git rev-parse -q --verify refs/heads/fix/1-typo >/dev/null || fail "a branch of another slug was deleted"

# FR-7.7: a branch of a done item with commits main lacks is kept.
git switch -q -c feature/1-first main && echo more >more.txt && git add more.txt && git commit -qm more && git switch -q main
assert_contains "$(sdd tidy --dry-run)" 'kept     branch feature/1-first (item 1, shipped): has commits not on main · git branch -D feature/1-first'
git branch -q -D feature/1-first

# FR-7.8: once main is pushed, the remote branches of done items are listed.
git push -q origin main && git fetch -q origin
out=$(sdd tidy)
assert_contains "$out" 'remote   origin/feature/1-first (item 1, shipped)'
assert_contains "$out" 'next    .sdd/bin/sdd tidy --remote'

# FR-7.9: a teammate pushes to shipped item 2's branch after our last fetch: the leased delete
# is refused. After a fetch, git cherry sees the change main lacks: still kept.
git clone -q "$T/origin.git" "$T/mate"
(cd "$T/mate" && git switch -q feature/2-second && echo late >late.txt && git add late.txt &&
	git commit -qm "late" && git push -q origin HEAD) || fail "teammate push failed"
out=$(sdd tidy --remote) || fail "tidy --remote failed: $out"
assert_contains "$out" 'removed  origin/feature/1-first (item 1, shipped)'
assert_contains "$out" 'kept     origin/feature/2-second (item 2, shipped): origin refused'
git fetch -q origin
assert_contains "$(sdd tidy --remote)" 'kept     origin/feature/2-second (item 2, shipped): changes not on origin/main ('
assert_eq "$(git ls-remote --heads origin feature/1-first)" ''
assert_contains "$(git ls-remote --heads origin)" 'feature/2-second'
assert_contains "$(git ls-remote --heads origin)" 'feature/4-open-work'

# FR-7.11: --remote only as the first argument; unknown flags.
sdd tidy --dry-run --remote >/dev/null 2>&1
assert_eq $? 2 "(--remote not first)"
sdd tidy --bogus >/dev/null 2>&1
assert_eq $? 2 "(unknown flag)"
exit 0

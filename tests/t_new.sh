# FR-1.2 new allocates an id, branches from base, scaffolds and commits only the item.
# FR-1.3 --worktree. FR-1.4 the item comes from the branch name.
. "$SRC/tests/lib.sh"
new_repo

echo "work in progress" >wip.txt
out=$(sdd new fix "Pagination drops last item" 2>&1) || fail "new failed: $out"
assert_contains "$out" 'fix/1-pagination-drops-last-item'
assert_eq "$(git symbolic-ref --short HEAD)" fix/1-pagination-drops-last-item
f=specs/changes/1-pagination-drops-last-item/item.md
assert_file "$f"
assert_contains "$(cat "$f")" 'id: 1'
assert_contains "$(cat "$f")" 'title: Pagination drops last item'
assert_contains "$(cat "$f")" 'FR-1.1'
assert_eq "$(git log -1 --format=%s)" 'docs(1): open fix "Pagination drops last item"'
assert_eq "$(git show --name-only --format= HEAD)" "$f"
assert_file wip.txt # unrelated work is carried along, not committed
git status --porcelain | grep -q 'wip.txt' || fail "wip.txt should still be untracked"
rm wip.txt

# Titles with odd characters and non-Latin text still produce a valid branch.
git switch -q main
out=$(sdd new chore 'Bump deps & "fix" CI / again' 2>&1) || fail "$out"
assert_eq "$(git symbolic-ref --short HEAD)" chore/2-bump-deps-fix-ci-again
assert_contains "$(cat specs/changes/2-bump-deps-fix-ci-again/item.md)" 'title: Bump deps & "fix" CI / again'
git switch -q main
sdd new spike 'Ærlig øl på ølfest' >/dev/null 2>&1 || fail "non-Latin title failed"
assert_eq "$(git symbolic-ref --short HEAD)" spike/3-rlig-l-p-lfest

# Unknown type and missing title are usage errors (exit 2).
sdd new nope "x" >/dev/null 2>&1
assert_eq $? 2
sdd new fix >/dev/null 2>&1
assert_eq $? 2

# --worktree: two at once get distinct ids, each in its own worktree.
git switch -q main
sdd new feature "Alpha" --worktree >"$T/a.out" 2>&1 &
sdd new feature "Beta" --worktree >"$T/b.out" 2>&1 &
wait
ids=$(cat "$T/a.out" "$T/b.out" | sed -n 's/^\([0-9][0-9]*\) feature.*/\1/p' | sort -n | paste -sd ' ' -)
assert_eq "$ids" "4 5"
aid=$(sed -n "s/^\([0-9]*\) feature · Alpha$/\1/p" "$T/a.out")
bid=$(sed -n "s/^\([0-9]*\) feature · Beta$/\1/p" "$T/b.out")
assert_file "$T/app.$aid/specs/changes/$aid-alpha/item.md"
assert_file "$T/app.$bid/specs/changes/$bid-beta/item.md"

# The current item comes from the branch: none on main.
assert_eq "$(git symbolic-ref --short HEAD)" main
out=$(sdd status 2>&1)
assert_contains "$out" 'open items:'
assert_contains "$out" 'Pagination drops last item'
assert_contains "$out" 'Alpha'
(cd "$T/app.$bid" && sdd status) | grep -q "^$bid feature · Beta" || fail "status in worktree should show item $bid"

# A fresh clone (no local counter) never reuses an id that a branch already carries, even
# with a custom branch template; unrelated branches like release/2024-10 are ignored.
git config -f .sdd/config sdd.branch '{id}-{slug}'
git branch 14-custom main
git branch release/2024-10 main
rm -f "$(git rev-parse --git-common-dir)/sdd/next-id"
out=$(sdd new chore "After custom" 2>&1) || fail "$out"
assert_contains "$out" '15 chore'
assert_eq "$(git symbolic-ref --short HEAD)" 15-after-custom

# Invoked through a symlink (a global ~/bin/sdd), it still finds its own folder.
mkdir -p "$HOME/bin"
ln -s "$SRC/.sdd/bin/sdd" "$HOME/bin/sdd"
"$SH" "$HOME/bin/sdd" help | grep -q 'Humans plan and review' || fail "symlinked sdd failed"
exit 0

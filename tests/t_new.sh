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
assert_contains "$out" 'warning: uncommitted changes come along to the new branch: wip.txt' # FR-73.5
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
assert_file "$T/app/.worktrees/$aid/specs/changes/$aid-alpha/item.md"
assert_file "$T/app/.worktrees/$bid/specs/changes/$bid-beta/item.md"

# FR-66.1: [worktree] setup runs in the new worktree; a failing one warns and keeps the item.
git config -f .sdd/config worktree.setup 'pwd > setup-ran'
out=$(sdd new chore "Seeded" --worktree 2>&1) || fail "new with setup failed: $out"
sid=$(printf '%s\n' "$out" | sed -n 's/^\([0-9][0-9]*\) chore.*/\1/p')
assert_eq "$(cat "$T/app/.worktrees/$sid/setup-ran")" "$(cd "$T/app/.worktrees/$sid" && pwd -P)"
git config -f .sdd/config worktree.setup 'echo nope-setup; exit 4'
out=$(sdd new chore "Unseeded" --worktree 2>&1) || fail "a failing setup must not fail new: $out"
assert_contains "$out" 'worktree setup failed'
assert_contains "$out" 'nope-setup'
fid=$(printf '%s\n' "$out" | sed -n 's/^\([0-9][0-9]*\) chore.*/\1/p')
assert_file "$T/app/.worktrees/$fid/specs/changes/$fid-unseeded/item.md"
git config -f .sdd/config --unset worktree.setup
# FR-78.2: the exclude holds the line once, so the main checkout stays clean.
assert_eq "$(grep -cx '/.worktrees/' "$(git rev-parse --git-common-dir)/info/exclude")" 1
assert_not_contains "$(git status --porcelain)" worktrees

# The current item comes from the branch: none on main.
assert_eq "$(git symbolic-ref --short HEAD)" main
out=$(sdd status 2>&1)
assert_contains "$out" 'open items:'
assert_contains "$out" 'Pagination drops last item'
assert_contains "$out" 'Alpha'
(cd "$T/app/.worktrees/$bid" && sdd status) | grep -q "^$bid feature · Beta" || fail "status in worktree should show item $bid"

# A fresh clone (no local counter) never reuses an id that a branch already carries, even
# with a custom branch template; unrelated branches like release/2024-10 are ignored.
git config -f .sdd/config sdd.branch '{id}-{slug}'
git branch 14-custom main
git branch release/2024-10 main
rm -f "$(git rev-parse --git-common-dir)/sdd/next-id"
out=$(sdd new chore "After custom" 2>&1) || fail "$out"
assert_contains "$out" '15 chore'
assert_eq "$(git symbolic-ref --short HEAD)" 15-after-custom

# FR-72.1 two clones of one origin, no push between: ids 1 and 2; the origin counter holds the last.
new_repo ids
git init -q --bare "$T/o72.git" && git remote add origin "$T/o72.git" && git push -q origin main
git clone -q "$T/o72.git" "$T/mate72"
refval() { git --git-dir="$T/o72.git" cat-file -p refs/sdd/next-id 2>/dev/null | cut -d ' ' -f1; }
out=$(sdd new chore "Alice" 2>&1) || fail "$out"
assert_contains "$out" '1 chore'
out=$(cd "$T/mate72" && sdd new chore "Bob" 2>&1) || fail "$out"
assert_contains "$out" '2 chore'
assert_eq "$(refval)" 2
assert_no_file "$T/o72.git/refs/heads/chore"
# FR-72.1 the origin says 5, the clone has seen 3: 6, and the origin then says 6.
git switch -q main
git branch chore/3-seen main
blob=$(printf '5 someone\n' | git --git-dir="$T/o72.git" hash-object -w --stdin)
git --git-dir="$T/o72.git" update-ref refs/sdd/next-id "$blob"
out=$(sdd new chore "Ahead" 2>&1) || fail "$out"
assert_contains "$out" '6 chore'
assert_eq "$(refval)" 6
# FR-72.1 the clone has seen more than the origin says: its own next id, written back.
git switch -q main
git branch chore/9-seen main
out=$(sdd new chore "Behind" 2>&1) || fail "$out"
assert_contains "$out" '10 chore'
assert_eq "$(refval)" 10
# FR-72.3 content that does not start with a number is ignored and replaced.
git switch -q main
blob=$(printf 'x; rm -rf\n' | git --git-dir="$T/o72.git" hash-object -w --stdin)
git --git-dir="$T/o72.git" update-ref refs/sdd/next-id "$blob"
out=$(sdd new chore "Garbage" 2>&1) || fail "$out"
assert_contains "$out" '11 chore'
assert_eq "$(refval)" 11
assert_not_contains "$out" 'Illegal number'
assert_not_contains "$out" 'integer expression'
# FR-72.2 a remote that refuses the write: the clone's own next id, the reason, the counter unmoved.
git switch -q main
printf '#!/bin/sh\nexit 1\n' >"$T/o72.git/hooks/pre-receive" && chmod +x "$T/o72.git/hooks/pre-receive"
out=$(sdd new chore "Refused" 2>&1 </dev/null) || fail "refused new failed: $out"
assert_contains "$out" 'sdd: warning: id 12 is not reserved on origin (it refused the write)'
assert_eq "$(refval)" 11
rm "$T/o72.git/hooks/pre-receive"
# FR-72.2 over ssh nothing may prompt or wait long: BatchMode and a connect timeout.
git switch -q main
printf '#!/bin/sh\nprintf "%%s\\n" "$*" >>"%s/ssh72.log"\nexit 255\n' "$T" >"$T/ssh72" && chmod +x "$T/ssh72"
git remote set-url origin "ssh://git@host.invalid/x.git"
out=$(GIT_SSH_COMMAND="$T/ssh72" sdd new chore "Ssh" 2>&1 </dev/null) || fail "ssh new failed: $out"
assert_contains "$out" '(could not reach it)'
assert_contains "$(cat "$T/ssh72.log")" '-o BatchMode=yes -o ConnectTimeout=10'
git remote set-url origin "$T/o72.git"
# FR-72.1 a lost race: the origin moves between the read and the write; the loser reads again.
git switch -q main
mkdir "$T/bin72"
REALGIT=$(command -v git)
cat >"$T/bin72/git" <<WRAP
#!/bin/sh
if [ "\$1" = push ] && [ -f "$T/race72" ]; then
	rm -f "$T/race72"
	b=\$(printf '20 racer\n' | "$REALGIT" --git-dir="$T/o72.git" hash-object -w --stdin)
	"$REALGIT" --git-dir="$T/o72.git" update-ref refs/sdd/next-id "\$b"
fi
exec "$REALGIT" "\$@"
WRAP
chmod +x "$T/bin72/git"
: >"$T/race72"
out=$(PATH="$T/bin72:$PATH" sdd new chore "Raced" 2>&1) || fail "$out"
assert_contains "$out" '21 chore'
assert_eq "$(refval)" 21
# FR-72.2 an unreachable remote: the clone's own next id, a warning, no hang, success.
git switch -q main
git remote set-url origin "$T/nowhere72.git"
out=$(sdd new chore "Offline" 2>&1 </dev/null) || fail "offline new failed: $out"
assert_contains "$out" '22 chore'
assert_contains "$out" 'sdd: warning: id 22 is not reserved on origin (could not reach it): another developer may take the same id'
# FR-72.2 no remote configured: no warning.
git switch -q main
git remote remove origin
out=$(sdd new chore "Alone" 2>&1) || fail "$out"
assert_contains "$out" '23 chore'
assert_not_contains "$out" 'not reserved'

# Invoked through a symlink (a global ~/bin/sdd), it still finds its own folder.
mkdir -p "$HOME/bin"
ln -s "$SRC/.sdd/bin/sdd" "$HOME/bin/sdd"
"$SH" "$HOME/bin/sdd" help | grep -q 'Humans plan and review' || fail "symlinked sdd failed"

# FR-73.5: refuses while the install is not committed on the base; no commits at all; no warning
# for a clean tree or --worktree.
mkdir -p "$T/adopt" && cd "$T/adopt" || exit 1
git init -q && echo x >x && git add x && git commit -qm init
sdd init >/dev/null 2>&1
out=$(sdd new fix "Early" 2>&1) && fail "new should refuse before the adoption commit"
assert_contains "$out" 'sdd is not committed on main yet: git add .sdd AGENTS.md && git commit -m "chore: adopt sdd"'
assert_eq "$(git symbolic-ref --short HEAD)" main
git add -A && git commit -qm adopt
out=$(sdd new fix "Clean" 2>&1) || fail "$out"
assert_not_contains "$out" 'uncommitted'
git switch -q main
echo more >extra.txt
out=$(sdd new fix "Wt" --worktree 2>&1) || fail "$out"
assert_not_contains "$out" 'uncommitted'
mkdir -p "$T/empty" && cd "$T/empty" || exit 1
git init -q
out=$(sdd new fix "Nothing" 2>&1) && fail "new should refuse without commits"
assert_contains "$out" 'no commits yet'
assert_not_contains "$out" 'set base'

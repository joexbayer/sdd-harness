# Item 24 (multi-item plans): FR-24.1 the roadmap type; FR-24.2 its entries and what analyze says
# about them; FR-24.3 new --from; FR-24.4 depends: state; FR-24.5 ready entries in next, entry
# states in show.
. "$SRC/tests/lib.sh"
new_repo
setcfg sdd.profile standard

# roadmap <title> <entries>: a new roadmap item with its plan filled and the entries (lines
# separated by \n) under "## Items", committed. Sets RM (the item file).
roadmap() {
	sdd new roadmap "$1" >/dev/null 2>&1 || fail "new roadmap failed"
	RM=$(for f in specs/changes/*/item.md; do grep -q "^title: $1\$" "$f" && echo "$f"; done)
	fill "$RM" plan
	E=$2 awk '
		function put(s,   n, a, i) { n = split(s, a, "\\\\n"); for (i = 1; i <= n; i++) print a[i]; print "" }
		{ print } $0 == "## Items" { put(ENVIRON["E"]) }' "$RM" >"$T/rm" && cp "$T/rm" "$RM"
	git add "$RM" && git commit -qm "docs: roadmap plan"
}

# FR-24.1: new roadmap scaffolds Goal, Items and Done when.
out=$(sdd new roadmap "Shop") || fail "new roadmap failed: $out"
assert_contains "$out" '1 roadmap · Shop'
f=specs/changes/1-shop/item.md
assert_file "$f"
for h in '## Goal' '## Items' '## Done when' '## Built'; do grep -qx "$h" "$f" || fail "no $h in $f"; done
assert_eq "$(sed -n "s/^type: //p" "$f")" roadmap
assert_contains "$(sdd next)" 'Phase: plan'

# FR-24.2: analyze flags an unknown type, an after: that is not an earlier entry (later, missing,
# itself), an unreadable entry, an ID written twice; in plan order, entries named by ID only.
fill "$f" plan
awk '{ print } $0 == "## Items" {
	print "- R-1.1 feature: Auth API"
	print "- R-1.2 feature: Login page (after: R-1.3)"
	print "- R-1.3 chore: Deploy (after: R-1.1, R-1.9)"
	print "- R-1.4 featur: Typo type"
	print "- R-1.5 Missing type"
	print "- R-1.6 fix: Itself (after: R-1.6)"
	print "- R-1.1 fix: Again"
	print "" }' "$f" >"$T/f" && cp "$T/f" "$f"
git commit -qam "docs(1): plan"
out=$(sdd analyze 2>&1)
assert_eq $? 1 "(analyze with entry problems)"
assert_eq "$out" "✗ R-1.1: written twice
✗ R-1.2: after R-1.3, which is not an earlier entry
✗ R-1.3: after R-1.9, which is not an entry
✗ R-1.4: unknown type featur (types: $(ls "$SRC/.sdd/core/templates" | sed 's/\.md$//' | sort | paste -sd ' ' -))
✗ R-1.5: cannot read it: write it as - R-1.5 <type>: <title>
✗ R-1.6: after R-1.6, which is not an earlier entry"
# FR-24.2: the entries are read: show lists them with their IDs.
assert_contains "$(sdd show 1)" 'R-1.2'

# FR-24.2: a roadmap with no entries.
awk '!/^- R-1\./' "$f" >"$T/f" && cp "$T/f" "$f" && git commit -qam "docs(1): no entries"
out=$(sdd analyze 2>&1)
assert_eq $? 1 "(roadmap with no entries)"
assert_eq "$out" "✗ Items: no entries: list them as - R-1.1 <type>: <title>"
# FR-24.2: standard blocks approval of a roadmap analyze finds problems in (gate analyzed).
out=$(sdd approve 2>&1)
assert_eq $? 1 "(approve of a roadmap with no entries)"
assert_contains "$out" 'no entries'

# FR-24.2: a clean roadmap passes; continuation lines and guidance comments are no entries.
awk '{ print } $0 == "## Items" {
	print "- R-1.1 feature: Auth API"
	print "- R-1.2 feature: Login page (after: R-1.1)"
	print "- R-1.3 chore: Deploy (after: R-1.1, R-1.2)"
	print "" }' "$f" >"$T/f" && cp "$T/f" "$f" && git commit -qam "docs(1): entries"
out=$(sdd analyze 2>&1)
assert_eq $? 0 "(clean roadmap: $out)"

# FR-24.1: it goes through approve and ship like a spike: only the item lands on main.
sdd approve >/dev/null 2>&1 || fail "approve roadmap failed"
assert_contains "$(sdd next)" '"## Built" is not written yet'
fill "$f" built
echo stray >stray.txt && git add -A && git commit -qm "docs(1): built"
out=$(sdd ship 2>&1) || fail "roadmap ship failed: $out"
assert_contains "$out" 'roadmap 1: plan archived on main'
git show main:specs/archive/1-shop/item.md | grep -q '^status: shipped' || fail "roadmap not archived on main"
git cat-file -e main:stray.txt 2>/dev/null && fail "a roadmap lands only its item"
assert_eq "$(git log -1 --format=%s main)" 'docs(1): roadmap plan "Shop"'
git switch -q main

# FR-24.3: an unknown entry, a roadmap that has not shipped, a bad ref are refused.
out=$(sdd new --from R-1.9 2>&1)
assert_eq $? 1 "(unknown entry)"
assert_contains "$out" 'no entry R-1.9 in roadmap 1 (entries: R-1.1 R-1.2 R-1.3)'
out=$(sdd new --from R-7.1 2>&1)
assert_eq $? 1 "(no roadmap 7)"
assert_contains "$out" 'no shipped roadmap 7 on main'
roadmap "Later" '- R-2.1 feature: Someday'
git switch -q main
out=$(sdd new --from R-2.1 2>&1)
assert_eq $? 1 "(roadmap 2 not shipped)"
assert_contains "$out" 'no shipped roadmap 2 on main'
for bad in R-1 R-x.1 R-1.y R-1.2.3 1.2; do
	sdd new --from "$bad" >/dev/null 2>&1
	assert_eq $? 2 "(--from $bad)"
done
assert_eq "$(git rev-parse --abbrev-ref HEAD)" main

# FR-24.3: an entry opens an item with its type and title, roadmap: and depends: (its after:).
out=$(sdd new --from R-1.2 2>&1) || fail "new --from R-1.2 failed: $out"
assert_contains "$out" '3 feature · Login page'
assert_contains "$out" 'roadmap R-1.2   (depends: R-1.1)'
assert_eq "$(git rev-parse --abbrev-ref HEAD)" feature/3-login-page
g=specs/changes/3-login-page/item.md
assert_eq "$(sed -n 's/^roadmap: //p' "$g")" R-1.2
assert_eq "$(sed -n 's/^depends: //p' "$g")" R-1.1
assert_eq "$(git log -1 --format=%s)" 'docs(3): open feature "Login page"'
git switch -q main
out=$(sdd new --from R-1.3 2>&1) || fail "new --from R-1.3 failed: $out"
assert_eq "$(sed -n 's/^depends: //p' specs/changes/4-deploy/item.md)" 'R-1.1, R-1.2'
assert_eq "$(sed -n 's/^type: //p' specs/changes/4-deploy/item.md)" chore
git switch -q main

# FR-24.3: an entry already opened is refused, here and on a teammate's clone that sees the
# item's branch only as a remote-tracking ref.
out=$(sdd new --from R-1.2 2>&1)
assert_eq $? 1 "(R-1.2 opened twice)"
assert_contains "$out" 'entry R-1.2 was already opened as item 3 (Login page, feature/3-login-page)'
git init -q --bare "$T/origin.git" && git remote add origin "$T/origin.git"
git push -q origin main feature/3-login-page 2>/dev/null || fail "push failed"
git clone -q "$T/origin.git" "$T/mate" && cd "$T/mate" || fail "clone failed"
out=$(sdd new --from R-1.2 2>&1)
assert_eq $? 1 "(teammate opens R-1.2 again)"
assert_contains "$out" 'already opened as item 3 (Login page, origin/feature/3-login-page)'
cd "$R" || exit 1

# FR-24.3: --worktree; an entry with no after: gets no depends:.
out=$(sdd new --from R-1.1 --worktree 2>&1) || fail "new --from R-1.1 --worktree failed: $out"
assert_contains "$out" '5 feature · Auth API'
assert_not_contains "$out" 'depends'
wt=$(cd "$T/app.5" && pwd -P) || fail "no worktree app.5"
assert_eq "$(sed -n 's/^roadmap: //p' "$wt/specs/changes/5-auth-api/item.md")" R-1.1
assert_eq "$(grep -c '^depends:' "$wt/specs/changes/5-auth-api/item.md")" 0
assert_eq "$(git rev-parse --abbrev-ref HEAD)" main

# ship_chore: fill the current chore item, commit it and ship it (standard).
ship_chore() {
	_f=$(ls specs/changes/*/item.md | while read -r x; do grep -q '^type: chore' "$x" && echo "$x"; done | head -n 1)
	fill "$_f" && git add -A && git commit -qm "docs: chore done" && sdd check >/dev/null 2>&1 || fail "check failed"
	_o=$(sdd ship 2>&1) || fail "ship failed: $_o"
}

# FR-24.5: next on main offers nothing while a roadmap has not shipped; roadmap 1's entries are all
# opened, so it offers none of them.
roadmap "Blog" '- R-6.1 chore: Posts\n- R-6.2 chore: Comments (after: R-6.1)\n- R-6.3 chore: Feed (after: R-6.1, R-6.2)'
sdd approve >/dev/null 2>&1 || fail "approve roadmap 6 failed"
git switch -q main
out=$(sdd next)
assert_not_contains "$out" 'Ready in roadmap'
git switch -q roadmap/6-blog && fill "$RM" built && git commit -qam "docs(6): built"
sdd ship >/dev/null 2>&1 || fail "ship roadmap 6 failed"
git switch -q main

# FR-24.5: once shipped, next offers the entries whose after: is met, with the command to open each.
out=$(sdd next)
assert_contains "$out" "Ready in roadmap 6 (Blog): R-6.1 chore: Posts → .sdd/bin/sdd new --from R-6.1"
assert_not_contains "$out" 'R-6.2'
assert_not_contains "$out" 'R-1.'
# FR-24.5: show lists every entry's state.
out=$(sdd show 6)
assert_contains "$out" 'R-6.1     [not opened] chore: Posts'
assert_contains "$out" 'R-6.3     [not opened] chore: Feed (after: R-6.1, R-6.2)'
out=$(sdd show 1)
assert_contains "$out" 'R-1.1     [open (item 5)] feature: Auth API'
assert_contains "$out" 'R-1.2     [open (item 3)] feature: Login page (after: R-1.1)'
assert_eq "$(sdd show 1 --json | jq -c '[.entries[] | [.id, .type, .title, (.after | join(",")), .state, .item]]')" \
	'[["R-1.1","feature","Auth API","","open",5],["R-1.2","feature","Login page","R-1.1","open",3],["R-1.3","chore","Deploy","R-1.1,R-1.2","open",4]]'

# FR-24.5: an opened entry is no longer offered, and the next one waits until it has shipped
# (FR-24.4: an entry counts as met once the item opened from it has shipped).
sdd new --from R-6.1 >/dev/null 2>&1 || fail "new --from R-6.1 failed"
git switch -q main
assert_not_contains "$(sdd next)" 'Ready in roadmap 6'
assert_contains "$(sdd show 6)" 'R-6.1     [open (item 7)] chore: Posts'
# Team-first: a teammate who fetched the branch of item 7 is not offered R-6.1 either.
git push -q origin main chore/7-posts 2>/dev/null || fail "push failed"
(cd "$T/mate" && git fetch -q && git merge -q --ff-only origin/main) || fail "teammate fetch failed"
assert_not_contains "$(cd "$T/mate" && sdd next)" 'R-6.1'
git switch -q chore/7-posts
ship_chore
git switch -q main 2>/dev/null
out=$(sdd next)
assert_contains "$out" "Ready in roadmap 6 (Blog): R-6.2 chore: Comments → .sdd/bin/sdd new --from R-6.2"
assert_not_contains "$out" 'R-6.3'
assert_contains "$(sdd show 6)" 'R-6.1     [shipped (item 7)] chore: Posts'
echo ok

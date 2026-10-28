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
echo ok

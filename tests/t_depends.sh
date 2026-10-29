# Item 24 (multi-item plans): FR-24.4 a depends: ref (an item ID or a roadmap entry) is met once
# that item, or the item opened from the entry, has shipped; FR-24.6 what an item waits for in
# next, status and ls, and the depends ship gate (lite warns, standard refuses).
. "$SRC/tests/lib.sh"
new_repo
setcfg sdd.profile standard

# The roadmap: three chores in order, shipped.
sdd new roadmap "Shop" >/dev/null 2>&1 || fail "new roadmap failed"
rm=specs/changes/1-shop/item.md
fill "$rm" plan
awk '{ print } $0 == "## Items" {
	print "- R-1.1 chore: Auth API"
	print "- R-1.2 chore: Login page (after: R-1.1)"
	print "- R-1.3 chore: Deploy (after: R-1.2)"
	print "" }' "$rm" >"$T/rm" && cp "$T/rm" "$rm"
git commit -qam "docs(1): plan" && sdd approve >/dev/null 2>&1 || fail "approve roadmap failed"
fill "$rm" built && git commit -qam "docs(1): built"
sdd ship >/dev/null 2>&1 || fail "ship roadmap failed"
git switch -q main

# finish <item file>: fill it, commit it and run the check, ready to ship.
finish() { fill "$1" && git add -A && git commit -qm "docs: done" && sdd check >/dev/null 2>&1 || fail "check failed"; }

# FR-24.6: R-1.2 opened before R-1.1: next and status say what it waits for.
sdd new --from R-1.2 >/dev/null 2>&1 || fail "new --from R-1.2 failed"
login=specs/changes/2-login-page/item.md
out=$(sdd next)
assert_contains "$out" 'Waits for: R-1.1 (not opened yet)'
assert_eq "$(printf '%s\n' "$out" | sed -n 4p)" 'Waits for: R-1.1 (not opened yet) (plan and build on; ship waits until they have shipped)'
assert_contains "$(sdd status)" 'waits   for R-1.1 (not opened yet)'

# FR-24.6: standard refuses to ship it, naming the ref; the branch stays as it was.
finish "$login"
before=$(git rev-parse HEAD)
out=$(sdd ship 2>&1)
assert_eq $? 1 "(ship with an unmet depends in standard)"
assert_contains "$out" 'item 2: waits for R-1.1 (not opened yet) (gate depends)'
assert_eq "$(git rev-parse HEAD)" "$before"
git cat-file -e main:specs/archive/2-login-page/item.md 2>/dev/null && fail "item 2 must not ship"

# FR-24.4: once R-1.1 is opened (item 3), the ref names that item until it ships.
git switch -q main
sdd new --from R-1.1 >/dev/null 2>&1 || fail "new --from R-1.1 failed"
auth=specs/changes/3-auth-api/item.md
git switch -q chore/2-login-page
assert_contains "$(sdd status)" 'waits   for 3 (Auth API, R-1.1)'
# FR-24.4: an ordinary item can name an item ID and an entry by hand.
git switch -q main
sdd new chore "Docs" >/dev/null 2>&1 || fail "new chore failed"
docs=specs/changes/4-docs/item.md
awk '{ print } $0 == "created: " d { print "depends: 3, R-1.3" }' d="$(sed -n 's/^created: //p' "$docs")" "$docs" >"$T/d" && cp "$T/d" "$docs"
git commit -qam "docs(4): depends"
assert_contains "$(sdd status)" 'waits   for 3 (Auth API), R-1.3 (not opened yet)'
# FR-24.6: ls on main and status's list of open items say it too.
git switch -q main
out=$(sdd ls)
assert_contains "$(printf '%s\n' "$out" | grep '^2 ')" '· waits for 3 (Auth API, R-1.1)'
assert_contains "$(printf '%s\n' "$out" | grep '^4 ')" '· waits for 3 (Auth API), R-1.3 (not opened yet)'
assert_not_contains "$(printf '%s\n' "$out" | grep '^3 ')" 'waits'
out=$(sdd status)
assert_contains "$out" '(git switch chore/2-login-page)   waits for 3 (Auth API, R-1.1)'
assert_contains "$(sdd ls --json | jq -r 'select(.id == 4) | .depends')" '3, R-1.3'
assert_contains "$(sdd ls --json | jq -r 'select(.id == 2) | .roadmap')" 'R-1.2'

# FR-24.4: item 3 ships; R-1.1 is met, so item 2 ships now.
git switch -q chore/3-auth-api
finish "$auth"
sdd ship >/dev/null 2>&1 || fail "ship 3 failed"
git switch -q chore/2-login-page
out=$(sdd next)
assert_not_contains "$out" 'Waits for'
out=$(sdd ship 2>&1) || fail "ship 2 after 3 failed: $out"
git cat-file -e main:specs/archive/2-login-page/item.md || fail "item 2 not shipped"

# FR-24.4: 3 shipped, R-1.3 not opened: only R-1.3 is unmet. FR-24.6: lite warns and ships.
git switch -q chore/4-docs
assert_eq "$(sdd status | sed -n 's/^waits   //p')" 'for R-1.3 (not opened yet) (ship waits until they have shipped)'
setcfg sdd.profile lite
finish "$docs"
out=$(sdd ship 2>&1) || fail "lite ship with an unmet depends failed: $out"
assert_contains "$out" 'warning: item 4: waits for R-1.3 (not opened yet) (gate depends)'
git cat-file -e main:specs/archive/4-docs/item.md || fail "item 4 not shipped in lite"
echo ok

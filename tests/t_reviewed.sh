# FR-22.4 sdd review records the code change's fingerprint (git patch-id from the merge base,
# specs/ left out); ship's reviewed gate (warn in lite and standard, block in strict) names what
# changed since, and a rebase that keeps the change keeps it reviewed.
. "$SRC/tests/lib.sh"
new_repo

# built: "## Built" written, with a verifier line (strict asks for one too, FR-22.3).
built() {
	awk '$0 == "## Built" { print; print "Filled in by the test (built)."; print "Verified by: m: 1 of 1 FRs proven; no findings"; next } { print }' "$ITEM" >"$T/i" && cp "$T/i" "$ITEM"
	git commit -qam "docs: built"
}

planned_item fix "Cache"
setcfg sdd.profile strict
mkdir -p src && echo a >src/a.js && echo b >src/b.js && git add src && git commit -qm "fix(1): cache"
built
seen=$(git rev-parse --git-common-dir)/sdd/checks/1.reviewed

# FR-22.4: strict refuses code nobody reviewed in this clone, naming the gate.
out=$(sdd ship 2>&1)
assert_eq $? 1 "(strict, no review)"
assert_contains "$out" 'not reviewed in this clone (gate reviewed): run .sdd/bin/sdd review'
sdd review >/dev/null
assert_file "$seen"

# FR-22.4: code changed after the review → refused, naming the file; specs/ changes do not count.
echo a2 >src/a.js && git commit -qam "fix(1): agent edit after review"
echo note >>"$ITEM" && git commit -qam "docs(1): a note"
out=$(sdd ship 2>&1)
assert_eq $? 1 "(strict, changed since review)"
assert_contains "$out" 'code changed since your review (src/a.js) (gate reviewed): run .sdd/bin/sdd review'
assert_not_contains "$out" 'src/b.js'

# FR-22.4: review again, then main moves on and the branch is rebased onto it: same change, so
# still reviewed, and strict ships.
sdd review >/dev/null
git switch -q main && echo other >other.txt && git add other.txt && git commit -qm "other work" && git switch -q -
git rebase -q main || fail "rebase failed"
out=$(sdd ship 2>&1) || fail "strict ship after a rebase failed: $out"
assert_not_contains "$out" 'review'
assert_contains "$out" 'shipped 1'

# FR-22.4: lite warns and ships.
planned_item fix "Evict"
setcfg sdd.profile lite
echo c >src/c.js && git add src && git commit -qm "fix(2): evict"
built
out=$(sdd ship 2>&1) || fail "lite ship without a review failed: $out"
assert_contains "$out" 'not reviewed in this clone (gate reviewed)'
assert_contains "$out" 'shipped 2'

# FR-22.4: an item that changes no code (docs only) has nothing to review.
planned_item fix "Docs only"
built
out=$(sdd ship 2>&1) || fail "docs-only ship failed: $out"
assert_not_contains "$out" 'review'
echo ok

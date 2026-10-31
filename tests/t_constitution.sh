# FR-3.1 articles parsed and well formed, FR-3.2 check articles run, FR-3.3 budget,
# FR-3.4 rules in next, FR-3.5 review articles to confirm, FR-3.6 guard, FR-3.7 amendment
# gates, FR-3.8 amendment diff in review. FR-44.1 a constitution with no C-<n> articles is named in
# check, next and review; FR-44.2 one with articles is not.
. "$SRC/tests/lib.sh"
new_repo

# Bootstrap: the first constitution may arrive in any item.
sdd new feature "Rules" >/dev/null 2>&1
f=specs/changes/1-rules/item.md
fill "$f" plan && sdd approve >/dev/null 2>&1 && fill "$f" built
cat >specs/constitution.md <<'EOF'
# Constitution
C-1 Nothing named forbidden.txt.
  Why: a test rule.
  Enforced: check test ! -f forbidden.txt

C-2 Humans own the data model.
  Why: a test rule.
  Enforced: review
EOF
out=$(sdd check 2>&1) || fail "check should pass: $out"
assert_not_contains "$out" 'has no C-<n> articles' # FR-44.2

# FR-3.1: an article without its Enforced line fails the check, naming it.
printf 'C-3 Unenforced.\n  Why: oops.\n' >>specs/constitution.md
out=$(sdd check 2>&1)
assert_eq $? 1
assert_contains "$out" '✗ constitution: C-3: no "Enforced:" line'
printf 'C-3 Unenforced.\n  Why: oops.\n  Enforced: maybe\n' >"$T/c3" && head -n 8 specs/constitution.md >"$T/c" && cat "$T/c" "$T/c3" >specs/constitution.md
assert_contains "$(sdd check 2>&1)" 'C-3: "Enforced:" must be review or check <command>'
printf 'C-3 No reason.\n  Enforced: review\n' >"$T/c3" && head -n 8 specs/constitution.md >"$T/c" && cat "$T/c" "$T/c3" >specs/constitution.md
assert_contains "$(sdd check 2>&1)" 'C-3: no "Why:" line'
printf 'C-3 Masked.\n  Why: oops.\n  Enforced: check false || true\n' >"$T/c3" && cat "$T/c" "$T/c3" >specs/constitution.md
assert_contains "$(sdd check 2>&1)" 'C-3 Masked. (its check hides failures: false || true)'
cp "$T/c" specs/constitution.md

# FR-3.2: a failing check article fails the check, naming the article.
touch forbidden.txt
out=$(sdd check 2>&1)
assert_eq $? 1
assert_contains "$out" '✗ constitution: C-1 Nothing named forbidden.txt. (its check failed)'
rm forbidden.txt

# FR-3.3: over budget.
git config -f .sdd/config constitution.max-articles 1
assert_contains "$(sdd check 2>&1)" '✗ constitution: over budget (2 of 1 articles)'
git config -f .sdd/config --unset constitution.max-articles

# FR-3.4 and FR-3.5: the rules ride along with instructions; review articles go to the human.
assert_contains "$(sdd next)" 'C-1 Nothing named forbidden.txt.'
sdd check >/dev/null 2>&1 || fail "check should pass again"
out=$(sdd review)
assert_contains "$out" 'Constitution: confirm each'
assert_contains "$out" '[ ] C-2 Humans own the data model.'
assert_not_contains "$out" '[ ] C-1'
git add -A && git commit -qm "constitution" && sdd ship >/dev/null 2>&1 || fail "bootstrap ship failed"

# FR-3.6: once on main, a feature may not touch it: check fails, ship refuses.
sdd new feature "Sneaky" >/dev/null 2>&1
f=$(ls specs/changes/2-*/item.md)
fill "$f" plan && sdd approve >/dev/null 2>&1 && fill "$f" built
echo 'C-9 Sneaked in.' >>specs/constitution.md
out=$(sdd check 2>&1)
assert_eq $? 1
assert_contains "$out" 'the constitution changes only through: .sdd/bin/sdd new amendment'
git add -A && git commit -qm sneak
out=$(sdd ship 2>&1)
assert_eq $? 1 "(ship must refuse)"
assert_contains "$out" 'the constitution changes only through'
git switch -q main

# vline <item file>: a verifier's line under "## Built".
vline() {
	awk '/^## Review/ { print "Verified by: test: 1 of 1 FRs proven; no findings" } { print }' "$1" >"$T/v" && cp "$T/v" "$1"
}

# FR-3.7: an amendment may change it, lands no code, and every gate blocks even in lite.
# Its Impact section is required: approve refuses while it is empty.
sdd new amendment "Allow forbidden.txt in docs" >/dev/null 2>&1
f=$(ls specs/changes/3-*/item.md)
fill "$f" plan
awk '/^## Impact$/ { print; skip = 1; next } skip && /^## / { skip = 0 } !skip' "$f" >"$T/a" && cp "$f" "$T/full" && cp "$T/a" "$f"
out=$(sdd approve 2>&1)
assert_eq $? 1 "(approve refuses an empty Impact)"
assert_contains "$out" 'Impact'
cp "$T/full" "$f"
sdd approve >/dev/null 2>&1 || fail "approve amendment failed"
sed 's/^C-1 Nothing named forbidden.txt./C-1 Nothing named forbidden.txt, except in docs\/./' specs/constitution.md >"$T/c" && cp "$T/c" specs/constitution.md
out=$(sdd check 2>&1) || fail "amendment check should pass: $out"
echo code >code.txt
out=$(sdd check 2>&1)
assert_eq $? 1
assert_contains "$out" 'an amendment lands no code'
rm code.txt
git add -A && git commit -qm amend
sdd check >/dev/null 2>&1
out=$(sdd ship 2>&1)
assert_eq $? 1 "(Built blocks for amendments, even in lite)"
assert_contains "$out" '"## Built" is not written yet'

# FR-3.8: review shows the constitution diff. Amendments need a verifier's line too (FR-22.3).
fill "$f" built && git commit -qam built
out=$(sdd ship 2>&1)
assert_eq $? 1 "(no verifier line blocks for amendments, even in lite)"
assert_contains "$out" 'verified'
vline "$f" && git commit -qam verified
out=$(sdd review)
assert_contains "$out" 'Constitution diff'
assert_contains "$out" '+C-1 Nothing named forbidden.txt, except in docs/.'
sdd ship >/dev/null 2>&1 || fail "amendment ship failed"
assert_contains "$(git show main:specs/constitution.md)" 'except in docs/'
# A check article added on main while an item is in flight runs at ship, after the rebase,
# even though the item's code check already passed (the code fingerprint did not change).
sdd new feature "In flight" >/dev/null 2>&1
f=$(ls specs/changes/4-*/item.md)
fill "$f" plan && sdd approve >/dev/null 2>&1 && fill "$f" built
echo feature >feature.txt && git add -A && git commit -qm feature
sdd check >/dev/null 2>&1 || fail "in-flight check should pass"
git switch -q main
sdd new amendment "No feature.txt" >/dev/null 2>&1
a=$(ls specs/changes/5-*/item.md)
fill "$a" plan && sdd approve >/dev/null 2>&1 && fill "$a" built && vline "$a"
printf '\nC-4 No feature.txt.\n  Why: a test rule.\n  Enforced: check test ! -f feature.txt\n' >>specs/constitution.md
git add -A && git commit -qm amend && sdd check >/dev/null 2>&1 && sdd ship >/dev/null 2>&1 || fail "amendment 5 ship failed"
git switch -q feature/4-in-flight
out=$(sdd ship 2>&1)
assert_eq $? 1 "(the new article must run at ship)"
assert_contains "$out" 'C-4 No feature.txt. (its check failed)'

# FR-44.1: a constitution in another format (Spec Kit's prose articles) yields no rules; say so
# in check (which still passes), next and review instead of showing nothing.
new_repo prose
mkdir -p specs && printf '# Constitution\n\n### I. Mechanism in Go, policy in Lisp\n\n- The core stays small.\n' >specs/constitution.md
git add -A && git commit -qm "prose constitution"
line='⚠ specs/constitution.md has no C-<n> articles, so no rule is shown or enforced: write each rule as "C-1 <rule>" with indented Why: and Enforced: lines (through an amendment item)'
sdd new feature "Prose" >/dev/null 2>&1 || fail "new failed"
assert_contains "$(sdd next 2>&1)" "$line"
out=$(sdd check 2>&1) || fail "check should still pass: $out"
assert_contains "$out" "$line"
assert_contains "$(sdd review 2>&1)" "$line"
exit 0

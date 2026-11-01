# FR-48.1 a docs-only change runs [check] run and skips [check] code; FR-48.2 any other change, no
# change, or no docs glob runs both; FR-48.3 code alone is a valid check, and is checked for masking.
. "$SRC/tests/lib.sh"
new_repo
setcfg check.code 'echo CODE-RAN'
setcfg --add check.docs '*.md'
setcfg --add check.docs 'docs/*'
log() { cat "$(git rev-parse --git-path "sdd/checks/$1.log")"; }

# FR-48.1: only docs changed (README.md at the root, a file under docs/): code is skipped.
planned_item feature "Docs"
id=$(sed -n 's/^id: //p' "$ITEM")
echo more >>README.md && mkdir -p docs && echo guide >docs/guide.txt
out=$(sdd check 2>&1) || fail "docs-only check failed: $out"
assert_contains "$out" "✓ check passed for item $id ("
assert_contains "$out" 's; docs-only change: skipped echo CODE-RAN)'
assert_not_contains "$(log "$id")" 'CODE-RAN'
assert_contains "$(log "$id")" '$ echo ok'

# FR-48.2: one path that is not docs (*.md does not match notes.md.txt) runs everything.
echo x >notes.md.txt
out=$(sdd check 2>&1) || fail "check failed: $out"
assert_not_contains "$out" 'docs-only change'
assert_contains "$(log "$id")" 'CODE-RAN'
rm notes.md.txt

# FR-48.2: on the base, nothing changed: everything runs.
git checkout -q README.md && rm -r docs
git switch -q main
sdd check >/dev/null 2>&1 || fail "check on main failed"
assert_contains "$(log none)" 'CODE-RAN'

# FR-48.2: no docs glob set: everything runs.
new_repo nodocs
setcfg check.code 'echo CODE-RAN'
planned_item feature "Docs"
id=$(sed -n 's/^id: //p' "$ITEM")
echo more >>README.md
sdd check >/dev/null 2>&1 || fail "check failed"
assert_contains "$(log "$id")" 'CODE-RAN'

# FR-48.3: code without run is a check; a code line that hides failures is refused.
new_repo codeonly
git config -f .sdd/config --unset-all check.run
setcfg check.code 'echo ok'
out=$(sdd check 2>&1) || fail "a code-only check should pass: $out"
setcfg check.code 'false || true'
out=$(sdd check 2>&1)
assert_eq $? 1
assert_contains "$out" 'refusing a check that hides failures: false || true'
exit 0

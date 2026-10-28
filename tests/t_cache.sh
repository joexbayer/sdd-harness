# Item 18 (performance): the facts derived from an item file are cached in .git/sdd/cache/ under
# the file's hash, its origin and path, the sdd code and the config. Changing any of them is a
# miss; facts that depend on a check result are never cached; deleting the cache changes nothing
# but speed (C-2).
. "$SRC/tests/lib.sh"
new_repo

mkdir -p specs/archive/1-one
printf -- '---\nid: 1\ntype: chore\ntitle: One\nstatus: shipped\nshipped: 2026-01-02\n---\n# 1 One\n\n## Why\nA reason.\n' \
	>specs/archive/1-one/item.md
git add -A && git commit -qm "docs(1): open chore \"One\""

real=$(sdd ls) || fail "ls failed: $real"
assert_contains "$real" 'One'
cache() { ls .git/sdd/cache/facts.* 2>/dev/null; }
[ "$(cache | wc -l)" -eq 1 ] || fail "expected one cache file, got: $(cache)"
assert_eq "$(wc -l <"$(cache)" | tr -d ' ')" 1

# poison: change the cached title of every row, so a hit shows "Cached".
poison() {
	_c=$(cache) && awk -F '\t' -v OFS='\t' '{ $11 = "Cached" } { print }' "$_c" >"$T/c" && cat "$T/c" >"$_c"
	assert_contains "$(sdd ls)" 'Cached'
}

# The item file changes: a miss.
poison
printf 'More reasons.\n' >>specs/archive/1-one/item.md && git commit -qam "docs: edit 1"
assert_not_contains "$(sdd ls)" 'Cached'

# The config changes: a miss.
poison
setcfg sdd.profile standard
assert_not_contains "$(sdd ls)" 'Cached'

# The sdd code (version or library) changes: a miss.
poison
echo 9.9.9 >.sdd/VERSION
assert_not_contains "$(sdd ls)" 'Cached'
poison
echo '# a comment' >>.sdd/core/lib/common.sh
assert_not_contains "$(sdd ls)" 'Cached'
git checkout -q -- .sdd

# The same file under another id's folder (its path) is a row of its own.
cp -r specs/archive/1-one specs/archive/3-three && git add -A && git commit -qm "docs(3): open chore \"Three\""
assert_contains "$(sdd ls --json)" '"id":3,"type":"chore","status":"shipped","phase":"done","frs":0,"tasks_done":0,"tasks_total":0,"title":"One"'

# Deleting the cache changes nothing but speed.
before=$(sdd ls --json)
rm -rf .git/sdd/cache
assert_eq "$(sdd ls --json)" "$before"

# A phase that depends on a check result is never cached: after a passing check the item is in
# review, and once its branch's code changes it is back in build.
planned_item chore "Two"
fill "$ITEM" built && git commit -qam "built 2"
sdd check >/dev/null 2>&1 || fail "check 2 failed"
git switch -q main
assert_contains "$(sdd ls)" 'review   FR 0   T -      Two'
git switch -q chore/4-two && echo code >code.txt && git add code.txt && git commit -qm "chore(4): code" && git switch -q main
assert_contains "$(sdd ls)" 'build    FR 0   T -      Two'
assert_not_contains "$(cat "$(cache)")" '4-two'

# The current item's own row (the working tree) is never cached either: an edit shows at once.
git switch -q chore/4-two
sed 's/^title: Two$/title: Two edited/' "$ITEM" >"$T/i" && cp "$T/i" "$ITEM"
assert_contains "$(sdd ls)" 'Two edited'

# Item 23: the commands agents call constantly run few git processes. Counts do not depend on
# machine load, so they catch a regression t_perf (timing) misses on a busy machine.
. "$SRC/tests/lib.sh"
new_repo

sdd new feature "Paging" >/dev/null 2>&1
f=specs/changes/1-paging/item.md
fill "$f" plan
awk '/^## What changes$/ { print; print "FR-1.1 WHEN a page is asked for THE SYSTEM SHALL return 20 orders."; print "  e.g. page 1 → orders 1-20"; print ""; next }
/^## Tasks \(optional\)$/ { print
	print "- [ ] T-1.1 Query, FR-1.1 (files: src.txt; test: true)"
	print "- [ ] T-1.2 Page, FR-1.1 (test: true)"; print ""; next } { print }' "$f" >"$T/f" && cp "$T/f" "$f"
git commit -qam "docs(1): plan" && sdd approve >/dev/null 2>&1 || fail "approve failed"
echo code >src.txt && sdd task 'done' T-1.1 >/dev/null 2>&1 && git add -A && git commit -qm "feat(1): T-1.1 query" || fail "T-1.1 failed"
assert_contains "$(sdd next)" 'T-1.2 Page'

# A git that logs each call, first on PATH.
mkdir -p "$T/bin"
real=$(command -v git)
printf '#!/bin/sh\necho "$*" >>"%s/git.log"\nexec "%s" "$@"\n' "$T" "$real" >"$T/bin/git"
chmod +x "$T/bin/git"
# calls <command>: how many git processes the command ran (its own output dropped).
calls() {
	: >"$T/git.log"
	PATH="$T/bin:$PATH" "$SH" -c "$1" >/dev/null 2>&1
	wc -l <"$T/git.log" | tr -d ' '
}
s="$SH .sdd/bin/sdd"
hook_in=$(printf '{"cwd":"%s","stop_hook_active":false}' "$PWD")
calls "$s next" >/dev/null # the first run writes the caches
# limit <max> <command>: the command runs at most <max> git processes (the log shows which).
limit() {
	n=$(calls "$2")
	[ "$n" -le "$1" ] || fail "$n git calls (at most $1): $2
$(cat "$T/git.log")"
}
# hook stop mid-build: rev-parse and one diff (was 9); next and status: rev-parse (were 6).
limit 3 "printf '%s' '$hook_in' | $s hook stop --agent claude"
limit 2 "$s next"
limit 2 "$s status"

# The caches never hide an edit, even one in the second they were written.
calls "$s next" >/dev/null
git config -f .sdd/config --replace-all check.run "echo cfg-a >$T/which"
sdd check >/dev/null 2>&1; assert_eq "$(cat "$T/which")" cfg-a
git config -f .sdd/config --replace-all check.run "echo cfg-b >$T/which"
sdd check >/dev/null 2>&1; assert_eq "$(cat "$T/which")" cfg-b
# A user config that appears, then goes, is seen at once.
git config -f .sdd/config --unset-all check.run
mkdir -p "$XDG_CONFIG_HOME/sdd"
printf '[check]\n\trun = echo user-cfg >%s/which\n' "$T" >"$XDG_CONFIG_HOME/sdd/config"
sdd check >/dev/null 2>&1; assert_eq "$(cat "$T/which")" user-cfg
rm "$XDG_CONFIG_HOME/sdd/config"
assert_contains "$(sdd check 2>&1)" 'no check configured'
git checkout -q -- .sdd/config
# A plan edit right after its hash was cached voids the approval at once.
assert_contains "$(sdd next)" 'Phase: build'
awk '/^## What changes$/ { print; print "FR-1.2 WHEN y THE SYSTEM SHALL z."; next } { print }' "$f" >"$T/g" && cp "$T/g" "$f"
assert_contains "$(sdd next)" 'Phase: plan'
git checkout -q -- "$f"
assert_contains "$(sdd next)" 'Phase: build'
# Another branch is read from HEAD at once, and a detached HEAD has no item.
git switch -q main
assert_not_contains "$(sdd next 2>&1)" 'Item 1 (feature)'
git switch -q --detach feature/1-paging
assert_not_contains "$(sdd next 2>&1)" 'Item 1 (feature)'
git switch -q feature/1-paging
assert_contains "$(sdd next)" 'Item 1 (feature)'
echo ok

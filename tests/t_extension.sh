# FR-61.3 an extension that is on adds its text after the step's own, in next and review; FR-61.4 a
# missing tool skips it; FR-61.5 none on changes nothing; FR-61.6 local folders count, and nothing in
# one is ever run.
. "$SRC/tests/lib.sh"
new_repo
d=.sdd/local/extensions/mine
mkdir -p "$d"
git config -f "$d/extension" extension.description 'A test add-on'
git config -f "$d/extension" extension.needs faketool
git config -f "$d/extension" extension.url https://example.test
for s in plan build review; do echo "EXT-$s for item {{id}}" >"$d/$s.md"; done
printf 'touch "$0.ran"\n' >"$d/run.sh"
git add -A && git commit -qm "a local extension"
mkdir -p "$T/tools" && printf '#!/bin/sh\n' >"$T/tools/faketool" && chmod +x "$T/tools/faketool"
withtool() { (PATH="$T/tools:$PATH" && export PATH && "$@"); }

# FR-61.5: not on: nothing.
sdd new feature "Paging" >/dev/null 2>&1
f=specs/changes/1-paging/item.md
assert_not_contains "$(withtool sdd next 2>&1)" 'EXT-'

# FR-61.3: on (a developer's own config counts): the plan step's text only, after the step's own, once.
mkdir -p "$XDG_CONFIG_HOME/sdd" && git config -f "$XDG_CONFIG_HOME/sdd/config" --add sdd.extension mine
out=$(withtool sdd next 2>&1)
assert_contains "$out" 'EXT-plan for item 1'
assert_not_contains "$out" 'EXT-build'
assert_eq "$(printf '%s\n' "$out" | grep -c 'EXT-plan')" 1 "(a feature's plan.feature step must not repeat it)"
[ "$(printf '%s\n' "$out" | grep -n 'PLAN: this is' | cut -d: -f1)" -lt "$(printf '%s\n' "$out" | grep -n 'EXT-plan' | cut -d: -f1)" ] ||
	fail "the extension's text comes after the step's own"

# FR-61.4: the tool it needs is missing: skipped.
assert_not_contains "$(sdd next 2>&1)" 'EXT-'

# FR-61.3: the build step's text; the review step's, in next and in review.
fill "$f" plan
awk '/^## What changes$/ { print; print "FR-1.1 WHEN asked THE SYSTEM SHALL page."; print "  e.g. page 2"; next } { print }' "$f" >"$T/f" && cp "$T/f" "$f"
git commit -qam "docs(1): plan" && sdd approve >/dev/null 2>&1 || fail "approve failed"
out=$(withtool sdd next 2>&1)
assert_contains "$out" 'EXT-build for item 1'
assert_not_contains "$out" 'EXT-plan'
echo code >code.txt && git add -A && git commit -qm "feat(1): code"
sdd check >/dev/null 2>&1 || fail "check failed"
fill "$f" built
awk '/^## Review/ { print "Verified by: test: 1 of 1 FRs proven; no findings" } { print }' "$f" >"$T/f" && cp "$T/f" "$f"
git commit -qam "docs(1): built" && sdd check >/dev/null 2>&1
out=$(withtool sdd next 2>&1)
assert_contains "$out" 'Phase: review'
assert_contains "$out" 'EXT-review for item 1'
assert_contains "$(withtool sdd review 2>&1)" 'EXT-review for item 1'
assert_not_contains "$(sdd review 2>&1)" 'EXT-review'

# FR-61.6: nothing in the folder was run; a name that is not a plain word is ignored.
[ ! -e "$d/run.sh.ran" ] || fail "an extension's script ran"
git config -f "$XDG_CONFIG_HOME/sdd/config" --add sdd.extension '../../evil'
withtool sdd next >/dev/null 2>&1 || fail "a bad extension name must not break next"
exit 0

# FR-61.3 an extension that is on adds its text after the step's own, in next and review; FR-61.4 a
# missing tool skips it; FR-61.5 none on changes nothing; FR-61.6 local folders count, and nothing in
# one is ever run. FR-61.1 add, remove; FR-61.2 list.
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

# FR-61.1, FR-61.2: the command, on a fresh repo: team and personal lists, off by default.
new_repo cmd
rm -f "$XDG_CONFIG_HOME/sdd/config"
d=.sdd/local/extensions/mine
mkdir -p "$d" && git config -f "$d/extension" extension.description 'A test add-on'
git config -f "$d/extension" extension.needs faketool && git config -f "$d/extension" extension.url https://example.test
git add -A && git commit -qm "a local extension"
assert_contains "$(sdd extension list 2>&1)" 'A test add-on'
assert_contains "$(sdd extension list 2>&1)" 'off'
assert_contains "$(sdd extension list 2>&1)" 'needs faketool, not installed'
assert_not_contains "$(withtool sdd extension list 2>&1)" 'not installed'
# Unknown names and names that are not plain words are refused.
out=$(sdd extension add nope 2>&1)
assert_eq $? 1 "(unknown extension)"
assert_contains "$out" 'unknown extension: nope'
sdd extension add '../x' >/dev/null 2>&1
assert_eq $? 1 "(a name that is not a word)"
# Just you: the user config; the tool's url when it is missing.
out=$(sdd extension add mine --me 2>&1) || fail "add --me failed: $out"
assert_contains "$out" 'faketool is not installed: https://example.test'
assert_eq "$(git config -f "$XDG_CONFIG_HOME/sdd/config" --get-all sdd.extension)" mine
assert_eq "$(git config -f .sdd/config --get-all sdd.extension)" ''
assert_contains "$(withtool sdd extension list 2>&1)" 'on (you)'
out=$(sdd extension remove mine --me 2>&1) || fail "remove --me failed: $out"
assert_eq "$(git config -f "$XDG_CONFIG_HOME/sdd/config" --get-all sdd.extension)" ''
# The team: .sdd/config, uncommitted; adding twice does not repeat it.
head=$(git rev-parse HEAD)
withtool sdd extension add mine >/dev/null 2>&1 || fail "add failed"
withtool sdd extension add mine >/dev/null 2>&1 || fail "second add failed"
assert_eq "$(git config -f .sdd/config --get-all sdd.extension)" mine
assert_eq "$(git rev-parse HEAD)" "$head" "(add commits nothing)"
assert_contains "$(withtool sdd extension list 2>&1)" 'on (team)'
sdd extension remove mine >/dev/null 2>&1 || fail "remove failed"
assert_eq "$(git config -f .sdd/config --get-all sdd.extension)" ''
sdd extension remove mine >/dev/null 2>&1
assert_eq $? 1 "(removing one that is not on)"
exit 0

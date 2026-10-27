# FR-9.1 an unclosed frontmatter is the phase reason; FR-9.2 approve and ship refuse before
# changing anything; FR-9.3 fm_set fails instead of silently writing nothing.
. "$SRC/tests/lib.sh"
new_repo
sdd new feature "Broken head" >/dev/null 2>&1
f=specs/changes/1-broken-head/item.md
fill "$f" plan
awk 'NR == 7 && $0 == "---" { next } { print }' "$f" >"$T/f" && cp "$T/f" "$f"
git commit -qam "docs(1): plan, header cut"
before=$(git rev-parse HEAD)
copy=$(cat "$f")

# FR-9.1: next, status and ls say what is wrong and how to fix it.
assert_contains "$(sdd next)" 'the --- block at the top is not closed; add --- after its last key'
assert_contains "$(sdd status)" 'the --- block at the top is not closed'
assert_eq "$(sdd ls --json | jq -r 'select(.id == 1) | .reason_code')" frontmatter

# FR-9.2: approve and ship refuse with the same message and change nothing.
out=$(sdd approve 2>&1)
assert_eq $? 1 "(approve)"
assert_contains "$out" 'item 1: the --- block at the top is not closed'
out=$(sdd ship 2>&1)
assert_eq $? 1 "(ship)"
assert_contains "$out" 'item 1: the --- block at the top is not closed'
assert_eq "$(git rev-parse HEAD)" "$before" "(no commit)"
assert_eq "$(cat "$f")" "$copy" "(file untouched)"

# FR-9.3: fm_set fails and leaves the file as it was.
(
	SDD_HOME="$SRC/.sdd"
	. "$SRC/.sdd/core/lib/common.sh"
	fm_set "$f" approved x
) && fail "fm_set should fail on an unclosed frontmatter"
assert_eq "$(cat "$f")" "$copy" "(fm_set left the file)"
assert_no_file "$f.tmp.$$"
exit 0

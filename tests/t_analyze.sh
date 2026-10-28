# FR-19.1 sdd analyze: the plan's problems, one line each; FR-19.2 the analyzed gate at approve;
# FR-19.3 the problems in next's plan step; FR-19.4 the gap checklist in the plan prompt.
. "$SRC/tests/lib.sh"
new_repo

# plan <file> <what changes> <how> <questions> <tasks>: fill the plan and put each text under
# its heading (lines separated by \n).
plan() {
	fill "$1" plan
	W=$2 H=$3 Q=$4 K=$5 awk '
		function put(s,   n, a, i) { n = split(s, a, "\\\\n"); for (i = 1; i <= n; i++) print a[i]; print "" }
		{ print }
		$0 == "## What changes" { put(ENVIRON["W"]) }
		$0 == "## How" { put(ENVIRON["H"]) }
		$0 == "## Questions (optional)" { put(ENVIRON["Q"]) }
		$0 == "## Tasks (optional)" { put(ENVIRON["K"]) }' "$1" >"$T/plan" && cp "$T/plan" "$1"
	git add "$1" && git commit -qm "docs: plan"
}

sdd new feature "Orders export" >/dev/null 2>&1
f=specs/changes/1-orders-export/item.md
plan "$f" \
	'FR-1.1 WHEN the user asks THE SYSTEM SHALL list orders.\n  e.g. GET /orders → 20 orders\nFR-1.2 WHEN the user asks for a file THE SYSTEM SHALL export as CSV.\nFR-1.3 WHEN an order is bad THE SYSTEM SHALL\n  reject it with a reason.\n  e.g. no total → "total missing"\n```\nFR-1.7 inside a fence is not a requirement\n```' \
	'D-1.1 Plain CSV, because spreadsheets read it.\nD-1.1 Plain CSV again.' \
	'Q-1.1 Which date format? → recommend: ISO 8601.\nQ-1.2 How many orders a page, or\n  all at once? → recommend: 20. → decided: 20 (test, 2026-10-28)' \
	'- [ ] T-1.1 List orders, FR-1.1 (files: a.sh; test: sh a.sh)\n- [ ] T-1.2 Reject bad orders, FR-1.3, FR-1.9 (files: b.sh)\n- [ ] T-1.3 Docs (files: README.md; tests: sh x.sh)'

# FR-19.1: one line per problem, in plan order, exit 1. Comments (the template's FR-1.1
# example), fenced lines and a decision on a wrapped line are not problems.
out=$(sdd analyze 2>&1)
assert_eq $? 1 "(analyze with problems)"
assert_eq "$out" "✗ FR-1.2 (export as CSV): no e.g. example under it
✗ FR-1.2 (export as CSV): no task names it
✗ D-1.1 (Plain CSV, because spreadsheets read it): written twice
✗ Q-1.1 (Which date format?): not decided
✗ T-1.2 (Reject bad orders): names FR-1.9, which the plan does not have
✗ T-1.3 (Docs): cannot read it: unknown attribute tests (known: files, test, expect, size)"
# FR-19.1: an item by its id, from another branch.
git checkout -q main
out2=$(sdd analyze 1 2>&1)
assert_eq $? 1 "(analyze 1 from main)"
assert_eq "$out2" "$out"
sdd analyze 99 >/dev/null 2>&1
assert_eq $? 1 "(no item 99)"
sdd analyze x >/dev/null 2>&1
assert_eq $? 2 "(analyze x)"

# FR-19.1: a plan with no tasks names no "no task" problem; a clean plan exits 0.
sdd new feature "Orders paging" >/dev/null 2>&1
g=specs/changes/2-orders-paging/item.md
plan "$g" 'FR-2.1 WHEN a page is asked for THE SYSTEM SHALL return 20 orders.\n  e.g. page 2 → orders 21-40' \
	'D-2.1 Offsets, because the table is small.' 'Q-2.1 Page size? → decided: 20 (test, 2026-10-28)' ''
out=$(sdd analyze 2>&1)
assert_eq $? 0 "(clean plan: $out)"
assert_contains "$out" 'no problems'
sdd approve >/dev/null 2>&1 || fail "approve of a clean plan failed"

# FR-19.2: standard blocks approval while the analysis finds problems.
git checkout -q feature/1-orders-export
setcfg sdd.profile standard
out=$(sdd approve 2>&1)
assert_eq $? 1 "(standard approve with problems)"
assert_contains "$out" '✗ Q-1.1 (Which date format?): not decided'
[ -z "$(sed -n 's/^approved: //p' "$f")" ] || fail "standard approved a plan with problems"
# FR-19.2: lite warns, prints the problems and approves anyway.
setcfg sdd.profile lite
out=$(sdd approve 2>&1) || fail "lite approve with problems failed: $out"
assert_contains "$out" '✗ Q-1.1 (Which date format?): not decided'
assert_contains "$out" 'warning'
assert_contains "$out" 'approved'
[ -n "$(sed -n 's/^approved: //p' "$f")" ] || fail "lite did not approve"
# FR-19.2: a level set for the gate beats the profile's.
git checkout -q feature/2-orders-paging
awk '{ print } /^Q-2\.1 / { print "Q-2.2 Sort order? → recommend: newest first." }' "$g" >"$T/plan" && cp "$T/plan" "$g"
git commit -qam "docs(2): open question"
setcfg profile.lite.analyzed block
out=$(sdd approve 2>&1)
assert_eq $? 1 "(analyzed = block in lite)"
assert_contains "$out" '✗ Q-2.2 (Sort order?): not decided'

# FR-19.3: next, in the plan phase with the plan filled in, lists the problems to fix first.
git checkout -q main
sdd new feature "Orders search" >/dev/null 2>&1
h=specs/changes/3-orders-search/item.md
out=$(sdd next)
assert_not_contains "$out" 'Before asking for approval, fix:'
plan "$h" 'FR-3.1 WHEN a word is searched for THE SYSTEM SHALL list matching orders.' '' '' ''
out=$(sdd next)
assert_contains "$out" 'Phase: plan (waiting for the human to approve'
assert_contains "$out" 'Before asking for approval, fix:
✗ FR-3.1 (list matching orders): no e.g. example under it'
awk '{ print } /^FR-3\.1 / { print "  e.g. \"ink\" → orders 4 and 9" }' "$h" >"$T/plan" && cp "$T/plan" "$h"
git commit -qam "docs(3): example"
assert_not_contains "$(sdd next)" 'Before asking for approval, fix:'
# FR-19.3: not in the build phase.
git checkout -q feature/1-orders-export || fail "checkout"
assert_not_contains "$(sdd next)" 'Before asking for approval, fix:'

# FR-19.4: the plan step tells the agent to look for gaps and ask about each one.
git checkout -q feature/3-orders-search || fail "checkout"
out=$(sdd next)
for c in 'check the plan for gaps' 'scope edges' 'errors and edge cases' 'data and state' 'speed' \
	'several developers at once' 'security' 'Ask the human about each gap you find'; do
	assert_contains "$out" "$c"
done

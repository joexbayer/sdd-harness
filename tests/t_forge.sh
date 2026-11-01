# FR-10.1 ship opens a PR; FR-10.2 shipping again pushes new commits into it; FR-10.3 and again
# merges it; FR-10.4 not while CI fails or is pending, or the PR is closed; FR-10.5 PR state in
# status, ls, review; FR-10.6 gh missing or logged out; FR-10.7 init suggests the forge. FR-54.1 the
# PR body points at the item file; FR-54.2 a later ship leaves it alone.
# GitHub is a stub gh (below) over a bare origin: nothing here talks to the network.
. "$SRC/tests/lib.sh"
new_repo
git init -q --bare "$T/origin.git" && git remote add origin "$T/origin.git"
git push -q origin main
# A constitution with three articles: its check runs before every merge (and once clobbered the
# PR number, item 13).
mkdir -p specs && printf 'C-1 One.\n  Why: a.\n  Enforced: check true\n\nC-2 Two.\n  Why: b.\n  Enforced: review\n\nC-3 Three.\n  Why: c.\n  Enforced: review\n' >specs/constitution.md
git add specs && git commit -qm "docs: constitution"
setcfg sdd.forge github && git push -q origin main

# The stub keeps PRs in $T/gh/prs as "<branch> <number> <state> <review> <url> <head>" (tabs),
# newest first, answers pr list with sdd's PR line (the head read live from origin while open),
# and merges on the bare origin with a merge commit, like GitHub. $T/gh/ci sets the CI result,
# $T/gh/auth the exit code of gh auth status.
mkdir -p "$T/bin" "$T/gh"
: >"$T/gh/prs"
cat >"$T/bin/gh" <<'STUB'
#!/bin/sh
G=$GH_STATE
echo "$*" >>"$G/log"
head_of() { git --git-dir="$GH_ORIGIN" rev-parse -q --verify "refs/heads/$1" 2>/dev/null; }
case "$1 $2" in
"auth status") exit "$(cat "$G/auth" 2>/dev/null || echo 0)" ;;
"pr list")
	want=
	while [ $# -gt 0 ]; do [ "$1" = --head ] && want=$2; shift; done
	ci=$(cat "$G/ci" 2>/dev/null || echo passing)
	awk -F '\t' -v OFS='\t' -v w="$want" -v ci="$ci" -v o="$GH_ORIGIN" '
		w != "" && $1 != w { next }
		{ h = $6; if ($3 == "OPEN") { c = "git --git-dir=" o " rev-parse -q --verify refs/heads/" $1; c | getline h; close(c) }
		  print $1, $2, $3, $4, ci, $5, h; if (w != "") exit }' "$G/prs"
	;;
"pr create")
	shift 2
	while [ $# -gt 0 ]; do
		case $1 in --head) b=$2 ;; --title) t=$2 ;; --body) body=$2 ;; esac
		shift
	done
	n=$(($(wc -l <"$G/prs") + 1))
	{ printf '%s\t%s\tOPEN\t\thttps://github.test/pr/%s\t\n' "$b" "$n" "$n"; cat "$G/prs"; } >"$G/prs.new" && mv "$G/prs.new" "$G/prs"
	printf '%s\n' "$body" >"$G/body.$n" && echo "$t" >"$G/title.$n"
	echo "https://github.test/pr/$n"
	;;
"pr merge")
	n=$3 sha=$6
	b=$(awk -F '\t' -v n="$n" '$2 == n { print $1 }' "$G/prs")
	[ "$(head_of "$b")" = "$sha" ] || { echo "head changed" >&2; exit 1; }
	rm -rf "$G/m" && git clone -q "$GH_ORIGIN" "$G/m" &&
		git -C "$G/m" merge -q --no-ff -m "Merge pull request #$n from $b" "origin/$b" &&
		git -C "$G/m" push -q origin HEAD || exit 1
	awk -F '\t' -v OFS='\t' -v n="$n" -v h="$sha" '$2 == n { $3 = "MERGED"; $6 = h } { print }' "$G/prs" >"$G/prs.new" &&
		mv "$G/prs.new" "$G/prs"
	;;
*) echo "stub gh: unexpected: $*" >&2; exit 1 ;;
esac
STUB
chmod +x "$T/bin/gh"
PATH="$T/bin:$PATH" GH_STATE="$T/gh" GH_ORIGIN="$T/origin.git"
export PATH GH_STATE GH_ORIGIN

planned_item feature "Faster search"
echo fast >search.txt && git add search.txt && git commit -qm "feat(1): search"
fill "$ITEM" built && git commit -qam "docs(1): built"

# FR-10.6: gh logged out: ship stops with the fix, status says the PR state is unknown.
echo 1 >"$T/gh/auth"
out=$(sdd ship 2>&1)
assert_eq $? 1 "(gh logged out)"
assert_contains "$out" 'ship goes through GitHub (forge = github): gh is not logged in (run: gh auth login)'
assert_contains "$(sdd ls --pr)" 'pr      state unknown: gh is not logged in'
# FR-27.1, FR-27.2: ls without --pr, and review before any PR, never run gh.
n=$(wc -l <"$T/gh/log")
sdd ls >/dev/null; sdd ls --json >/dev/null; sdd review >/dev/null
assert_eq "$(wc -l <"$T/gh/log")" "$n" "(ls and review before a PR called gh)"
assert_not_contains "$(sdd review)" 'pr      '
echo 0 >"$T/gh/auth"
# FR-10.6: gh not installed at all.
nogh=$(printf '%s\n' "$PATH" | tr ':' '\n' | while IFS= read -r d; do [ -x "$d/gh" ] || printf '%s:' "$d"; done)
assert_contains "$(PATH=$nogh sdd ship 2>&1)" 'gh is not installed'

# FR-10.1: gates, archive on the branch, push, PR; main is untouched. FR-54.1: the body points at
# the item file instead of copying it.
main_before=$(git rev-parse main)
out=$(sdd ship 2>&1) || fail "ship failed: $out"
assert_contains "$out" 'PR opened for item 1: https://github.test/pr/1'
assert_eq "$(cat "$T/gh/title.1")" 'feature(1): Faster search'
assert_eq "$(cat "$T/gh/body.1")" 'Item 1 (feature): Faster search

The plan, its requirements and the build notes: `specs/archive/1-faster-search/item.md` on this branch.'
assert_eq "$(git --git-dir="$T/origin.git" rev-parse feature/1-faster-search)" "$(git rev-parse HEAD)"
assert_eq "$(git rev-parse main)" "$main_before" "(main moves only when the PR merges)"

# FR-10.5: the PR in status, ls (text and JSON) and review; the phase says it waits to merge.
out=$(sdd status)
assert_contains "$out" 'phase   pr'
assert_contains "$out" 'pr      PR #1 open: no review yet, CI passing   https://github.test/pr/1'
assert_contains "$(sdd ls --pr)" '· PR #1 open: no review yet, CI passing'
assert_not_contains "$(sdd ls)" 'PR #1'
assert_eq "$(sdd ls --pr --json | jq -r 'select(.id == 1) | "\(.pr.number) \(.pr.state) \(.pr.ci)"')" '1 OPEN passing'
assert_contains "$(sdd review)" 'pr      PR #1 open'
assert_contains "$(sdd summary --md)" 'in a pull request, waiting to merge'
# FR-51.1: the pr step's ship hand-off names the skill, with the command as fallback.
assert_contains "$(sdd next 2>&1)" 'they run `/sdd-ship` (or `.sdd/bin/sdd ship`) again once CI passes'

# FR-10.4: no merge while CI is pending or failing.
echo "pending: test" >"$T/gh/ci"
out=$(sdd ship 2>&1)
assert_eq $? 1 "(CI pending)"
assert_contains "$out" 'PR #1: CI pending: test; ship again when it passes'
echo "failing: lint" >"$T/gh/ci"
assert_contains "$(sdd ship 2>&1)" 'CI failing: lint'
assert_eq "$(grep -c 'pr merge' "$T/gh/log")" 0 "(no merge was tried)"
awk -F '\t' -v OFS='\t' '$2 == 1 { $4 = "CHANGES_REQUESTED" } { print }' "$T/gh/prs" >"$T/gh/p" && mv "$T/gh/p" "$T/gh/prs"
assert_contains "$(sdd ship 2>&1)" 'PR #1: changes requested'
awk -F '\t' -v OFS='\t' '$2 == 1 { $4 = "APPROVED" } { print }' "$T/gh/prs" >"$T/gh/p" && mv "$T/gh/p" "$T/gh/prs"
echo passing >"$T/gh/ci"

# FR-10.2: new local commits are checked, pushed, and the body updated; no second PR.
echo faster >search.txt && git commit -qam "fix(1): review comment"
out=$(sdd ship 2>&1) || fail "second ship failed: $out"
assert_contains "$out" 'pushed new commits to PR #1'
assert_eq "$(git --git-dir="$T/origin.git" rev-parse feature/1-faster-search)" "$(git rev-parse HEAD)"
assert_eq "$(wc -l <"$T/gh/prs" | tr -d ' ')" 1
assert_eq "$(grep -c 'pr edit' "$T/gh/log")" 0 "(FR-54.2: the body is left alone)"

# FR-10.3: shipped again with nothing new: merged with a merge commit, base updated, branches gone.
out=$(sdd ship 2>&1) || fail "merge failed: $out"
assert_contains "$out" 'merged PR #1 into main'
assert_contains "$out" 'branch feature/1-faster-search deleted'
assert_eq "$(git symbolic-ref --short HEAD)" main
assert_eq "$(git log -1 --format=%s main)" 'Merge pull request #1 from feature/1-faster-search'
assert_file specs/archive/1-faster-search/item.md
assert_eq "$(git --git-dir="$T/origin.git" rev-parse -q --verify feature/1-faster-search)" ''
assert_contains "$(grep 'pr merge' "$T/gh/log")" '--merge --match-head-commit'

# FR-10.3, FR-10.4: a PR whose head moved (a teammate pushed) or that was closed is not merged.
planned_item fix "Typo"
mkdir -p .github/workflows && echo "on: push" >.github/workflows/ci.yml
echo typo >typo.txt && git add -A && git commit -qm "fix(2): typo"
fill "$ITEM" built && git commit -qam "docs(2): built"
out=$(sdd ship 2>&1) || fail "ship 2 failed: $out"
# FR-10.4: CI says nothing yet although the branch has workflows: not a pass.
echo none >"$T/gh/ci"
assert_contains "$(sdd ship 2>&1)" 'PR #2: CI has not reported yet'
echo passing >"$T/gh/ci"
git clone -q "$T/origin.git" "$T/mate"
# FR-10.3: main moved on the remote: the branch must contain it before anything merges.
(cd "$T/mate" && echo other >other.txt && git add other.txt && git commit -qm other && git push -q origin main) ||
	fail "teammate main push failed"
out=$(sdd ship 2>&1)
assert_eq $? 1 "(behind origin/main)"
assert_contains "$out" 'fix/2-typo is behind origin/main: git merge origin/main'
git merge -q --no-edit origin/main
(cd "$T/mate" && git switch -q fix/2-typo && echo mate >mate.txt && git add mate.txt && git commit -qm mate &&
	git push -q origin HEAD) || fail "teammate push failed"
out=$(sdd ship 2>&1)
assert_eq $? 1 "(head moved)"
assert_contains "$out" 'PR #2 has commits this branch lacks'
awk -F '\t' -v OFS='\t' '$2 == 2 { $3 = "CLOSED" } { print }' "$T/gh/prs" >"$T/gh/p" && mv "$T/gh/p" "$T/gh/prs"
out=$(sdd ship 2>&1)
assert_eq $? 1 "(closed)"
assert_contains "$out" 'PR #2 is closed'

# FR-10.4, FR-10.5: the real query (FORGE_JQ, which the stub skips) sorts GitHub's check results:
# a running check is pending, a failed status context is failing, no checks is none.
cat >"$T/prs.json" <<'JSON'
[{"headRefName":"a/1-x","number":5,"state":"OPEN","reviewDecision":null,"url":"u5","headRefOid":"s5",
  "statusCheckRollup":[{"name":"test","status":"IN_PROGRESS","conclusion":null},{"name":"lint","status":"COMPLETED","conclusion":"SKIPPED"}]},
 {"headRefName":"a/2-y","number":6,"state":"OPEN","reviewDecision":"APPROVED","url":"u6","headRefOid":"s6",
  "statusCheckRollup":[{"name":"test","status":"COMPLETED","conclusion":"SUCCESS"},{"context":"ext","state":"ERROR"}]},
 {"headRefName":"a/3-z","number":7,"state":"MERGED","reviewDecision":"","url":"u7","headRefOid":"s7","statusCheckRollup":[]},
 {"headRefName":"a/4-w","number":8,"state":"OPEN","reviewDecision":"","url":"u8","headRefOid":"s8",
  "statusCheckRollup":[{"name":"test","status":"COMPLETED","conclusion":"SUCCESS"},{"context":"ci/x","state":"SUCCESS"}]}]
JSON
out=$(. "$SRC/.sdd/core/forges/github.sh" && jq -r ".[] | $FORGE_JQ" "$T/prs.json" | cut -f1,5)
assert_eq "$out" "$(printf 'a/1-x\tpending: test\na/2-y\tfailing: ext\na/3-z\tnone\na/4-w\tpassing')"

# FR-10.7: init on a repo whose origin is on GitHub suggests the forge.
new_repo other
git remote add origin https://github.com/acme/app.git
assert_contains "$(sdd init 2>&1)" "tip     origin is on GitHub: add 'forge = github'"
exit 0

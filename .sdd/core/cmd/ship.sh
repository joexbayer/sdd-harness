# shellcheck shell=sh
# ship: gates, archive the item, fast-forward the base branch locally. Never pushes.
# If anything fails after the item was touched, the branch is reset to where it was, so
# running ship again is always safe.
[ $# -eq 0 ] || usage_die "usage: $NAME ship"
need_repo
current_item || die "not on an item branch (see: $CMD status)"
[ "$(fm_get status "$IFILE")" = open ] || die "item $ID is not open"
[ -z "$(git status --porcelain)" ] || die "commit, stash or ignore your changes first (ship checks exactly what it lands)"

base=$(cfg sdd.base main)
title=$(fm_get title "$IFILE")
archive="$SPECS/archive/${IDIR##*/}"
[ ! -e "$archive" ] || die "$archive already exists"
pre=

# fail <message>: undo whatever ship did to this branch, then stop.
fail() {
	[ -n "$pre" ] && git reset -q --hard "$pre"
	die "$1"
}

# ff_base <commit>: fast-forward the base branch to <commit>, whether or not the base
# is checked out in some worktree. Refuses anything that is not a fast-forward.
ff_base() {
	_old=$(git rev-parse "refs/heads/$base") || fail "base branch $base not found"
	git merge-base --is-ancestor "$_old" "$1" || fail "$base moved while shipping; run $CMD ship again"
	_wt=$(git worktree list --porcelain | awk -v b="refs/heads/$base" '
		/^worktree / { w = substr($0, 10) } $0 == "branch " b { print w; exit }')
	if [ -n "$_wt" ]; then
		git -C "$_wt" merge -q --ff-only "$1" || fail "could not fast-forward $base in $_wt (uncommitted changes there?)"
	else
		git update-ref "refs/heads/$base" "$1" "$_old" || fail "could not update $base"
	fi
}

# gate <name> <condition-failed message>: apply a gate at its level for this type.
gate() {
	_lvl=$(gate_level "$1" "$ITYPE")
	[ "$_lvl" != off ] || return 0
	[ "$_lvl" = block ] && fail "$2"
	warn "$2"
}

# The gates that look at the item.
[ -z "$(missing_sections "$IFILE" plan)" ] ||
	gate planned "item $ID: the plan is incomplete (empty: $(joinlist "$(missing_sections "$IFILE" plan)"))"
if [ "$(gate_level approved "$ITYPE")" != off ]; then
	if ! approval_ok; then
		gate approved "item $ID: the plan is not approved, or changed since (the human runs: $CMD approve)"
	else
		first=$(git log --reverse --format=%H --grep="^docs($ID): approve plan" "$base..HEAD" | head -n 1)
		early=$([ -n "$first" ] && git log --format=%h "$base..$first" -- . ":(exclude)$SPECS")
		[ -z "$early" ] || gate approved "item $ID: code was committed before the plan was approved ($(joinlist "$early"))"
	fi
fi
[ -z "$(missing_sections "$IFILE" built)" ] || gate built "item $ID: \"## Built\" is not written yet"
# The constitution blocks in every profile.
guard=$(constitution_guard) || fail "item $ID: $guard"

pre=$(git rev-parse HEAD)

# A spike's code never lands: only its archived item reaches the base branch.
if [ "$(cfg "type.$ITYPE.lands" all)" = item ]; then
	fm_set "$IFILE" status shipped
	fm_set "$IFILE" shipped "$(date +%F)"
	git commit -q -m "docs($ID): ship spike \"$title\"" -- "$IFILE" || fail "could not commit $IFILE"
	tmpidx=$(mktemp "${TMPDIR:-/tmp}/$NAME-index.XXXXXX") && rm -f "$tmpidx"
	GIT_INDEX_FILE=$tmpidx git read-tree "$base" || fail "could not read $base"
	git ls-tree -r HEAD -- "$IDIR" | while IFS="$(printf '\t')" read -r meta path; do
		GIT_INDEX_FILE=$tmpidx git update-index --add --cacheinfo "$(echo "$meta" | awk '{ print $1 "," $3 }'),$archive/${path#"$IDIR"/}"
	done
	tree=$(GIT_INDEX_FILE=$tmpidx git write-tree)
	rm -f "$tmpidx"
	commit=$(git commit-tree "$tree" -p "$base" -m "docs($ID): spike findings \"$title\"") || fail "could not create the findings commit"
	ff_base "$commit"
	echo "✓ spike $ID: findings archived on $base (local); the code stays on $BRANCH"
	echo "next    git push origin $base   ·   delete the code when done: git branch -D $BRANCH"
	exit 0
fi

if ! git merge-base --is-ancestor "$base" HEAD; then
	git rebase -q "$base" >/dev/null 2>&1 || {
		git rebase --abort >/dev/null 2>&1
		die "rebase onto $base hit conflicts; resolve with: git rebase $base, then $CMD ship"
	}
	echo "rebased onto $base"
fi

# Check articles run after the rebase, on the constitution that will be in force: editing it
# does not change the code fingerprint, so a cached code check has not seen new articles.
: >"$ST/checks/$ID.articles.log"
check_articles "$ST/checks/$ID.articles.log" || fail "item $ID: $(printf '%s\n' "$CHECK_ARTICLES" | paste -sd ';' -)"

if [ "$(gate_level check "$ITYPE")" != off ]; then
	if check_passed_here "$ID"; then
		echo "✓ check already passed for this exact code"
	else
		run_check "$ID"
		case $? in
		0) echo "✓ check passed" ;;
		3) gate check "check ran zero tests: that proves nothing (log: $CHECK_LOG)" ;;
		*) gate check "check failed (log: $CHECK_LOG)" ;;
		esac
	fi
fi

fm_set "$IFILE" status shipped
fm_set "$IFILE" shipped "$(date +%F)"
mkdir -p "$SPECS/archive"
git mv "$IDIR" "$archive" || fail "could not move $IDIR to $archive"
git add -- "$archive" || fail "could not stage $archive"
git commit -q -m "docs($ID): ship $ITYPE \"$title\"" || fail "could not commit the archive move"

ff_base "$(git rev-parse HEAD)"
if ! git worktree list --porcelain | grep -qx "branch refs/heads/$base"; then
	git switch -q "$base" || die "shipped, but could not switch to $base"
	if git branch -q -d "$BRANCH" 2>/dev/null; then
		echo "✓ shipped $ID into $base (local); branch $BRANCH deleted"
	else
		echo "✓ shipped $ID into $base (local); branch $BRANCH kept (delete with: git branch -D $BRANCH)"
	fi
else
	echo "✓ shipped $ID into $base (local)"
	echo "cleanup git worktree remove $ROOT && git branch -d $BRANCH"
fi
echo "next    git push origin $base"

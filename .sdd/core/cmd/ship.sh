# shellcheck shell=sh
# ship: gates, archive the item, fast-forward the base branch locally. Never pushes, unless the
# project sets a forge (forge = github): then ship pushes the item branch and opens a PR, and
# shipping again merges it (see pr_ship below).
# If anything fails after the item was touched, the branch is reset to where it was, so
# running ship again is always safe.
[ $# -eq 0 ] || usage_die "usage: $NAME ship"
need_repo
current_item || die "not on an item branch (see: $CMD status)"
fm_closed "$IFILE" || die "item $ID: $FM_OPEN"

[ -z "$(git status --porcelain)" ] || die "commit, stash or ignore your changes first (ship checks exactly what it lands)"

base=$(cfg sdd.base main)
title=$(fm_get title "$IFILE")
pre=
remote=$(cfg sdd.remote origin)
forge=
if forge_load; then
	why=$(forge_ready) || die "ship goes through $FORGE_NAME (forge = $(cfg sdd.forge)): $why"
	forge=1
fi

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
	_wt=$(worktree_of "$base")
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

# check_gate: the configured checks must pass for exactly this code (cached when they did).
check_gate() {
	[ "$(gate_level check "$ITYPE")" != off ] || return 0
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
}

# cleanup <what happened>: after the base has the item. In a linked worktree, keep it: removing
# it would leave this shell (or an agent) in a deleted folder; tidy removes it from the main
# checkout. Here, the branch goes when every commit on it is on the base, even if its pushed
# copy differs (git branch -d would refuse).
cleanup() {
	_main=$(main_root)
	_wt=$(worktree_of "$base")
	if [ "$ROOT" != "$_main" ]; then
		echo "✓ $1; this worktree and branch $BRANCH stay until tidy"
		echo "cleanup cd $_main && $CMD tidy"
	elif [ -n "$_wt" ]; then
		echo "✓ $1; branch $BRANCH kept ($base is checked out in $_wt)"
		echo "cleanup git switch --detach && $CMD tidy"
	else
		git switch -q "$base" || die "shipped, but could not switch to $base"
		if git merge-base --is-ancestor "$BRANCH" "$base" && git branch -q -D "$BRANCH"; then
			echo "✓ $1; branch $BRANCH deleted"
		else
			echo "✓ $1; branch $BRANCH kept (delete with: git branch -D $BRANCH)"
		fi
	fi
}

# pr_push <message>: push the item branch and open its PR, or update the open one.
pr_push() {
	git push -q -u "$remote" "$BRANCH" || fail "could not push $BRANCH to $remote" # C-4: ship (forge)
	_pr=$(forge_pr_state "$BRANCH")
	if [ "$(printf '%s\n' "$_pr" | cut -f3)" = OPEN ]; then
		_n=$(printf '%s\n' "$_pr" | cut -f2)
		forge_pr_edit "$_n" "$IFILE" || die "pushed, but could not update the body of PR #$_n"
		echo "✓ $1 PR #$_n: $(printf '%s\n' "$_pr" | cut -f6)"
	else
		_url=$(forge_pr_create "$BRANCH" "$base" "$ITYPE($ID): $title" "$IFILE") ||
			die "pushed $BRANCH, but could not open the PR; run $CMD ship again"
		echo "✓ PR opened for item $ID: $_url"
	fi
	echo "next    when CI passes (and a teammate approved, if your team asks for it): $CMD ship   (merges it)"
}

# pr_ship: ship again, for an item already shipped into a PR. New local commits are checked and
# pushed; otherwise the PR is merged when CI allows and GitHub still has exactly this commit.
pr_ship() {
	[ -n "$forge" ] || die "item $ID was shipped into a pull request; set forge under [sdd] in $DIRNAME/config to merge it"
	_pr=$(forge_pr_state "$BRANCH")
	_n=$(tsv 2 "$_pr") _st=$(tsv 3 "$_pr") _ci=$(tsv 5 "$_pr") _url=$(tsv 6 "$_pr") _head=$(tsv 7 "$_pr")
	_here=$(git rev-parse HEAD)
	case $_st in
	'') check_gate && pr_push "pushed item $ID to" && return ;;
	CLOSED) die "PR #$_n is closed: reopen it (gh pr reopen $_n) to ship it, or drop the item" ;;
	MERGED) ;;
	*)
		if [ "$_head" != "$_here" ]; then
			git merge-base --is-ancestor "$_head" HEAD 2>/dev/null ||
				die "PR #$_n has commits this branch lacks (a teammate pushed?): git pull $remote $BRANCH, then $CMD ship"
			check_gate && pr_push "pushed new commits to" && return
		fi
		case $_ci in
		failing* | pending*) die "PR #$_n: CI $_ci; ship again when it passes ($_url)" ;;
		esac
		check_gate
		forge_pr_merge "$_n" "$_here" || die "could not merge PR #$_n ($_url)"
		git push -q "$remote" --delete "$BRANCH" || warn "merged, but could not delete $remote/$BRANCH" # C-4: ship (forge)
		;;
	esac
	git fetch -q "$remote" "$base" || die "merged PR #$_n, but could not fetch $remote/$base"
	ff_base "$remote/$base"
	cleanup "merged PR #$_n into $base (now at $(git rev-parse --short "$base"))"
}

if [ -n "${IPR:-}" ]; then
	pr_ship
	exit 0
fi
[ "$(fm_get status "$IFILE")" = open ] || die "item $ID is not open"
archive="$SPECS/archive/${IDIR##*/}"
[ ! -e "$archive" ] || die "$archive already exists"

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

check_gate

fm_set "$IFILE" status shipped
fm_set "$IFILE" shipped "$(date +%F)"
mkdir -p "$SPECS/archive"
git mv "$IDIR" "$archive" || fail "could not move $IDIR to $archive"
git add -- "$archive" || fail "could not stage $archive"
git commit -q -m "docs($ID): ship $ITYPE \"$title\"" || fail "could not commit the archive move"

if [ -n "$forge" ]; then
	IDIR=$archive IFILE=$archive/item.md
	pr_push "pushed item $ID to"
	exit 0
fi
ff_base "$(git rev-parse HEAD)"
cleanup "shipped $ID into $base (local)"
echo "next    git push origin $base"

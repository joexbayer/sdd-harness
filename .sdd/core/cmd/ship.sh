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

# pr_ready: what was checked is what lands. The branch must contain the remote base (GitHub
# merges into it) and the local base must have nothing the remote lacks (it is fast-forwarded
# after the merge).
pr_ready() {
	git fetch -q "$remote" "$base" || die "could not fetch $remote/$base"
	git merge-base --is-ancestor "$base" "$remote/$base" ||
		die "$base has commits $remote/$base lacks; push or reset $base first (PRs land on $remote/$base)"
	git merge-base --is-ancestor "$remote/$base" HEAD ||
		die "$BRANCH is behind $remote/$base: git merge $remote/$base (or rebase, if never pushed), then $CMD ship"
}

# pr_gates: the gates the local ship also applies to this code: the constitution and the check.
pr_gates() {
	guard=$(constitution_guard) || die "item $ID: $guard"
	: >"$ST/checks/$ID.articles.log"
	check_articles "$ST/checks/$ID.articles.log" || die "item $ID: $(printf '%s\n' "$CHECK_ARTICLES" | paste -sd ';' -)"
	check_gate
}

# pr_push <message>: push the item branch and open its PR, or update the open one.
pr_push() {
	git push -q -u "$remote" "$BRANCH" || fail "could not push $BRANCH to $remote" # C-4: ship (forge)
	pr_line=$(forge_pr_state "$BRANCH") || die "pushed, but $FORGE_NAME did not answer; run $CMD ship again"
	if [ "$(printf '%s\n' "$pr_line" | cut -f3)" = OPEN ]; then
		pr_num=$(printf '%s\n' "$pr_line" | cut -f2)
		forge_pr_edit "$pr_num" "$IFILE" || die "pushed, but could not update the body of PR #$pr_num"
		echo "✓ $1 PR #$pr_num: $(printf '%s\n' "$pr_line" | cut -f6)"
	else
		pr_url=$(forge_pr_create "$BRANCH" "$base" "$ITYPE($ID): $title" "$IFILE") ||
			die "pushed $BRANCH, but could not open the PR; run $CMD ship again"
		echo "✓ PR opened for item $ID: $pr_url"
	fi
	echo "next    when CI passes (and a teammate approved, if your team asks for it): $CMD ship   (merges it)"
}

# PR facts live in pr_* variables: sh has no locals, and lib helpers called in between (the
# constitution check counts in _n) reuse the short _x names.
# pr_ship: ship again, for an item already shipped into a PR. New local commits are checked and
# pushed; otherwise the PR is merged when CI allows and GitHub still has exactly this commit.
pr_ship() {
	[ -n "$forge" ] || die "item $ID was shipped into a pull request; set forge under [sdd] in $DIRNAME/config to merge it"
	pr_line=$(forge_pr_state "$BRANCH") || die "$FORGE_NAME did not answer; run $CMD ship again"
	pr_num=$(tsv 2 "$pr_line") pr_state=$(tsv 3 "$pr_line") pr_review=$(tsv 4 "$pr_line")
	pr_ci=$(tsv 5 "$pr_line") pr_url=$(tsv 6 "$pr_line") pr_head=$(tsv 7 "$pr_line")
	pr_here=$(git rev-parse HEAD)
	case $pr_state in
	'') pr_ready && pr_gates && pr_push "pushed item $ID to" && return ;;
	CLOSED) die "PR #$pr_num is closed: reopen it (gh pr reopen $pr_num) to ship it, or drop the item" ;;
	MERGED)
		# Merged on GitHub (the button): fine, unless it left out newer commits from here.
		git merge-base --is-ancestor HEAD "$pr_head" 2>/dev/null ||
			die "PR #$pr_num was merged without the newest commits here ($(git log --format=%h "$pr_head..HEAD" 2>/dev/null | paste -sd ' ' -)): keep $BRANCH and ship them as a new item"
		git push -q "$remote" --delete "$BRANCH" 2>/dev/null # C-4: ship (forge)
		;;
	*)
		if [ "$pr_head" != "$pr_here" ]; then
			git merge-base --is-ancestor "$pr_head" HEAD 2>/dev/null ||
				die "PR #$pr_num has commits this branch lacks (a teammate pushed?): git pull $remote $BRANCH, then $CMD ship"
			pr_ready && pr_gates && pr_push "pushed new commits to" && return
		fi
		[ "$pr_review" != CHANGES_REQUESTED ] || die "PR #$pr_num: changes requested; address the review, then $CMD ship ($pr_url)"
		case $pr_ci in
		failing* | pending*) die "PR #$pr_num: CI $pr_ci; ship again when it passes ($pr_url)" ;;
		none)
			# Right after a push GitHub has not registered the checks yet: no result is not a pass.
			[ -z "$(git ls-tree -d HEAD .github/workflows)" ] ||
				die "PR #$pr_num: CI has not reported yet (this branch has .github/workflows); ship again in a minute"
			;;
		esac
		pr_ready
		pr_gates
		forge_pr_merge "$pr_num" "$pr_here" || die "could not merge PR #$pr_num ($pr_url)"
		git push -q "$remote" --delete "$BRANCH" || warn "merged, but could not delete $remote/$BRANCH" # C-4: ship (forge)
		;;
	esac
	git fetch -q "$remote" "$base" || die "PR #$pr_num is merged, but $remote/$base could not be fetched; run $CMD ship again"
	git merge-base --is-ancestor "$base" "$remote/$base" ||
		die "PR #$pr_num is merged, but $base has commits $remote/$base lacks; reconcile $base, then $CMD ship"
	ff_base "$remote/$base"
	cleanup "merged PR #$pr_num into $base (now at $(git rev-parse --short "$base"))"
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
# Tasks: sdd ticks a box when its test passes, git proves it: a ticked task needs a commit
# naming it, in every profile, and, when that commit is yours, the note task done left in this
# clone (a teammate's tick was proven on their machine). Features also need tasks, all ticked.
trows=$(task_rows)
unproven=$(printf '%s\n' "$trows" | awk -F '\t' '$2 == "done" { print $1 }' |
	while IFS= read -r t; do [ -n "$(task_commit "$t")" ] || echo "$t"; done)
[ -z "$unproven" ] || fail "item $ID: ticked, but no commit names them: $(joinlist "$unproven") (put the task ID in the commit subject)"
me=$(git config user.name)
byhand=$(printf '%s\n' "$trows" | awk -F '\t' '$2 == "done" { print $1 }' | while IFS= read -r t; do
	grep -qx "$t" "$ST/checks/$ID.tasks" 2>/dev/null && continue
	[ "$(git log -1 --format=%an "$(task_commit "$t")")" != "$me" ] || echo "$t"
done)
[ -z "$byhand" ] || fail "item $ID: ticked without $CMD task done: $(joinlist "$byhand") (untick them and run task done)"
if [ "$(gate_level tasks "$ITYPE")" != off ]; then
	[ -n "$trows" ] || gate tasks "item $ID: the plan has no tasks (- [ ] T-$ID.1 …)"
	open=$(printf '%s\n' "$trows" | awk -F '\t' '$2 == "open" { print $1 }')
	[ -z "$open" ] || gate tasks "item $ID: tasks not done: $(joinlist "$open")"
fi
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

# With a forge, GitHub merges into the remote base: the branch must already contain it (no
# rebase, which would rewrite commits a PR or a teammate may already have).
if [ -n "$forge" ]; then
	pr_ready
elif ! git merge-base --is-ancestor "$base" HEAD; then
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

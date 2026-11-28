# shellcheck shell=sh
# ship: gates, archive the item, fast-forward the base branch locally. Never pushes, unless the
# project sets a forge (forge = github): then ship pushes the item branch and opens a PR, and
# shipping again merges it (see pr_ship below).
# If anything fails after the item was touched, the branch is reset to where it was, so
# running ship again is always safe.
[ $# -eq 0 ] || usage_die "usage: $NAME ship"
human_only ship
need_repo
current_item || die "not on an item branch (see: $CMD status)"
# FR-89.1: a roadmap or spike lands inside the first item built from it (new --from).
case $ITYPE:$(cfg "type.$ITYPE.lands" all) in
roadmap:item) die "roadmap $ID ships with its first item: $CMD new --from R-$ID.1" ;;
*:item) die "$ITYPE $ID ships with the item that acts on it: $CMD new <type> \"title\" --from $ID" ;;
esac
fm_closed "$IFILE" || die "item $ID: $FM_OPEN"

[ -z "$(git status --porcelain)" ] || die "commit, stash or ignore your changes first (ship checks exactly what it lands)"

base=$(cfg sdd.base main)
# FR-73.9: no push hint without a remote.
remote=$(cfg sdd.remote origin)
push_hint=
git remote get-url "$remote" >/dev/null 2>&1 && push_hint="git push $remote $base   ·   "
title=$(fm_get title "$IFILE")
pre=
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
	case $_lvl in off) return 0 ;; warn) warn "$2" ;; *) fail "$2" ;; esac
}

# unverified_tally: " (<n> of <m> shipped items were not verified)", counted in the archive on
# $base: no "Verified by:" line in "## Built", or none (FR-85.5).
unverified_tally() {
	git ls-tree -r --name-only "$base" -- "$SPECS/archive" | grep '/item\.md$' | sed "s|^|$base:|" |
		git cat-file --batch | awk '
		function end() { if (m) { t++; v = tolower(v); sub(/^verified by:[ \t]*/, "", v); if (v == "" || v ~ /^none/) n++ } }
		/^[0-9a-f]+ blob [0-9]+$/ { end(); m = 1; on = 0; v = ""; next }
		/^## / { on = ($0 == "## Built"); next }
		on { s = $0; sub(/^[ \t]*([-*][ \t]+)?/, "", s); if (index(s, "Verified by:") == 1) v = s }
		END { end(); if (t) printf " (%d of %d shipped items were not verified)", n, t }'
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
		*) gate check "check failed (log: $CHECK_LOG)
$(LC_ALL=C tr -d '\000' <"$CHECK_LOG" | LC_ALL=C grep -v '^[[:space:]]*$' | tail -n 5)" ;;
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
		echo "cleanup cd $(shq "$_main") && $CMD tidy"
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
# merges into it) and the local base must have nothing the remote lacks. The local base is
# fast-forwarded to the remote's, so a teammate's changes there are not this item's (FR-68.9).
pr_ready() {
	git fetch -q "$remote" "$base" || die "could not fetch $remote/$base"
	git merge-base --is-ancestor "$base" "$remote/$base" ||
		die "$base has commits $remote/$base lacks; push or reset $base first (PRs land on $remote/$base)"
	ff_base "$remote/$base"
	git merge-base --is-ancestor "$remote/$base" HEAD ||
		die "$BRANCH is behind $remote/$base: git merge $remote/$base (or rebase, if never pushed), then $CMD ship"
}

# type_guard: the type an item was opened with stays its type (D-68.1). FR-68.4
type_guard() {
	_ip="$SPECS/changes/${IDIR##*/}/item.md"
	# --follow: a folder rename must not pass for the item's creation.
	_add=$(git log --follow --diff-filter=A --name-only --format=%H -- "$_ip" | sed '/^$/d' | tail -n 2)
	[ -n "$_add" ] || return 0
	_was=$(git show "$(printf '%s\n' "$_add" | head -n 1):$(printf '%s\n' "$_add" | tail -n 1)" | fm_get type)
	[ "$_was" = "$ITYPE" ] || fail "item $ID was opened as $_was: its type cannot change (now $ITYPE); open a new item"
}

# item_gates: the gates that look at the item, for a first ship and (FR-68.5) for new commits on
# a PR or its merge.
item_gates() {
	[ -z "$(missing_sections "$IFILE" plan)" ] ||
		gate planned "item $ID: the plan is incomplete (empty: $(joinlist "$(missing_sections "$IFILE" plan)"))"
	if [ "$(gate_level approved "$ITYPE")" != off ]; then
		if ! approval_ok; then
			gate approved "item $ID: the plan is not approved, or changed since (the human runs: $CMD approve)"
		else
			first=$(git log --reverse --format=%H --grep="^docs($ID): approve plan" "$base..HEAD" | head -n 1)
			# FR-83.3: each early commit with its files, 5 files in all.
			early=$([ -n "$first" ] && git log --format=#%h --name-only "$base..$first" -- . ":(exclude)$SPECS" | awk '
				/^#/ { h = substr($0, 2); next }
				NF { if (++n <= 5) { if (!(h in f)) o = o (o == "" ? "" : "; ") h; f[h] = f[h] (f[h] == "" ? ": " : ", ") $0 } }
				END { split(o, hs, "; "); for (i = 1; i in hs; i++) r = r (i > 1 ? "; " : "") hs[i] f[hs[i]]; print r (n > 5 ? " …" : "") }')
			[ -z "$early" ] || gate approved "item $ID: code was committed before the plan was approved ($early)"
		fi
	fi
	[ -z "$(missing_sections "$IFILE" built)" ] || gate built "item $ID: \"## Built\" is not written yet"
	# FR-22.3: someone other than the builder proved the requirements (the verifier, see finish.md).
	[ "$(gate_level verified "$ITYPE")" = off ] || verified ||
		gate verified "item $ID: not verified (gate verified): \"## Built\" needs a \"Verified by: <model>: …\" line, not none (the verifier step in $CMD next)$([ "$(gate_level verified "$ITYPE")" = block ] || unverified_tally)"
	# FR-85.3: stale verification warns, never blocks.
	if [ "$(gate_level verified "$ITYPE")" != off ] && verified && [ "$(verified_since | cut -c1-2)" != ok ]; then
		warn "item $ID: $(since_text)"
	fi
	# FR-22.4: the code ships as the human last saw it in $CMD review here; a rebase keeps its patch
	# id. An item that changes no code has nothing to see.
	if [ "$(gate_level reviewed "$ITYPE")" != off ]; then
		seen="$ST/checks/$ID.reviewed"
		now=$(review_print)
		if [ "$(printf '%s\n' "$now" | sed -n 1p)" = patch= ]; then
			:
		elif [ ! -f "$seen" ]; then
			gate reviewed "item $ID: not reviewed in this clone (gate reviewed): run $CMD review"
		elif [ "$(sed -n 1p "$seen")" != "$(printf '%s\n' "$now" | sed -n 1p)" ]; then
			since=$(printf '%s\n' "$now" | awk -F '\t' 'FNR == 1 { next } NR == FNR { was[$0] = 1; next }
				{ is[$0] = 1; if (!($0 in was)) p[$2] = 1 } END { for (l in was) if (!(l in is)) { split(l, f, "\t"); p[f[2]] = 1 } for (x in p) print x }' "$seen" - | sort)
			gate reviewed "item $ID: code changed since your review${since:+ ($(joinlist "$since"))} (gate reviewed): run $CMD review"
		fi
	fi
	# FR-24.6: an item ships after the items and roadmap entries it depends on (D-24.2: only ship waits).
	if [ "$(gate_level depends "$ITYPE")" != off ]; then
		waits_for "$(fm_get depends "$IFILE")"
		[ -z "$WAITS" ] || gate depends "item $ID: waits for $WAITS (gate depends)"
	fi
	# Tasks: sdd ticks a box when its test passes, git proves it: a ticked task needs a commit
	# naming it, in every profile, and, when that commit is yours, the note task done left in this
	# clone (a teammate's tick was proven on their machine). Features also need tasks, all ticked.
	trows=$(task_rows)
	# FR-73.8: a tick with no task done note says that first: a commit subject is no use to it.
	me=$(git config user.name)
	byhand=$(printf '%s\n' "$trows" | awk -F '\t' '$2 == "done" { print $1 }' | while IFS= read -r t; do
		grep -qx "$t" "$ST/checks/$ID.tasks" 2>/dev/null && continue
		! waived "$t" || continue
		c=$(task_commit "$t")
		[ -z "$c" ] || [ "$(git log -1 --format=%an "$c")" = "$me" ] && echo "$t"
	done)
	[ -z "$byhand" ] || fail "item $ID: ticked without $CMD task done: $(joinlist "$byhand") (untick them and run task done)"
	unproven=$(printf '%s\n' "$trows" | awk -F '\t' '$2 == "done" { print $1 }' |
		while IFS= read -r t; do waived "$t" || [ -n "$(task_commit "$t")" ] || echo "$t"; done)
	[ -z "$unproven" ] || fail "item $ID: ticked, but no commit names them: $(joinlist "$unproven") (put the task ID in the commit subject)"
	# FR-58.1: a test the planner wrote is the contract; the builder may not quietly change it.
	bent=$(bent_tests)
	[ -z "$bent" ] || fail "$bent"
	# FR-75.1: a change cannot weaken the check that judges it, in any profile.
	x=$(check_edited)
	[ -z "$x" ] || fail "$x"
	if [ "$(gate_level tasks "$ITYPE")" != off ]; then
		[ -n "$trows" ] || gate tasks "item $ID: the plan has no tasks (- [ ] T-$ID.1 …)"
		open=$(printf '%s\n' "$trows" | awk -F '\t' '$2 == "open" { print $1 }')
		# A task whose line sdd cannot read (task_rows) is refused, ticked or not.
		unread=$(printf '%s\n' "$trows" | awk -F '\t' '$8 != "" { s = s (s == "" ? "" : "; ") $1 " (" $8 ")" } END { print s }')
		tmsg=
		[ -z "$open" ] || tmsg="tasks not done: $(joinlist "$open")"
		[ -z "$unread" ] || tmsg="${tmsg:+$tmsg; }tasks $NAME cannot read: $unread"
		[ -z "$tmsg" ] || gate tasks "item $ID: $tmsg"
	fi
}

# pr_gates: the gates the local ship also applies to this code: the item's, the constitution and
# the check.
pr_gates() {
	item_gates # FR-68.5, FR-68.6
	type_guard
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
		# FR-54.2: the body only points at the item file, so new commits leave it as it is.
		echo "✓ $1 PR #$(printf '%s\n' "$pr_line" | cut -f2): $(printf '%s\n' "$pr_line" | cut -f6)"
	else
		# FR-54.1: the body points at the item file; a copy would go stale and outgrow the forge.
		pr_body="Item $ID ($ITYPE): $title

The plan, its requirements and the build notes: \`$IFILE\` on this branch."
		pr_url=$(forge_pr_create "$BRANCH" "$base" "$ITYPE($ID): $title" "$pr_body") ||
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
	CLOSED) die "PR #$pr_num is closed: reopen it (gh pr reopen $pr_num) to ship it, or abandon the item: git branch -D $BRANCH" ;;
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
# FR-72.4: the same id already on the base under another name (two clones took it offline).
_twin=$(git ls-tree --name-only "$base" "$SPECS/archive/" "$SPECS/changes/" 2>/dev/null | sed 's|.*/||' | grep "^$ID-" | grep -vx "${IDIR##*/}" | head -n 1)
[ -z "$_twin" ] || warn "id $ID is also $_twin on $base"

# With a forge, GitHub merges into the remote base: the branch must already contain it (no
# rebase, which would rewrite commits a PR or a teammate may already have). It is fetched before
# the gates judge the item (FR-68.9).
[ -z "$forge" ] || pr_ready
item_gates
type_guard
# The constitution blocks in every profile.
guard=$(constitution_guard) || fail "item $ID: $guard"

pre=$(git rev-parse HEAD)

if [ -z "$forge" ] && ! git merge-base --is-ancestor "$base" HEAD; then
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
# FR-89.4: items carried into this branch (new --from) ship in the same commit; only folders the
# branch added, never one the base already holds.
_mb=$(git merge-base "$base" HEAD)
for _c in "$SPECS"/changes/*/; do
	_c=${_c%/}
	[ -f "$_c/item.md" ] || continue
	! git cat-file -e "$_mb:$_c/item.md" 2>/dev/null || continue
	fm_set "$_c/item.md" status shipped
	fm_set "$_c/item.md" shipped "$(date +%F)"
	git mv "$_c" "$SPECS/archive/${_c##*/}" && git add -- "$SPECS/archive/${_c##*/}" || fail "could not move $_c to the archive"
done
git commit -q -m "docs($ID): ship $ITYPE \"$title\"" || fail "could not commit the archive move"

if [ -n "$forge" ]; then
	IDIR=$archive IFILE=$archive/item.md
	pr_push "pushed item $ID to"
	exit 0
fi
ff_base "$(git rev-parse HEAD)"
cleanup "shipped $ID into $base (local)"
[ -z "$push_hint" ] || echo "next    git push $remote $base"

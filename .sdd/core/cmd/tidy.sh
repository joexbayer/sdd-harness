# shellcheck shell=sh
# tidy [--remote] [--dry-run]: remove the worktrees and branches of items that are shipped or
# dropped on the base branch, when git proves nothing is lost; keep the rest and say why.
# --remote (human-only, first argument only, so an ask rule's prefix always matches) also
# deletes their remote branches: the one push C-4 allows.
remote=
dry=
[ "${1:-}" = --remote ] && remote=1 && shift
for a in "$@"; do
	case $a in
	--dry-run) dry=1 ;;
	*) usage_die "usage: $NAME tidy [--remote] [--dry-run]   (--remote goes first)" ;;
	esac
done
need_repo
base=$(cfg sdd.base main)
main=$(main_root)
tab=$(printf '\t')

# Items that are done: "<id>\t<status>\t<type>", from the archive on the base branch.
done_items=$(git ls-tree -r --name-only "$base" -- "$SPECS/archive" 2>/dev/null | grep '/item\.md$' |
	while IFS= read -r p; do
		i=$(id_of "${p%/item.md}") || continue
		printf '%s\t%s\t%s\n' "$i" "$(git show "$base:$p" | fm_get status)" "$(git show "$base:$p" | fm_get type)"
	done)

# done_item <branch>: "<status>\t<type>" when the branch belongs to a done item, else fails.
done_item() {
	_i=$(id_of "$1") || return 1
	printf '%s\n' "$done_items" | awk -F '\t' -v i="$_i" '$1 == i { print $2 "\t" $3; f = 1 } END { exit !f }'
}

shown=
say() { printf '%-8s %s\n' "$1" "$2"; shown=1; }
gone=$([ -n "$dry" ] && echo "would remove" || echo removed)

# Local branches, and the worktree each one is checked out in.
for b in $(git for-each-ref --format='%(refname:short)' refs/heads); do
	[ "$b" != "$base" ] || continue
	st=$(done_item "$b") || continue
	why="(item $(id_of "$b"), ${st%%"$tab"*})"
	w=$(worktree_of "$b")
	rmwt=${w:+"git worktree remove --force $w && "}
	if [ "$w" = "$main" ]; then
		say kept "branch $b $why: checked out in the main checkout · git switch $base && $CMD tidy"
	elif [ -n "$w" ] && [ "$w" = "$ROOT" ]; then
		say kept "worktree $w $why: you are in it · cd $main && $CMD tidy"
	elif ! git merge-base --is-ancestor "$b" "$base"; then
		if [ "${st#*"$tab"}" = spike ]; then
			say kept "branch $b $why: a spike's code never lands on $base · ${rmwt}git branch -D $b"
		else
			say kept "branch $b $why: has commits not on $base · ${rmwt}git branch -D $b"
		fi
	elif [ -n "$w" ] && [ -n "$(git -C "$w" status --porcelain)" ]; then
		say kept "worktree $w $why: uncommitted changes · git worktree remove --force $w && git branch -D $b"
	else
		if [ -n "$w" ]; then
			[ -n "$dry" ] || git worktree remove "$w" || die "could not remove worktree $w"
			say "$gone" "worktree $w $why"
		fi
		[ -n "$dry" ] || git branch -q -D "$b" || die "could not delete branch $b"
		say "$gone" "branch $b $why"
	fi
done

# Remote branches of done items. Deleting one is a push, so only with --remote, and only when
# every commit's change is already on the base (git cherry), because a deleted remote branch
# cannot be brought back and a teammate may have pushed to it after the ship.
left=
for r in $(git for-each-ref --format='%(refname:short)' refs/remotes); do
	case $r in */HEAD) continue ;; esac
	st=$(done_item "$r") || continue
	why="(item $(id_of "$r"), ${st%%"$tab"*})"
	rem=${r%%/*} b=${r#*/}
	if [ -z "$remote" ]; then
		say remote "$r $why"
		left=1
		continue
	fi
	extra=$(git cherry "$base" "$r" | sed -n 's/^+ //p' | cut -c1-7 | paste -sd ' ' -)
	if [ -n "$extra" ]; then
		say kept "$r $why: changes not on $base ($extra) · git push $rem --delete $b"
	elif [ -n "$dry" ]; then
		say "$gone" "$r $why"
	elif git push -q "$rem" --delete "$b"; then
		say "$gone" "$r $why"
	else
		say kept "$r $why: the push failed (already gone? git fetch --prune $rem)"
	fi
done

[ -n "$shown" ] || echo "nothing to tidy"
[ -z "$left" ] || echo "next    $CMD tidy --remote   (deletes these remote branches; the human confirms)"

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
[ -z "$remote" ] || human_only "tidy --remote"
need_repo
base=$(cfg sdd.base main)
main=$(main_root)
tab=$(printf '\t')

# done_in <ref>: "<id>-<slug>\t<status>\t<type>" for every item archived on <ref>.
done_in() {
	git ls-tree -r --name-only "$1" -- "$SPECS/archive" 2>/dev/null | grep '/item\.md$' |
		while IFS= read -r _p; do
			_d=${_p%/item.md}
			printf '%s\t%s\t%s\n' "${_d##*/}" "$(git show "$1:$_p" | fm_get status)" "$(git show "$1:$_p" | fm_get type)"
		done
}

# done_item <done list> <branch>: "<status>\t<type>" when the branch's last part (always
# <id>-<slug>) is a done item's folder, else fails.
done_item() {
	L=$1 B=${2##*/} awk 'BEGIN { n = split(ENVIRON["L"], r, "\n")
		for (i = 1; i <= n; i++) { split(r[i], f, "\t"); if (f[1] == ENVIRON["B"]) { print f[2] "\t" f[3]; exit 0 } }
		exit 1 }'
}

# keep_reason <branch> <type> <worktree>: why a done item's branch (and its worktree) must stay,
# with the command that removes it anyway; nothing when removing it loses nothing.
keep_reason() {
	_rm="${3:+git worktree remove --force $3 && }git branch -D $1"
	if [ "$3" = "$main" ]; then
		echo "checked out in the main checkout · git switch $base && $CMD tidy"
	elif [ -n "$3" ] && [ "$3" = "$ROOT" ]; then
		echo "you are in it · cd $main && $CMD tidy"
	elif ! git merge-base --is-ancestor "$1" "$base"; then
		if [ "$2" = spike ]; then echo "a spike's code never lands on $base · $_rm"; else echo "has commits not on $base · $_rm"; fi
	elif [ -d "$3" ] && [ -n "$(git -C "$3" status --porcelain)" ]; then
		echo "uncommitted changes · $_rm"
	fi
}

# remove_worktree <path>: remove it, or forget it when its folder was already deleted by hand.
remove_worktree() { if [ -d "$1" ]; then git worktree remove "$1"; else git worktree prune; fi; }

shown=
say() { printf '%-8s %s\n' "$1" "$2"; shown=1; }

# Local branches (and their worktrees), judged against the local base.
done_here=$(done_in "$base")
for b in $(git for-each-ref --format='%(refname:short)' refs/heads); do
	st=$(done_item "$done_here" "$b") || continue
	w=$(worktree_of "$b")
	wl=$w
	[ "$w" != "$main" ] || wl= # the main checkout is never removed, so it is not named
	what="${wl:+worktree $wl and }branch $b (item $(id_of "$b"), ${st%%"$tab"*})"
	keep=$(keep_reason "$b" "${st#*"$tab"}" "$w")
	if [ -n "$keep" ]; then
		say kept "$what: $keep"
	elif [ -n "$dry" ]; then
		say "would remove" "$what"
	elif { [ -z "$w" ] || remove_worktree "$w"; } && git branch -q -D "$b"; then
		say removed "$what"
	else
		say kept "$what: git could not remove it (see above)"
	fi
done

# Remote branches. Deleting one is a push, so only with --remote. Each is judged against what
# its remote holds (<remote>/<base> as of the last fetch: an item shipped here but not pushed yet
# does not count), and the delete is leased: if the branch moved on the remote since the last
# fetch, the remote refuses, because a deleted remote branch cannot be brought back.
left=
seen=
for r in $(git for-each-ref --format='%(refname:short)' refs/remotes); do
	case $r in */HEAD) continue ;; esac
	rem=${r%%/*} b=${r#*/}
	[ "$rem" = "$seen" ] || { seen=$rem && done_there=$(done_in "$rem/$base"); }
	st=$(done_item "$done_there" "$r") || continue
	what="$r (item $(id_of "$r"), ${st%%"$tab"*})"
	if [ -z "$remote" ]; then
		say remote "$what"
		left=1
		continue
	fi
	extra=$(git cherry "$rem/$base" "$r" | sed -n 's/^+ //p' | cut -c1-7 | paste -sd ' ' -)
	if [ -n "$extra" ]; then
		say kept "$what: changes not on $rem/$base ($extra) · git push $rem --delete $b"
	elif [ -n "$dry" ]; then
		say "would remove" "$what"
	elif git push -q --force-with-lease="$b:$(git rev-parse "$r")" "$rem" --delete "$b"; then # C-4: tidy --remote
		say removed "$what"
	else
		say kept "$what: $rem refused (it moved since the last fetch, or is gone) · git fetch --prune $rem && $CMD tidy --remote"
	fi
done

[ -n "$shown" ] || echo "nothing to tidy"
[ -z "$left" ] || echo "next    $CMD tidy --remote   (deletes these remote branches; the human confirms)"

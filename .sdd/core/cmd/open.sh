# shellcheck shell=sh
# open <id> [--worktree]: switch to an item's branch, tracking a teammate's remote branch when
# that is the only copy, or open it in its own worktree at ../<repo>.<id>.
id=
wt=
for a in "$@"; do
	case $a in
	--worktree) wt=1 ;;
	*[!0-9]* | '') usage_die "usage: $NAME open <id> [--worktree]" ;;
	*) [ -z "$id" ] || usage_die "usage: $NAME open <id> [--worktree]"; id=$a ;;
	esac
done
[ -n "$id" ] || usage_die "usage: $NAME open <id> [--worktree]"
need_repo

src=$(item_sources | while IFS="$(printf '\t')" read -r o r p; do
	[ "$(id_of "${p%/item.md}")" = "$id" ] && printf '%s\t%s\t%s\n' "$o" "$r" "$p" && break
done)
[ -n "$src" ] || die "no item $id (see: $CMD ls)"
o=$(printf '%s\n' "$src" | cut -f1)
ref=$(printf '%s\n' "$src" | cut -f2)
path=$(printf '%s\n' "$src" | cut -f3)

case $o in
archive) die "item $id is $(git show "$ref:$path" | fm_get status) (${path%/item.md})" ;;
base) die "item $id has no branch: its item sits on $ref (${path%/item.md})" ;;
worktree) echo "already on $ref" && exit 0 ;;
local) branch=$ref track= ;;
remote) branch=${ref#*/} track=$ref ;;
esac

there=$(worktree_of "$branch")
if [ -n "$there" ]; then
	echo "$branch is checked out in $there"
	echo "next    cd $there && $CMD next"
	exit 0
fi

if [ -n "$wt" ]; then
	where=$(worktree_path "$id")
	[ ! -e "$where" ] || die "$where already exists (remove it, or: cd $where)"
	if [ -n "$track" ]; then
		git worktree add -q --track -b "$branch" "$where" "$track" || die "could not create worktree $where"
	else
		git worktree add -q "$where" "$branch" || die "could not create worktree $where"
	fi
	cd "$where" || exit 1
	sync_here
	echo "worktree $where   (branch $branch${track:+, tracking $track})"
	echo "next    cd $where && $CMD next"
	exit 0
fi

[ -z "$(git status --porcelain)" ] || die "commit, stash or ignore your changes first (open switches this checkout)"
if [ -n "$track" ]; then
	git switch -q --track -c "$branch" "$track" || die "could not create $branch from $track"
	echo "switched to $branch (tracking $track)"
else
	git switch -q "$branch" || die "could not switch to $branch"
	echo "switched to $branch"
fi
echo "next    $CMD next"

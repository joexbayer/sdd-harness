# shellcheck shell=sh
# new <type> "title" [--worktree]: branch from base, scaffold the item, commit only it.
[ $# -ge 2 ] || usage_die "usage: $NAME new <type> \"title\" [--worktree]   (types: $(types | paste -sd ' ' -))"
need_repo

type=$1
title=$2
shift 2
wt=0
for a in "$@"; do
	case $a in
	--worktree) wt=1 ;;
	*) usage_die "unknown option: $a" ;;
	esac
done

case $type in *[!a-z0-9-]* | '') usage_die "unknown type: $type" ;; esac
tpl=$(sdd_path "templates/$type.md") || usage_die "unknown type: $type (types: $(types | paste -sd ' ' -))"
[ -n "$title" ] || usage_die "the title is empty"
case $title in *'
'*) usage_die "the title must be one line" ;; esac

base=$(cfg sdd.base main)
git rev-parse -q --verify "refs/heads/$base^{commit}" >/dev/null ||
	die "base branch '$base' not found or has no commits (set base under [sdd] in $DIRNAME/config)"

id=$(next_id) || exit 1
slug=$(slugify "$title")
[ -n "$slug" ] || slug=item
branch=$(cfg "type.$type.branch" || cfg sdd.branch '{type}/{id}-{slug}')
branch=$(printf '%s\n' "$branch" | sed "s/{type}/$type/g; s/{id}/$id/g; s/{slug}/$slug/g")
dir="$SPECS/changes/$id-$slug"

if [ $wt -eq 1 ]; then
	where=$(worktree_path "$id")
	git worktree add -q -b "$branch" "$where" "$base" || die "could not create worktree $where"
	cd "$where" || exit 1
else
	git switch -q -c "$branch" "$base" || die "could not create branch $branch from $base"
	where=
fi

mkdir -p "$dir"
render "$tpl" "$id" "$title" "$type" >"$dir/item.md"
git add -- "$dir/item.md" || die "could not add $dir/item.md"
git commit -q -m "docs($id): open $type \"$title\"" -- "$dir/item.md" || die "could not commit $dir/item.md"

[ -z "$where" ] || sync_here

echo "$id $type · $title"
echo "branch  $branch${where:+   (worktree $where)}"
echo "item    $dir/item.md"
echo "next    fill in the item, then: $CMD next"

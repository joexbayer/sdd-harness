# shellcheck shell=sh
# new <type> "title" [--worktree]: branch from base, scaffold the item, commit only it.
# new --from R-<id>.<n> [--worktree]: the same for a shipped roadmap's entry (FR-24.3): its type and
# title, with "roadmap:" and "depends:" (its after: list) in the frontmatter.
[ $# -ge 2 ] || usage_die "usage: $NAME new <type> \"title\" [--worktree]   or: $NAME new --from R-<id>.<n> [--worktree]   (types: $(types | paste -sd ' ' -))"
need_repo

from=
after=
carry=
if [ "$1" = --from ]; then
	from=$2
	rid=${from#R-}
	rn=${rid#*.}
	rid=${rid%%.*}
	case $from in R-*.*) ;; *) rid= ;; esac
	case $rid:$rn in :* | *: | *[!0-9:]*) usage_die "--from takes a roadmap entry, e.g. --from R-30.2" ;; esac
	# FR-89.2: a roadmap not on the base yet but approved and written up is carried into the item's branch.
	if ! entries=$(shipped_roadmaps "$rid"); then
		src=$(carry_source "$rid" roadmap) ||
			die "no shipped roadmap $rid on $(cfg sdd.base main): only a shipped, or approved and written up, roadmap's entries open items (see: $CMD show $rid)"
		carry=${src#*"$(printf '\t')"}
		_rt=$(mktemp "${TMPDIR:-/tmp}/$NAME-roadmap.XXXXXX") && git show "${src%%"$(printf '\t')"*}:$carry/item.md" >"$_rt" ||
			die "could not read roadmap $rid"
		entries=$(roadmap_entries "$_rt" "$rid")
		rm -f "$_rt"
		# FR-89.5: one carrier at a time.
		by=$(carrier_of "$rid") && die "roadmap $rid is carried by item $by: open $from after it ships"
	fi
	entry=$(printf '%s\n' "$entries" | E=$from awk -F '\t' '$3 == ENVIRON["E"]')
	[ -n "$entry" ] || die "no entry $from in roadmap $rid (entries: $(printf '%s\n' "$entries" | cut -f3 | paste -sd ' ' -))"
	bad=$(tsv 7 "$entry")
	[ -z "$bad" ] || die "entry $from cannot be read: $bad"
	# Opened once, on any branch sdd sees (local, remote-tracking, the archive); a dropped one may be
	# opened again.
	opened=$(item_rows | E=$from awk -F '\t' '$18 == ENVIRON["E"] && $3 != "dropped" { print $1 " (" $8 ", " ($9 == "" ? $3 : $9) ")"; exit }')
	[ -z "$opened" ] || die "entry $from was already opened as item $opened"
	type=$(tsv 4 "$entry")
	title=$(tsv 5 "$entry")
	after=$(tsv 6 "$entry")
else
	type=$1
	title=$2
fi
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
# FR-73.5: a repo with no commits, and an install not yet on the base, each say what to do.
git rev-parse -q --verify HEAD >/dev/null 2>&1 ||
	die "this repo has no commits yet: commit your files first (git add -A && git commit -m init), then $DIRNAME and AGENTS.md"
git rev-parse -q --verify "refs/heads/$base^{commit}" >/dev/null ||
	die "base branch '$base' not found or has no commits (set base under [sdd] in $DIRNAME/config)"
git rev-parse -q --verify "$base:$DIRNAME/bin/$NAME" >/dev/null 2>&1 ||
	die "$NAME is not committed on $base yet: git add $DIRNAME AGENTS.md && git commit -m \"chore: adopt $NAME\""
if [ $wt -eq 0 ]; then
	dirty=$(git status --porcelain 2>/dev/null | cut -c4- | sed -n '1,5p' | paste -sd ',' - | sed 's/,/, /g')
	if [ -n "$dirty" ]; then
		[ "$(git status --porcelain | wc -l)" -le 5 ] || dirty="$dirty, …"
		warn "uncommitted changes come along to the new branch: $dirty"
	fi
fi

id=$(next_id) || exit 1
slug=$(slugify "$title")
[ -n "$slug" ] || slug=item
branch=$(cfg "type.$type.branch" || cfg sdd.branch '{type}/{id}-{slug}')
branch=$(printf '%s\n' "$branch" | sed "s/{type}/$type/g; s/{id}/$id/g; s/{slug}/$slug/g")
dir="$SPECS/changes/$id-$slug"

if [ $wt -eq 1 ]; then
	where=$(worktree_path "$id")
	git worktree add -q -b "$branch" "$where" "$base" || die "could not create worktree $where"
	exclude_worktrees
	cd "$where" || exit 1
else
	git switch -q -c "$branch" "$base" || die "could not create branch $branch from $base"
	where=
fi

mkdir -p "$dir"
render "$tpl" "$id" "$title" "$type" >"$dir/item.md"
if [ -n "$from" ]; then
	fm_set "$dir/item.md" roadmap "$from" || die "could not write $dir/item.md"
	[ -z "$after" ] || fm_set "$dir/item.md" depends "$(printf '%s' "$after" | sed 's/ /, /g')" || die "could not write $dir/item.md"
fi
git add -- "$dir/item.md" || die "could not add $dir/item.md"
# FR-89.2: the carried item's folder, copied from its branch, lands in the same commit.
[ -z "$carry" ] || git checkout -q "${src%%"$(printf '\t')"*}" -- "$carry" || die "could not carry $carry"
git commit -q -m "docs($id): open $type \"$title\"" -- "$dir/item.md" ${carry:+"$carry"} || die "could not commit $dir/item.md"

[ -z "$where" ] || sync_here
# FR-66.1: seed the worktree so it can build; a failing setup keeps the item.
setup=$(cfg worktree.setup)
if [ -n "$where" ] && [ -n "$setup" ]; then
	sh -c "$setup" </dev/null >"$where/.sdd-setup.log" 2>&1 || warn "worktree setup failed: $(tail -n 1 "$where/.sdd-setup.log")"
	rm -f "$where/.sdd-setup.log"
fi

echo "$id $type · $title"
[ -z "$from" ] || echo "roadmap $from${after:+   (depends: $(printf '%s' "$after" | sed 's/ /, /g'))}"
echo "branch  $branch${where:+   (worktree $where)}"
echo "item    $dir/item.md"
echo "next    fill in the item, then: $CMD next"

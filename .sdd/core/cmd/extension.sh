# shellcheck shell=sh
# extension [list] | add <name> [--me] | remove <name> [--me]: optional add-ons: text added to a
# step's instructions (FR-61.3), never run. .sdd/config is the team's; --me is your own user config.
usage="usage: $NAME extension [list | add <name> [--me] | remove <name> [--me]]"
need_repo
sub=${1:-list}
[ $# -eq 0 ] || shift
me=''
name=''
for a in "$@"; do
	case $a in
	--me) me=1 ;;
	-*) usage_die "$usage" ;;
	*) [ -z "$name" ] || usage_die "$usage"; name=$a ;;
	esac
done
team="$ROOT/$DIRNAME/config"
mine=$(user_config)
file=$team
[ -z "$me" ] || file=$mine

# ext_field <dir> <key>: one value of an extension's manifest.
ext_field() { git config -f "$1/extension" "extension.$2" 2>/dev/null; }
# has <config file> <name>: is that extension on in that file?
has() { [ -f "$1" ] && git config -f "$1" --get-all sdd.extension 2>/dev/null | grep -qxF -- "$2"; }

case $sub in
list)
	[ -z "$name$me" ] || usage_die "$usage"
	for e in $({ ls "$SDD_HOME/core/extensions" "$SDD_HOME/local/extensions"; } 2>/dev/null | grep -E '^[a-z0-9-]+$' | sort -u); do
		d=$(sdd_path "extensions/$e") || continue
		state=off
		has "$mine" "$e" && state='on (you)'
		has "$team" "$e" && state='on (team)'
		need=$(ext_field "$d" needs)
		note=
		[ -z "$need" ] || command -v "$need" >/dev/null 2>&1 || note=" (needs $need, not installed)"
		printf '%-14s %-10s %s%s\n' "$e" "$state" "$(ext_field "$d" description)" "$note"
	done
	;;
add)
	[ -n "$name" ] || usage_die "$usage"
	case $name in *[!a-z0-9-]*) die "unknown extension: $name (see: $CMD extension list)" ;; esac
	d=$(sdd_path "extensions/$name") || die "unknown extension: $name (see: $CMD extension list)"
	if has "$file" "$name"; then
		echo "$name is already on"
	else
		mkdir -p "$(dirname "$file")"
		git config -f "$file" --add sdd.extension "$name" || die "could not write $file"
		if [ -n "$me" ]; then echo "$name is on for you"; else echo "$name is on for the team: commit $DIRNAME/config"; fi
	fi
	need=$(ext_field "$d" needs)
	[ -z "$need" ] || command -v "$need" >/dev/null 2>&1 || warn "$need is not installed: $(ext_field "$d" url)"
	;;
remove)
	[ -n "$name" ] || usage_die "$usage"
	has "$file" "$name" || die "$name is not on in $file"
	case $name in *[!a-z0-9-]*) die "$name is not on in $file" ;; esac
	git config -f "$file" --unset-all sdd.extension "^$name\$" || die "could not write $file"
	echo "$name is off$([ -n "$me" ] && echo " for you")"
	;;
*) usage_die "$usage" ;;
esac

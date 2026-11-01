#!/bin/sh
# prepack (FR-53.33): copy this repo's .sdd/bin and .sdd/core into the package's sdd/, with a
# VERSION stamped as `sdd init` stamps it (item 49): "<version> (<12-char commit>)". Only from a
# clean .sdd/ on the base branch, so a published package never carries unshipped sdd work.
set -eu
server=$(cd "$(dirname "$0")/.." && pwd -P)
repo=$(git -C "$server" rev-parse --show-toplevel)
src="$repo/.sdd"
base=$(git config -f "$src/config" sdd.base 2>/dev/null) || base=main
branch=$(git -C "$repo" symbolic-ref --quiet --short HEAD 2>/dev/null) || branch="a detached HEAD"
if [ "$branch" != "$base" ]; then
	echo "prepack: sdd is on $branch, not $base: refusing" >&2
	exit 1
fi
if [ -n "$(git -C "$repo" status --porcelain -- .sdd/bin .sdd/core .sdd/VERSION)" ]; then
	echo "prepack: .sdd/bin, .sdd/core or .sdd/VERSION has uncommitted changes: refusing" >&2
	exit 1
fi
rm -rf "$server/sdd"
mkdir "$server/sdd"
cp -R "$src/bin" "$src/core" "$server/sdd/"
cp "$repo/LICENSE" "$server/LICENSE"
printf '%s (%s)\n' "$(cat "$src/VERSION")" "$(git -C "$repo" rev-parse --short=12 HEAD)" >"$server/sdd/VERSION"
echo "prepack: bundled sdd $(cat "$server/sdd/VERSION")"

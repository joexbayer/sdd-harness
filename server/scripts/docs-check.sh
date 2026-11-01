#!/bin/sh
# docs-check (DOD-53.1): the README's config example and deploy/sdd-server.conf.example pass
# `sdd-server check --offline`, and the README names every subcommand the CLI has.
set -eu
server=$(cd "$(dirname "$0")/.." && pwd -P)
T=$(mktemp -d "${TMPDIR:-/tmp}/sdd-server-docs.XXXXXX")
trap 'rm -rf "$T"' EXIT
fail() {
	printf 'docs-check: %s\n' "$*" >&2
	exit 1
}
awk '/^```ini$/ { on = 1; n++; next } /^```$/ { on = 0 } on && n == 1' "$server/README.md" >"$T/readme.conf"
[ -s "$T/readme.conf" ] || fail "no \`\`\`ini block in README.md"
for c in "$T/readme.conf" "$server/deploy/sdd-server.conf.example"; do
	out=$(node "$server/src/cli.ts" check --offline --config "$c") || fail "$c: $out"
	[ "$out" = "config ok: 2 repos, 2 tokens" ] || fail "$c: $out"
done
usage=$(node "$server/src/cli.ts" 2>&1 || :)
for cmd in serve check token health version; do
	case $usage in *"sdd-server $cmd"*) ;; *) fail "the CLI's usage lacks $cmd" ;; esac
	grep -q "\`$cmd" "$server/README.md" || fail "README.md does not name the $cmd subcommand"
done
echo "docs-check: ok"

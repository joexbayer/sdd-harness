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
# FR-70.6 to FR-70.8: deploy files and README that work as written.
grep -q '^[[:space:]]*init: true' "$server/deploy/compose.yaml" || fail "compose.yaml lacks init: true"
grep -q '^StateDirectory=sdd-server$' "$server/deploy/sdd-server.service" || fail "the unit lacks StateDirectory=sdd-server"
if grep -q '^ReadWritePaths' "$server/deploy/sdd-server.service"; then fail "the unit still has ReadWritePaths"; fi
grep -q 'chown -R 1000:1000 keys' "$server/README.md" || fail "README.md lacks the chown of keys to uid 1000"
grep -q 'Not on npm yet' "$server/README.md" || fail "README.md lacks the not-on-npm note"
grep -q 'server-v<version>' "$server/README.md" || fail "README.md does not tag releases server-v<version>"
grep -A4 'Not on npm yet' "$server/README.md" | grep -q 'step 1 URL' ||
	fail "README.md's not-on-npm note does not name the step 1 URL"
grep -q 'needs Node 22+' "$server/README.md" || fail "README.md's token step does not name Node 22+"
grep -q 'command -v sdd-server' "$server/deploy/sdd-server.service" || fail "the unit does not say how to find the binary"
grep -q 'every interface' "$server/deploy/sdd-server.conf.example" || fail "the conf example does not say why it listens on every interface"
echo "docs-check: ok"

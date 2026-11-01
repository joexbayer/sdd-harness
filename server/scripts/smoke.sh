#!/bin/sh
# smoke (FR-53.18, FR-53.33, FR-53.34): pack sdd-server the way `npm publish` does, install the
# tarball in a temporary prefix, start it on a fixture repo and call its tools with curl.
# The pack runs in a throwaway copy of this checkout (working tree included), committed on main,
# because prepack refuses anywhere else. Needs node, npm, git and curl; network only when the npm
# cache lacks a dependency.
set -eu
server=$(cd "$(dirname "$0")/.." && pwd -P)
repo=$(git -C "$server" rev-parse --show-toplevel)
T=$(mktemp -d "${TMPDIR:-/tmp}/sdd-server-smoke.XXXXXX")
pid=
cleanup() {
	[ -z "$pid" ] || kill "$pid" 2>/dev/null || :
	rm -rf "$T"
}
trap cleanup EXIT
fail() {
	printf 'smoke: %s\n' "$*" >&2
	exit 1
}
# HOME stays (version managers such as asdf find node through it); git and sdd get their own config.
export GIT_CONFIG_GLOBAL="$T/gitconfig" GIT_CONFIG_NOSYSTEM=1 XDG_CONFIG_HOME="$T/config"
printf '[user]\n\tname = smoke\n\temail = smoke@example.com\n[init]\n\tdefaultBranch = main\n' >"$GIT_CONFIG_GLOBAL"

# The checkout as a fresh repo on main (tracked and untracked files, not ignored ones).
mkdir "$T/src"
(cd "$repo" && git ls-files -z -co --exclude-standard | tar --null -T - -cf -) | tar -xf - -C "$T/src"
cd "$T/src"
git init -q -b main && git add -A && git commit -qm smoke
ln -s "$server/node_modules" server/node_modules

# FR-53.33: prepack refuses off main and with uncommitted sdd changes.
git switch -q -c feature/60-x
out=$(cd server && sh scripts/bundle-sdd.sh 2>&1) && fail "bundle-sdd.sh packed on a feature branch"
[ "$out" = "prepack: sdd is on feature/60-x, not main: refusing" ] || fail "off main it said: $out"
git switch -q main
echo '# edited' >>.sdd/core/lib/common.sh
out=$(cd server && sh scripts/bundle-sdd.sh 2>&1) && fail "bundle-sdd.sh packed uncommitted sdd changes"
case $out in *"uncommitted changes: refusing") ;; *) fail "with changes it said: $out" ;; esac
git checkout -q -- .sdd/core/lib/common.sh

# Pack (prepack: build, bundle) and look inside.
(cd server && npm pack --pack-destination "$T" >"$T/pack.log" 2>&1) || { cat "$T/pack.log" >&2; fail "npm pack failed"; }
tgz="$T/sdd-server-0.1.0.tgz"
[ -f "$tgz" ] || fail "no $tgz"
[ ! -e server/sdd ] || fail "postpack left server/sdd behind"
top=$(tar -tzf "$tgz" | sed 's|^package/||; s|/.*||' | sort -u | paste -sd ' ' -)
allowed=" dist sdd package.json npm-shrinkwrap.json README.md LICENSE "
for f in $top; do
	case $allowed in *" $f "*) ;; *) fail "unexpected $f in the package ($top)" ;; esac
done
for f in dist sdd package.json npm-shrinkwrap.json; do
	case " $top " in *" $f "*) ;; *) fail "the package lacks $f ($top)" ;; esac
done
tar -tzf "$tgz" | grep -qx 'package/dist/src/cli.js' || fail "no dist/src/cli.js in the package"
tar -tzf "$tgz" | grep -q '^package/test/' && fail "tests in the package"

# FR-53.34: installed from the tarball, version names both versions.
npm install -g --prefix "$T/prefix" --ignore-scripts --prefer-offline --no-audit --no-fund "$tgz" >"$T/install.log" 2>&1 ||
	{ cat "$T/install.log" >&2; fail "npm install of the tarball failed"; }
bin="$T/prefix/bin/sdd-server"
want="sdd-server 0.1.0 · sdd $(cat .sdd/VERSION) ($(git rev-parse --short=12 HEAD))"
got=$("$bin" version) || fail "version failed"
[ "$got" = "$want" ] || fail "version: expected [$want], got [$got]"

# A fixture repo with sdd and one item by kari.
git init -q --bare "$T/origin.git"
git clone -q "$T/origin.git" "$T/work" 2>/dev/null
cd "$T/work"
echo hello >README.md && git add -A && git commit -qm init
sh "$T/src/.sdd/bin/sdd" init >/dev/null 2>&1 || fail "sdd init failed"
git add -A && git commit -qm "install sdd" && git push -q origin main
GIT_AUTHOR_NAME=kari sh .sdd/bin/sdd new feature "Smoke login" >/dev/null 2>&1 || fail "sdd new failed"
git push -q origin HEAD

port=$(node -e 'const s = require("net").createServer().listen(0, "127.0.0.1", () => { console.log(s.address().port); s.close(); })')
tok=$("$bin" token kari) || fail "token failed"
token=$(printf '%s\n' "$tok" | sed -n 's/^token: //p')
{
	printf '[server]\n\tlisten = 127.0.0.1:%s\n\tpublic-host = sdd.example.com\n\tdata = %s\n' "$port" "$T/data"
	printf '[repo "api"]\n\turl = %s\n\tkey = %s\n' "$T/origin.git" "$T/no-key"
	printf '%s\n' "$tok" | sed 1d
} >"$T/config"

# FR-53.18: check clones, fetches and indexes once, one line per repo.
out=$("$bin" check --config "$T/config") || fail "check failed: $out"
[ "$out" = "api ok 1 item" ] || fail "check said: $out"

"$bin" serve --config "$T/config" >"$T/serve.log" 2>&1 &
pid=$!
i=0
until curl -fsS "http://127.0.0.1:$port/healthz" >/dev/null 2>&1; do
	i=$((i + 1))
	[ "$i" -lt 150 ] || { cat "$T/serve.log" >&2; fail "healthz never answered 200"; }
	sleep 0.2
done
"$bin" health --config "$T/config" >/dev/null || fail "health exited non-zero"

rpc() {
	curl -sS -X POST "http://127.0.0.1:$port/mcp" -H "Authorization: Bearer $1" -H 'content-type: application/json' \
		-H 'accept: application/json, text/event-stream' -H 'mcp-protocol-version: 2025-06-18' -d "$2"
}
call() { rpc "$token" "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"tools/call\",\"params\":{\"name\":\"$1\",\"arguments\":$2}}"; }
out=$(call items '{}')
case $out in *'"title":"Smoke login"'*'"opened_by":"kari"'*) ;; *) fail "items: $out" ;; esac
out=$(call item '{"repo":"api","id":1}')
case $out in *'"repo":"api"'*'"requirements":['*) ;; *) fail "item: $out" ;; esac
out=$(call search '{"query":"smoke login"}')
case $out in *'"item":1'*) ;; *) fail "search: $out" ;; esac
code=$(curl -s -o /dev/null -w '%{http_code}' -X POST "http://127.0.0.1:$port/mcp" -H 'Authorization: Bearer sdd_wrong' \
	-H 'content-type: application/json' -d '{}')
[ "$code" = 401 ] || fail "a wrong token got $code"
grep -q '"tool":"items"' "$T/serve.log" || fail "no audit line in the log"
grep -q '"auth":"refused"' "$T/serve.log" || fail "no refusal line in the log"
! grep -qF "$token" "$T/serve.log" || fail "the token is in the log"

kill -TERM "$pid"
rc=0
wait "$pid" || rc=$?
pid=
[ "$rc" -eq 0 ] || fail "serve exited $rc on SIGTERM"
echo "smoke: ok ($got)"

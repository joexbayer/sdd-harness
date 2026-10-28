# shellcheck shell=sh
# Sourced by every test: an isolated HOME and git identity, helpers and assertions.
set -u
T=$(mktemp -d "${TMPDIR:-/tmp}/sdd-test.XXXXXX")
trap 'rm -rf "$T"' EXIT
export HOME="$T/home" XDG_CONFIG_HOME="$T/home/.config" GIT_CONFIG_GLOBAL="$T/gitconfig"
export GIT_CONFIG_NOSYSTEM=1 SDD_SH="$SH"
# A role run's builder runs this suite too; its SDD_RUN would make every approve and ship refuse.
unset SDD_RUN
mkdir -p "$HOME"
git config --global user.name test
git config --global user.email test@example.com
git config --global init.defaultBranch main

sdd() { "$SH" "$SRC/.sdd/bin/sdd" "$@"; }

fail() { printf 'assertion failed: %s\n' "$*" >&2; exit 1; }
assert_eq() { [ "$1" = "$2" ] || fail "expected [$2], got [$1] ${3:-}"; }
assert_contains() { case $1 in *"$2"*) ;; *) fail "expected output to contain [$2]: $1" ;; esac; }
assert_not_contains() { case $1 in *"$2"*) fail "expected output not to contain [$2]: $1" ;; esac; }
assert_file() { [ -e "$1" ] || fail "missing $1"; }
assert_no_file() { [ ! -e "$1" ] || fail "unexpected $1"; }

# new_repo [name]: a repo with one commit on main, sdd installed, and a passing check.
new_repo() {
	R="$T/${1:-app}"
	mkdir -p "$R" && cd "$R" || exit 1
	git init -q
	echo hello >README.md
	git add README.md && git commit -qm init
	sdd init >/dev/null 2>&1 || fail "init failed"
	git config -f .sdd/config --add check.run 'echo ok'
	git add -A && git commit -qm "install sdd"
}

# setcfg <git-config args...>: change the project config and commit it (ship needs a clean tree).
setcfg() { git config -f .sdd/config "$@" && git commit -qm "test: config" -- .sdd/config; }

# fill <file> [plan|built|all]: put content under the "## " headings of that part
# (plan = above "## Built"; default all).
fill() {
	P=${2:-all} awk '
		{ print }
		/^## / {
			if ($0 == "## Built") built = 1
			if (ENVIRON["P"] == "all" || (ENVIRON["P"] == "built") == (built == 1)) print "Filled in by the test (" ENVIRON["P"] ")."
		}' "$1" >"$1.tmp" && mv "$1.tmp" "$1"
}

# planned_item <type> "title": a new item with its plan filled, committed and approved.
# Sets ITEM (the item file).
planned_item() {
	sdd new "$1" "$2" >/dev/null 2>&1 || fail "new $1 failed"
	ITEM=$(for f in specs/changes/*/item.md; do grep -q "^title: $2\$" "$f" && echo "$f"; done)
	fill "$ITEM" plan
	git add "$ITEM" && git commit -qm "docs: plan"
	sdd approve >/dev/null 2>&1 || fail "approve failed"
}

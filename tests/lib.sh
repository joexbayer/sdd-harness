# shellcheck shell=sh
# Sourced by every test: an isolated HOME and git identity, helpers and assertions.
set -u
T=$(mktemp -d "${TMPDIR:-/tmp}/sdd-test.XXXXXX")
trap 'rm -rf "$T"' EXIT
export HOME="$T/home" XDG_CONFIG_HOME="$T/home/.config" GIT_CONFIG_GLOBAL="$T/gitconfig"
export GIT_CONFIG_NOSYSTEM=1 SDD_SH="$SH"
# A role run's builder runs this suite too; its SDD_RUN would make every approve and ship refuse.
unset SDD_RUN SDD_ROLE
mkdir -p "$HOME"
# What three `git config --global` calls would write, without three git processes per test file.
printf '[user]\n\tname = test\n\temail = test@example.com\n[init]\n\tdefaultBranch = main\n' >"$GIT_CONFIG_GLOBAL"

sdd() { "$SH" "$SRC/.sdd/bin/sdd" "$@"; }

fail() { printf 'assertion failed: %s\n' "$*" >&2; exit 1; }
assert_eq() { [ "$1" = "$2" ] || fail "expected [$2], got [$1] ${3:-}"; }
assert_contains() { case $1 in *"$2"*) ;; *) fail "expected output to contain [$2]: $1" ;; esac; }
assert_not_contains() { case $1 in *"$2"*) fail "expected output not to contain [$2]: $1" ;; esac; }
assert_file() { [ -e "$1" ] || fail "missing $1"; }
assert_no_file() { [ ! -e "$1" ] || fail "unexpected $1"; }

# new_repo [name]: a repo with one commit on main, sdd installed, and a passing check.
# tests/run.sh builds one such repo per shell and exports it as SDD_TEMPLATE: a copy of it is
# much cheaper than git init, sdd init and two commits in every test. Its cached config
# (.git/sdd-config) names the builder's HOME, so it goes; sdd rebuilds it on the next call.
new_repo() {
	R="$T/${1:-app}"
	if [ -d "${SDD_TEMPLATE:-}" ] && [ ! -e "$R" ]; then
		cp -R "$SDD_TEMPLATE" "$R" && cd "$R" || exit 1
		rm -f .git/sdd-config
		return
	fi
	mkdir -p "$R" && cd "$R" || exit 1
	git init -q
	echo hello >README.md
	git add README.md && git commit -qm init
	sdd init >/dev/null 2>&1 || fail "init failed"
	git config -f .sdd/config sdd.profile lite
	git config -f .sdd/config --add check.run 'echo ok'
	git add -A && git commit -qm "install sdd"
}

# use_narrowbot: the adapter for a private agent lives in this repo's .sdd/local/agents, not in the
# core that init copies (FR-73.13); a test that runs it puts it into the repo it works in.
use_narrowbot() {
	mkdir -p .sdd/local/agents && cp "$SRC/.sdd/local/agents/narrowbot.sh" .sdd/local/agents/ &&
		git add .sdd/local && git commit -qm "test: narrowbot adapter" || fail "could not install the narrowbot adapter"
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
	# A fix always has tasks (item 69): "tasks" as a third argument writes its test-first pair.
	if [ "${3:-}" = tasks ]; then
		_n=$(sed -n 's/^id: //p' "$ITEM")
		awk -v n="$_n" '{ print } $0 == "## Tasks" { print "- [ ] T-" n ".1 Red test (test: false; expect: fail; size: S)"; print "- [ ] T-" n ".2 Fix (test: true; size: S)"; print "" }' "$ITEM" >"$ITEM.tmp" && mv "$ITEM.tmp" "$ITEM"
	fi
	git add "$ITEM" && git commit -qm "docs: plan"
	sdd approve >/dev/null 2>&1 || fail "approve failed"
}

# done_tasks: do the pair planned_item <type> "title" tasks wrote, and commit them by name, as ship
# wants where the tasks gate is on.
done_tasks() {
	_n=$(sed -n 's/^id: //p' "$ITEM")
	sdd task 'done' "T-$_n.1" >/dev/null 2>&1 || fail "task done T-$_n.1 failed"
	sdd task 'done' "T-$_n.2" >/dev/null 2>&1 || fail "task done T-$_n.2 failed"
	git add -A && git commit -qm "fix($_n): T-$_n.1 T-$_n.2 tasks"
}

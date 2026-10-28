#!/bin/sh
# Usage: tests/run.sh [shell...]   Runs every tests/t_*.sh with each given shell (default /bin/sh).
# All files under all shells run at the same time, each test in its own temp dir (tests/lib.sh);
# results print afterwards per shell, in file order. Timing tests (t_perf*.sh) run alone after
# the rest, one shell at a time, so the others' load does not count against their budgets.
[ $# -gt 0 ] || set -- /bin/sh
here=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd -P)
SRC=$(dirname "$here")
export SRC
res=$(mktemp -d "${TMPDIR:-/tmp}/sdd-run.XXXXXX") || exit 1
trap 'rm -rf "$res"' EXIT

# one <n> <shell> <test>: run a test, keeping its output and exit code under $res/<n>.<name>.
one() {
	SH=$2 "$2" "$3" >"$res/$1.${3##*/}.out" 2>&1
	echo $? >"$res/$1.${3##*/}.rc"
}

n=0
for sh in "$@"; do
	n=$((n + 1))
	for t in "$here"/t_*.sh; do
		case ${t##*/} in t_perf*) continue ;; esac
		one "$n" "$sh" "$t" &
	done
done
wait
n=0
for sh in "$@"; do
	n=$((n + 1))
	for t in "$here"/t_perf*.sh; do
		[ -f "$t" ] && one "$n" "$sh" "$t"
	done
done

rc=0
n=0
for sh in "$@"; do
	n=$((n + 1))
	pass=0
	failed=0
	for t in "$here"/t_*.sh; do
		r="$res/$n.${t##*/}"
		if [ "$(cat "$r.rc" 2>/dev/null)" = 0 ]; then
			pass=$((pass + 1))
			printf 'ok   %s\n' "${t##*/}"
		else
			failed=$((failed + 1))
			printf 'FAIL %s\n%s\n' "${t##*/}" "$(cat "$r.out" 2>/dev/null)" | sed '2,$s/^/     /'
		fi
	done
	printf '%s: %d passed, %d failed\n' "$sh" "$pass" "$failed"
	[ "$failed" -eq 0 ] || rc=1
done
exit $rc

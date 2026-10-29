#!/bin/sh
# Usage: tests/run.sh [shell...]   Runs every tests/t_*.sh with each given shell (default /bin/sh).
# Every file under every shell is one job, each in its own temp dir (tests/lib.sh). As many jobs
# run at once as the machine has CPUs (SDD_TEST_JOBS overrides): starting all ~70 at once made
# the run slower than running them one by one. Results print afterwards per shell, in file
# order. Timing tests (t_perf*.sh) run alone after the rest, one shell at a time, so the
# others' load does not count against their budgets.
[ $# -gt 0 ] || set -- /bin/sh
here=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd -P)
SRC=$(dirname "$here")
export SRC
res=$(mktemp -d "${TMPDIR:-/tmp}/sdd-run.XXXXXX") || exit 1
trap 'rm -rf "$res"' EXIT

# one <n> <shell> <test>: run a test, keeping its output and exit code under $res/<n>.<name>.
# SDD_TEMPLATE is that shell's new_repo, built once (tests/lib.sh copies it).
one() {
	SDD_TEMPLATE="$res/tpl.$1" SH=$2 "$2" "$3" </dev/null >"$res/$1.${3##*/}.out" 2>&1
	echo $? >"$res/$1.${3##*/}.rc"
}

# worker: run every job in $res/jobs that no other worker has claimed (mkdir is atomic).
worker() {
	while read -r n sh t; do
		mkdir "$res/claim.$n.${t##*/}" 2>/dev/null && one "$n" "$sh" "$t"
	done <"$res/jobs"
}

jobs=${SDD_TEST_JOBS:-$(getconf _NPROCESSORS_ONLN 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 4)}
n=0
for sh in "$@"; do
	n=$((n + 1))
	SH=$sh "$sh" -c '. "$SRC/tests/lib.sh" && new_repo >/dev/null && cp -R "$R" "$1"' sh "$res/tpl.$n" ||
		{ echo "could not build the template repo under $sh" >&2; exit 1; }
done
# Jobs alternate between the shells, so the last ones to start are not all one shell's.
for t in "$here"/t_*.sh; do
	case ${t##*/} in t_perf*) continue ;; esac
	n=0
	for sh in "$@"; do
		n=$((n + 1))
		printf '%s %s %s\n' "$n" "$sh" "$t"
	done
done >"$res/jobs"
w=0
while [ "$w" -lt "$jobs" ]; do
	worker &
	w=$((w + 1))
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

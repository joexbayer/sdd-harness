#!/bin/sh
# Usage: tests/run.sh [shell]   Runs every tests/t_*.sh with the given shell (default /bin/sh).
SH=${1:-/bin/sh}
here=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd -P)
SRC=$(dirname "$here")
export SH SRC
pass=0
failed=0
for t in "$here"/t_*.sh; do
	if out=$("$SH" "$t" 2>&1); then
		pass=$((pass + 1))
		printf 'ok   %s\n' "${t##*/}"
	else
		failed=$((failed + 1))
		printf 'FAIL %s\n%s\n' "${t##*/}" "$out" | sed '2,$s/^/     /'
	fi
done
printf '%s: %d passed, %d failed\n' "$SH" "$pass" "$failed"
[ "$failed" -eq 0 ]

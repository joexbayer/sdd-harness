# FR-16.7 sdd usage sums the logged runs per item and role, per task for one item, --md for sharing.
. "$SRC/tests/lib.sh"
new_repo
setcfg usage.track true   # off by default (FR-16.5); t_usage_off.sh covers that
assert_contains "$(sdd usage)" 'no runs logged yet'
log=$(git rev-parse --git-common-dir)/sdd/runs.tsv
mkdir -p "$(dirname "$log")"
{
	printf '# run\tstarted\titem\trole\tagent\tmodel\tphase\ttask\tin\tout\tcost\tseconds\texit\tverdict\n'
	printf '1\tt\t4\tplanner\tclaude\topus\tplan\t\t40000\t2000\t0.40\t62\t0\tdone\n'
	printf '2\tt\t4\tbuilder\tnarrow\tqwen\tbuild\tT-4.1\t30000\t3000\t\t90\t0\tpassed\n'
	printf '3\tt\t4\tbuilder\tnarrow\tqwen\tbuild\tT-4.2\t11000\t1000\t\t30\t1\tfailing\n'
	printf '4\tt\t5\tbuilder\tnarrow\tqwen\tbuild\tT-5.1\t5000\t500\t\t10\t0\tpassed\n'
} >"$log"

# Per item and role: builder on item 4 is two runs, 41k in, 4k out, no cost, 2m 0s.
out=$(sdd usage)
assert_contains "$out" "$(printf '%-6s %-10s %-8s %5d %8s %8s %9s %9s' 4 builder - 2 41k 4k - '2m 0s')"
assert_contains "$out" "$(printf '%-6s %-10s %-8s %5d %8s %8s %9s %9s' 4 planner - 1 40k 2k '$0.40' '1m 2s')"
assert_contains "$out" "$(printf '%-6s %-10s %-8s %5d %8s %8s %9s %9s' total '' '' 4 86k 6k '$0.40' '3m 12s')"

# One item: per task too; other items left out.
out=$(sdd usage 4)
assert_contains "$out" "$(printf '%-6s %-10s %-8s %5d' 4 builder T-4.1 1)"
assert_contains "$out" "$(printf '%-6s %-10s %-8s %5d' 4 builder T-4.2 1)"
assert_not_contains "$out" 'T-5.1'
assert_contains "$(sdd usage 9)" 'no runs logged for item 9'

# --md: a Markdown table.
out=$(sdd usage --md)
assert_eq "$(printf '%s\n' "$out" | head -n 1)" '| item | role | task | runs | in | out | cost | time |'
assert_contains "$out" '| 4 | planner | - | 1 | 40k | 2k | $0.40 | 1m 2s |'
sdd usage x >/dev/null 2>&1
assert_eq $? 2 "(bad argument)"
exit 0

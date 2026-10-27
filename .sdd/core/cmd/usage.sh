# shellcheck shell=sh
# usage [<id>] [--md]: what the logged runs cost, from this clone's .git/sdd/runs.tsv (written by
# sdd run and by role subagents): runs, tokens in and out, cost and time per item and role, and
# per task too for one item. --md prints a Markdown table, for sharing.
id=
md=
for a in "$@"; do
	case $a in
	--md) md=1 ;;
	*[!0-9]* | '') usage_die "usage: $NAME usage [<id>] [--md]" ;;
	*) id=$a ;;
	esac
done
need_repo
log="$ST/runs.tsv"
if ! usage_on; then
	echo "usage tracking is off"
	echo "next    switch it on: add [usage] track = true to $DIRNAME/config (or your $(user_config))"
	exit 0
fi
if ! grep -qv '^#' "$log" 2>/dev/null; then
	echo "no runs logged yet"
	echo "next    $CMD run <role> <id>, or ask your agent to run a role on an item"
	exit 0
fi

grep -v '^#' "$log" | I=$id MD=$md awk -F '\t' '
	function k(x) { return x >= 1000000 ? sprintf("%.1fM", x / 1000000) : x >= 1000 ? sprintf("%.0fk", x / 1000) : x }
	function t(s) { return s >= 60 ? sprintf("%dm %ds", s / 60, s % 60) : s "s" }
	function money(c, has) { return has ? sprintf("$%.2f", c) : "-" }
	function row(a, b, c, key) {
		if (ENVIRON["MD"] != "") printf "| %s | %s | %s | %d | %s | %s | %s | %s |\n", a, b, c, runs[key], k(tin[key]), k(tout[key]), money(cost[key], priced[key]), t(secs[key])
		else printf "%-6s %-10s %-8s %5d %8s %8s %9s %9s\n", a, b, c, runs[key], k(tin[key]), k(tout[key]), money(cost[key], priced[key]), t(secs[key])
	}
	ENVIRON["I"] != "" && $3 != ENVIRON["I"] { next }
	{
		key = $3 SUBSEP $4 SUBSEP (ENVIRON["I"] != "" ? $8 : "")
		if (!(key in runs)) order[++n] = key
		runs[key]++; tin[key] += $9; tout[key] += $10; secs[key] += $12
		if ($11 != "") { cost[key] += $11; priced[key] = 1 }
		T = "total"; runs[T]++; tin[T] += $9; tout[T] += $10; secs[T] += $12
		if ($11 != "") { cost[T] += $11; priced[T] = 1 }
	}
	END {
		if (n == 0) { print "no runs logged for item " ENVIRON["I"]; exit }
		if (ENVIRON["MD"] != "") { print "| item | role | task | runs | in | out | cost | time |"; print "|---|---|---|---|---|---|---|---|" }
		else printf "%-6s %-10s %-8s %5s %8s %8s %9s %9s\n", "item", "role", "task", "runs", "in", "out", "cost", "time"
		for (i = 1; i <= n; i++) { split(order[i], p, SUBSEP); row(p[1], p[2], (p[3] == "" ? "-" : p[3]), order[i]) }
		row("total", "", "", "total")
	}'

# shellcheck shell=sh
# run <role> <id>: one step of an item, headless, with the agent and model the role is set to;
# logged in this clone's .git/sdd/runs.tsv. Roles on Claude models usually run as subagents
# instead (sync claude); this is the path for the others, and for scripts.
[ $# -eq 2 ] || usage_die "usage: $NAME run <role> <id>"
role=$1
id=$2
case $role in '' | *[!a-z0-9-]*) usage_die "role names are lowercase words, e.g. builder" ;; esac
case $id in '' | *[!0-9]*) usage_die "usage: $NAME run <role> <id>" ;; esac
need_repo
current_item && [ "$ID" = "$id" ] || die "item $id is not checked out here (open it with: $CMD open $id)"

# mine <key> [default]: a tier or agent setting, the developer's own config first, then the
# project's: the team names roles, each developer chooses the agent and model behind them.
mine() {
	for _f in "$(user_config)" "$SDD_HOME/config" "$SDD_HOME/core/config"; do
		[ -f "$_f" ] && git config -f "$_f" --get "$1" && return 0
	done
	[ $# -gt 1 ] && printf '%s\n' "$2"
}
tier=$(cfg "role.$role.tier") ||
	usage_die "no tier for role $role; add to $DIRNAME/config:
[role \"$role\"]
	tier = <name, e.g. small>"
agent=$(mine "tier.$tier.agent")
model=$(mine "tier.$tier.model")
[ -n "$agent" ] && [ -n "$model" ] ||
	usage_die "tier $tier has no agent or model; add to $(user_config) (yours) or $DIRNAME/config:
[tier \"$tier\"]
	agent = <claude|narrow>
	model = <model name>"
args=$(mine "tier.$tier.args" '')
bin=$(mine "agent.$agent.bin" "$agent")
adapter=$(sdd_path "agents/$agent.sh") || usage_die "unknown agent: $agent (agents: $(agents | paste -sd ' ' -))"
# shellcheck source=/dev/null
. "$adapter"
command -v agent_run >/dev/null 2>&1 || die "$agent cannot run headless from $NAME yet"

# What the role is to do: the item's next step, plus the role's own prompt if the project has one.
item_phase
phase=$PHASE
task=
[ "$WHYCODE" != task ] || task=$(task_rows | awk -F '\t' '$2 == "open" { print $1; exit }')
mkdir -p "$ST/runs"
n=1
while ! mkdir "$ST/runs/$n" 2>/dev/null; do n=$((n + 1)); done
dir="$ST/runs/$n"
"${SDD_SH:-/bin/sh}" "$SDD_HOME/bin/$NAME" next >"$dir/prompt.md" 2>&1
if _rp=$(sdd_path "prompts/role-$role.md"); then
	printf '\n' >>"$dir/prompt.md"
	render "$_rp" "$ID" "$(fm_get title "$IFILE")" "$ITYPE" >>"$dir/prompt.md"
fi

echo "run $n · $role · $agent $model · item $ID${task:+ $task} · started"
start=$(date +%s)
started=$(date -u +%Y-%m-%dT%H:%M:%SZ)
agent_run "$bin" "$model" "$dir/prompt.md" "$dir/out" "$args" 2>"$dir/stderr"
rc=$?
secs=$(($(date +%s) - start))
use=$(agent_usage "$dir/out")
[ "$rc" -ne 127 ] || use=$(printf '\t\t\t%s not found' "$bin")

[ -s "$ST/runs.tsv" ] || printf '# run\tstarted\titem\trole\tagent\tmodel\tphase\ttask\tin\tout\tcost\tseconds\texit\tverdict\n' >"$ST/runs.tsv"
# One line per run: run, started, item, role, agent, model, phase, task, in, out, cost, seconds,
# exit, verdict (usage.sh reads these columns).
printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$n" "$started" "$ID" "$role" "$agent" "$model" \
	"$phase" "$task" "$(tsv 1 "$use")" "$(tsv 2 "$use")" "$(tsv 3 "$use")" "$secs" "$rc" "$(tsv 4 "$use")" >>"$ST/runs.tsv"
tail -n 1 "$ST/runs.tsv" | awk -F '\t' '
	function k(x) { return x == "" ? "?" : x >= 1000 ? sprintf("%.0fk", x / 1000) : x }
	{ printf "run %s · %s · %s %s · %s%s · %s in / %s out%s · %ss · exit %s · %s\n", $1, $4, $5, $6, "item " $3, ($8 == "" ? "" : " " $8),
		k($9), k($10), ($11 == "" ? "" : " · $" $11), $12, $13, ($14 == "" ? "-" : $14) }'
[ "$rc" -eq 0 ] || { echo "✗ the agent exited $rc (its output: $dir)"; exit 1; }
echo "next    $CMD next   (or $CMD usage $ID)"

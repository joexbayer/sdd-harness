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

tier=$(cfg "role.$role.tier") ||
	usage_die "no tier for role $role; add to $DIRNAME/config:
[role \"$role\"]
	tier = <name, e.g. small>"
# The tier is read whole from one file: yours if you define it, else the project's (tier_file).
agent=$(tier_get "$tier" agent)
model=$(tier_get "$tier" model)
[ -n "$agent" ] && [ -n "$model" ] ||
	usage_die "tier $tier has no agent or model; add to $(user_config) (yours) or $DIRNAME/config:
[tier \"$tier\"]
	agent = <claude|narrow>
	model = <model name>"
tier_ok "$agent" "$model" || usage_die "tier $tier: agent must be a word and model a name without spaces or quotes (got: $agent, $model)"
args=$(tier_get "$tier" args)
bin=$(cfg_mine "agent.$agent.bin" "$agent")
adapter=$(sdd_path "agents/$agent.sh") || usage_die "unknown agent: $agent (agents: $(agents | paste -sd ' ' -))"
# shellcheck source=/dev/null
. "$adapter"
command -v agent_run >/dev/null 2>&1 || die "$agent cannot run headless from $NAME yet"

# What the role is to do: the item's next step, plus the role's own prompt if the project has one.
item_phase
# A role works the agent's phases only: approving, reviewing and shipping are the human's.
case $WHYCODE in
approval | changed | ready | pr | status) usage_die "item $ID is waiting for the human ($WHY): no role runs now" ;;
esac
phase=$PHASE
# In build, the role works the current batch of tasks (task_batch), which next shows it.
task=$TASK
[ -z "$task" ] || task=$(ir_batch | cut -f1 | paste -sd ' ' -)
run_slot
n=$RUN
dir=$RUNDIR
"${SDD_SH:-/bin/sh}" "$SDD_HOME/bin/$NAME" next >"$dir/prompt.md" 2>&1
if _rp=$(sdd_path "prompts/role-$role.md"); then
	printf '\n' >>"$dir/prompt.md"
	render "$_rp" "$ID" "$(fm_get title "$IFILE")" "$ITYPE" >>"$dir/prompt.md"
fi

echo "run $n · $role · $agent $model · item $ID${task:+ $task} · started"
start=$(date +%s)
started=$(date -u +%Y-%m-%dT%H:%M:%SZ)
# The agent knows it is a role run: approve, ship and tidy --remote refuse it (human_only).
SDD_RUN=$n
export SDD_RUN
# args are split on spaces, as written in the tier (no quoting), and never glob-expanded.
set -f
agent_run "$bin" "$model" "$dir/prompt.md" "$dir/out" "$args" 2>"$dir/stderr"
rc=$?
set +f
secs=$(($(date +%s) - start))
use=$(agent_usage "$dir/out")
[ "$rc" -ne 127 ] || use=$(printf '\t\t\t%s not found' "$bin")

run_log "$n" "$started" "$ID" "$role" "$agent" "$model" "$phase" "$task" "$(tsv 1 "$use")" "$(tsv 2 "$use")" \
	"$(tsv 3 "$use")" "$secs" "$rc" "$(tsv 4 "$use")"
[ "$rc" -eq 0 ] || { echo "✗ the agent exited $rc (its output: $dir)"; exit 1; }
# Tracking off: the agent's output was only needed for this summary (kept above when it failed).
usage_on || rm -rf "$dir"
echo "next    $CMD next   (or $CMD usage $ID)"

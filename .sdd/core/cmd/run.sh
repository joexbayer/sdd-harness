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
# A role works the agent's phases only: approving, reviewing and shipping are the human's. A ready
# item still takes review-time roles (a verifier), not the builder: its work is done (FR-33.1).
case $WHYCODE in
approval | changed | contract | pr | status) usage_die "item $ID is waiting for the human ($WHY): no role runs now" ;;
ready) [ "$role" != builder ] || usage_die "item $ID is waiting for the human ($WHY): no role runs now" ;;
esac
# FR-28.1, D-28.1: a builder run does tasks only. Finishing needs judgment: it is the session's
# that orchestrates the build, not a prompt a small model ignores.
[ "$role" != builder ] || [ "$PHASE" != build ] || [ "$WHYCODE" = task ] ||
	usage_die "item $ID has no open task: finishing (check, security pass, verifier, Built) is the orchestrating session's: $CMD next"
phase=$PHASE
# In build, the role works the current batch of tasks (task_batch), which next shows it. A batch
# belongs to one role (`by:`, the builder when none): another role's run is refused (FR-36.3).
task=$TASK
if [ -n "$task" ]; then
	batch=$(ir_batch)
	task=$(printf '%s\n' "$batch" | cut -f1 | paste -sd ' ' -)
	by=$(printf '%s\n' "$batch" | head -n 1 | cut -f11)
	by=${by:-builder}
	[ "$role" = "$by" ] || usage_die "${task%% *} is the $by's: $CMD run $by $ID"
fi
run_slot
n=$RUN
dir=$RUNDIR
"${SDD_SH:-/bin/sh}" "$SDD_HOME/bin/$NAME" next >"$dir/prompt.md" 2>&1
# FR-36.5, D-36.3: a batch run's job, before the project's own role prompt.
if [ -n "$task" ] && _rp=$(sdd_path prompts/role-batch.md); then
	printf '\n' >>"$dir/prompt.md"
	render "$_rp" "$ID" "$(fm_get title "$IFILE")" "$ITYPE" >>"$dir/prompt.md"
fi
if _rp=$(sdd_path "prompts/role-$role.md"); then
	printf '\n' >>"$dir/prompt.md"
	render "$_rp" "$ID" "$(fm_get title "$IFILE")" "$ITYPE" >>"$dir/prompt.md"
fi

echo "run $n · $role · $agent $model · item $ID${task:+ $task} · started"
start=$(date +%s)
started=$(date -u +%Y-%m-%dT%H:%M:%SZ)
# The agent knows it is a role run: approve, ship and tidy --remote refuse it (human_only), and
# the finish gate holds only a builder (hook stop).
SDD_RUN=$n
SDD_ROLE=$role
export SDD_RUN SDD_ROLE
# FR-34.1, D-34.1, FR-36.4: the item file is not the batch role's to write (sdd ticks its tasks
# below; Built comes after the build), so a batch run gets it back as it was.
before=
if [ -n "$task" ]; then
	before=$(mktemp "${TMPDIR:-/tmp}/$NAME-item.XXXXXX") && cp "$IFILE" "$before" || die "could not copy $IFILE"
fi
# args are split on spaces, as written in the tier (no quoting), and never glob-expanded.
set -f
agent_run "$bin" "$model" "$dir/prompt.md" "$dir/out" "$args" 2>"$dir/stderr"
rc=$?
set +f
if [ -n "$before" ]; then
	cmp -s "$before" "$IFILE" ||
		{ cp "$before" "$IFILE" && echo "⚠ the $role edited $IFILE: restored (sdd ticks its tasks; Built is written after the build)"; }
	rm -f "$before"
fi
secs=$(($(date +%s) - start))
use=$(agent_usage "$dir/out")
[ "$rc" -ne 127 ] || use=$(printf '\t\t\t%s not found' "$bin")

run_log "$n" "$started" "$ID" "$role" "$agent" "$model" "$phase" "$task" "$(tsv 1 "$use")" "$(tsv 2 "$use")" \
	"$(tsv 3 "$use")" "$secs" "$rc" "$(tsv 4 "$use")"
# FR-28.3, D-28.2: the adapter may say an exit code is not a failure (agent_exit_note prints why);
# the log above keeps the real code.
[ "$rc" -eq 0 ] || { command -v agent_exit_note >/dev/null 2>&1 && agent_exit_note "$rc"; } ||
	{ echo "✗ the agent exited $rc (its output: $dir)"; exit 1; }
# FR-31.1, D-31.1, FR-36.4: in a batch run the batch's own tests decide, not the model: sdd ticks
# each task the agent left open, in plan order, and stops at the first that fails. It commits
# nothing (C-4): it prints the commit for the orchestrator to make.
if [ -n "$task" ]; then
	rows=$(task_rows)
	left=
	for t in $task; do
		[ "$(printf '%s\n' "$rows" | T=$t awk -F '\t' '$1 == ENVIRON["T"] { print $2 }')" != open ] || left="$left $t"
	done
	case $ITYPE in feature) kind=feat ;; hotfix) kind=fix ;; *) kind=$ITYPE ;; esac
	of=$(printf '%s\n' $left | grep -c .)
	ticked=
	what=
	n_ok=0
	for t in $left; do
		if tick=$("${SDD_SH:-/bin/sh}" "$SDD_HOME/bin/$NAME" task 'done' "$t" 2>&1); then
			printf '%s\n' "$tick" | sed -n '1s/ · commit with: .*//p'
			n_ok=$((n_ok + 1))
			ticked="$ticked $t"
			what="${what:+$what, }$(printf '%s\n' "$rows" | T=$t awk -F '\t' '$1 == ENVIRON["T"] { print $3 }')"
		else
			printf '%s\n' "$tick"
			echo "ticked $n_ok of $of${ticked:+ · commit with: $kind($ID):$ticked $what}"
			exit 1
		fi
	done
	[ -z "$left" ] || echo "ticked $n_ok of $of · commit with: $kind($ID):$ticked $what"
fi
# Tracking off: the agent's output was only needed for this summary (kept above when it failed).
usage_on || rm -rf "$dir"
echo "next    $CMD next   (or $CMD usage $ID)"

# shellcheck shell=sh
# hook <event> --agent <agent>: called by agent hooks. Decides ok/warn/block plus a message;
# agents/<agent>.sh turns that into the agent's own output format. Never fails loudly.
event=${1:-}
[ $# -gt 0 ] && shift
agent=
while [ $# -gt 0 ]; do
	case $1 in
	--agent) agent=${2:-}; [ $# -gt 1 ] && shift ;;
	esac
	shift
done

input=
[ -t 0 ] || input=$(cat)
cwd=
active=false
if [ -n "$input" ] && command -v jq >/dev/null 2>&1; then
	cwd=$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null)
	active=$(printf '%s' "$input" | jq -r '.stop_hook_active // false' 2>/dev/null)
fi
if [ -n "$cwd" ]; then cd "$cwd" 2>/dev/null || exit 0; fi
git rev-parse --show-toplevel >/dev/null 2>&1 || exit 0
need_repo

# Role subagents (sync claude): note the start, and at the stop log the run with the tokens
# summed from its transcript (no hook reports them; kb/claude-subagents.md). Never blocks.
case $event in
subagent-start | subagent-stop)
	command -v jq >/dev/null 2>&1 && [ -n "$input" ] || exit 0
	type=$(printf '%s' "$input" | jq -r '.agent_type // empty')
	aid=$(printf '%s' "$input" | jq -r '.agent_id // empty')
	case $type in "$NAME"-*) ;; *) exit 0 ;; esac
	case $aid in '' | *[!A-Za-z0-9_-]*) exit 0 ;; esac
	mkdir -p "$ST/runs"
	mark="$ST/runs/sub.$aid"
	if [ "$event" = subagent-start ]; then
		item=- phase=- task=
		if current_item; then
			item=$ID
			item_phase
			phase=$PHASE
			[ "$WHYCODE" != task ] || task=$(task_rows | awk -F '\t' '$2 == "open" { print $1; exit }')
		fi
		printf '%s\t%s\t%s\t%s\t%s\n' "$(date +%s)" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$item" "$phase" "$task" >"$mark"
		exit 0
	fi
	st=$(cat "$mark" 2>/dev/null)
	rm -f "$mark"
	[ -n "$st" ] || st=$(printf '%s\t%s\t-\t-\t' "$(date +%s)" "$(date -u +%Y-%m-%dT%H:%M:%SZ)")
	tr=$(printf '%s' "$input" | jq -r '.agent_transcript_path // empty')
	# shellcheck source=/dev/null
	. "$(sdd_path agents/claude.sh)"
	use=
	[ -f "$tr" ] && use=$(agent_transcript_usage "$tr" 2>/dev/null)
	verdict='done'
	[ -n "$use" ] || verdict="no transcript"
	run_slot
	[ -z "$tr" ] || printf '%s\n' "$tr" >"$RUNDIR/transcript"
	run_log "$RUN" "$(tsv 2 "$st")" "$(tsv 3 "$st")" "${type#"$NAME"-}" claude "$(tsv 3 "$use")" "$(tsv 4 "$st")" "$(tsv 5 "$st")" \
		"$(tsv 1 "$use")" "$(tsv 2 "$use")" "" "$(($(date +%s) - $(tsv 1 "$st")))" 0 "$verdict" >/dev/null
	exit 0
	;;
esac

level=ok
msg=
case $event in
session-start)
	msg="$("${SDD_SH:-/bin/sh}" "$SDD_HOME/bin/$NAME" status 2>/dev/null)
This repo uses $NAME. For instructions on the current phase run: $CMD next"
	;;
stop)
	# The finish gate: an agent may not stop with code changes that are unplanned,
	# unapproved, unverified or not written up. Planning and review talk never trips it.
	if current_item && code_changed; then
		item_phase
		case $PHASE in
		plan) msg="$NAME: item $ID has code changes but the plan is not ready ($WHY). Do not build before the human approves." ;;
		build) msg="$NAME: item $ID is not finished: $WHY. Run $CMD next." ;;
		pr) check_passed_here "$ID" || msg="$NAME: item $ID is in a pull request and has changes no check has passed. Run $CMD check." ;;
		esac
		[ -n "$msg" ] && level=$(cfg "type.$ITYPE.finish" || cfg "profile.$(cfg sdd.profile lite).finish" off)
	fi
	;;
*) exit 0 ;;
esac
[ "$level" = off ] && level=ok

if [ -n "$agent" ] && _a=$(sdd_path "agents/$agent.sh"); then
	# shellcheck source=/dev/null
	. "$_a"
	agent_hook_reply "$event" "$level" "$msg" "$active"
	exit 0
fi
[ "$event" = session-start ] && { printf '%s\n' "$msg"; exit 0; }
[ -n "$msg" ] && printf '%s\n' "$msg" >&2
[ "$level" = block ] && exit 2
exit 0

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
	# Both fields in one jq run: "<cwd>\n<stop_hook_active>".
	fields=$(printf '%s' "$input" | jq -r '"\(.cwd // "")\n\(.stop_hook_active // false)"' 2>/dev/null)
	cwd=${fields%%"
"*}
	active=${fields#*"
"}
fi
if [ -n "$cwd" ]; then cd "$cwd" 2>/dev/null || exit 0; fi
find_repo || exit 0

# Role subagents (sync claude): the agent's adapter logs them (agent_subagent_hook). Never blocks.
case $agent in *[!a-z0-9-]*) agent= ;; esac
case $event in
subagent-start | subagent-stop)
	if [ -n "$agent" ] && _a=$(sdd_path "agents/$agent.sh"); then
		# shellcheck source=/dev/null
		. "$_a"
		! command -v agent_subagent_hook >/dev/null 2>&1 || agent_subagent_hook "$event" "$input"
	fi
	exit 0
	;;
esac

level=ok
msg=
case $event in
session-start)
	# status, run in this process: a subshell instead of a new sdd.
	# shellcheck source=/dev/null
	msg="$(set --; . "$(sdd_path cmd/status.sh)" 2>/dev/null)
This repo uses $NAME. For instructions on the current phase run: $CMD next"
	;;
stop)
	# The finish gate: an agent may not stop with code changes that are unplanned,
	# unapproved, unverified or not written up. Planning and review talk never trips it, nor
	# does a role run that does not build (a verifier reports; its builder finishes the item), nor
	# a role run's builder once its tasks are done (FR-28.2).
	if [ "${SDD_ROLE:-builder}" = builder ] && current_item && code_changed; then
		item_phase
		case $PHASE in
		# FR-60.1: the next step is the human's, so a block could only trap the agent.
		plan) msg="$NAME: item $ID has code changes but the plan is not ready ($WHY). The next step is the human's: stop and ask them." ;;
		# FR-28.2: a role run's builder does tasks only; once none is open, finishing (check,
		# Built) is the orchestrating session's, so it may stop.
		build) [ -n "${SDD_RUN:-}" ] && [ "$WHYCODE" != task ] || msg="$NAME: item $ID is not finished: $WHY. Run $CMD next." ;;
		pr) check_passed_here "$ID" || msg="$NAME: item $ID is in a pull request and has changes no check has passed. Run $CMD check." ;;
		esac
		[ -n "$msg" ] && level=$(cfg "type.$ITYPE.finish" || cfg "profile.$(cfg sdd.profile lite).finish" off)
		[ "$PHASE" != plan ] || [ "$level" != block ] || level=warn
	fi
	;;
*) exit 0 ;;
esac
[ "$level" = off ] && level=ok

# shellcheck source=/dev/null
if [ -n "$agent" ] && _a=$(sdd_path "agents/$agent.sh") && . "$_a" && command -v agent_hook_reply >/dev/null 2>&1; then
	agent_hook_reply "$event" "$level" "$msg" "$active"
	exit 0
fi
[ "$event" = session-start ] && { printf '%s\n' "$msg"; exit 0; }
[ -n "$msg" ] && printf '%s\n' "$msg" >&2
[ "$level" = block ] && exit 2
exit 0

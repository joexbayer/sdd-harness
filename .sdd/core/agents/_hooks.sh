# shellcheck shell=sh
# Shared by agents whose hooks use the { "hooks": { "<Event>": [ { "hooks": [ ... ] } ] } }
# layout and { decision, reason, systemMessage } replies: Claude Code and Codex.

need_jq() {
	command -v jq >/dev/null 2>&1 || die "jq is required for agent hooks (brew install jq / apt install jq)"
}

# hook_cmd <event> <agent>: a command that finds the repo's own copy and runs it. Tagged
# so a later sync can replace exactly the entries it created.
hook_cmd() {
	printf "sh -c 'd=\$(git rev-parse --show-toplevel 2>/dev/null) || exit 0; [ -f \"\$d/%s/bin/%s\" ] || exit 0; exec /bin/sh \"\$d/%s/bin/%s\" hook %s --agent %s' # %s-managed" \
		"$DIRNAME" "$NAME" "$DIRNAME" "$NAME" "$1" "$2" "$NAME"
}

# merge_hooks <file> <agent>: add our SessionStart and Stop hooks, keeping everything else.
merge_hooks() {
	mkdir -p "$(dirname "$1")"
	[ -s "$1" ] || echo '{}' >"$1"
	if ! jq --arg ss "$(hook_cmd session-start "$2")" --arg stop "$(hook_cmd stop "$2")" --arg tag "$NAME-managed" '
		def clean: map(.hooks |= map(select((.command // "") | contains($tag) | not)))
			| map(select((.hooks | length) > 0));
		.hooks = (.hooks // {})
		| .hooks.SessionStart = (((.hooks.SessionStart // []) | clean) + [{hooks: [{type: "command", command: $ss}]}])
		| .hooks.Stop = (((.hooks.Stop // []) | clean) + [{hooks: [{type: "command", command: $stop}]}])
	' "$1" >"$1.tmp.$$"; then
		rm -f "$1.tmp.$$"
		die "could not update $1 (is it valid JSON?)"
	fi
	mv "$1.tmp.$$" "$1"
}

# agent_hook_reply <event> <level> <message> <stop_hook_active>
# session-start: plain stdout becomes context. stop: block once, then let it stop with a
# warning so the report carries the problem instead of looping.
agent_hook_reply() {
	case $1 in
	session-start) [ -n "$3" ] && printf '%s\n' "$3" ;;
	stop)
		case $2 in
		warn) jq -n --arg m "$3" '{systemMessage: $m}' ;;
		block)
			if [ "$4" = true ]; then
				jq -n --arg m "unverified: $3" '{systemMessage: $m}'
			else
				jq -n --arg m "$3" '{decision: "block", reason: $m}'
			fi
			;;
		esac
		;;
	esac
	return 0
}

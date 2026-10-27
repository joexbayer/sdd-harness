# shellcheck shell=sh
# Claude Code: CLAUDE.md imports AGENTS.md (Claude reads AGENTS.md only when there is no
# CLAUDE.md); hooks live in .claude/settings.local.json.
# shellcheck source=/dev/null
. "$(sdd_path agents/_hooks.sh)"

agent_sync() {
	need_jq
	if [ ! -f CLAUDE.md ]; then
		printf '@AGENTS.md\n' >CLAUDE.md
		exclude CLAUDE.md
		echo "created CLAUDE.md (imports AGENTS.md; kept out of git)"
	elif ! grep -qx '@AGENTS.md' CLAUDE.md; then
		printf '\n@AGENTS.md\n' >>CLAUDE.md
		echo "added @AGENTS.md to CLAUDE.md (commit this change)"
	fi
	merge_hooks .claude/settings.local.json claude
	ask_rules .claude/settings.local.json
	exclude .claude/settings.local.json
	echo "claude: session-start and stop hooks, and ask rules for approve, ship and tidy --remote, in .claude/settings.local.json"
	install_skills .claude/skills claude
	echo "claude: skills $NAME-new, -plan, -build, -review, -ship in .claude/skills (all kept out of git)"
}

# ask_rules <settings>: Claude Code asks the human before approve, ship or tidy --remote runs.
# Covers the spellings agents use (relative, ./, sh or bash, this checkout's absolute path,
# and the bare name for a symlink on PATH); a relative path from a subfolder
# (../.sdd/bin/sdd) is not.
# Replaces exactly these entries, keeping the user's own rules.
ask_rules() {
	jq --arg cmd "$CMD" --arg root "$ROOT" --arg name "$NAME" '
		([$cmd, "./" + $cmd, "sh " + $cmd, "bash " + $cmd, $root + "/" + $cmd, $name]
			| map(. as $c | ["approve", "ship", "tidy --remote"] | map("Bash(" + $c + " " + . + ":*)")) | flatten) as $add
		| .permissions = (.permissions // {})
		| .permissions.ask = (((.permissions.ask // []) - $add) + $add)
	' "$1" >"$1.tmp.$$" || { rm -f "$1.tmp.$$"; die "could not update $1"; }
	mv "$1.tmp.$$" "$1"
}

# agent_usage <output file>: "<tokens in>\t<tokens out>\t<cost>\t<verdict>" from the result line
# of `claude -p --output-format json`. Tokens in count cached input too (what was processed).
agent_usage() {
	_l=$(grep '"type":"result"' "$1" 2>/dev/null | tail -n 1)
	[ -n "$_l" ] || { printf '\t\t\tno result\n'; return 0; }
	_a=$(json_num input_tokens "$_l") _b=$(json_num cache_creation_input_tokens "$_l") _c=$(json_num cache_read_input_tokens "$_l")
	_in=$((${_a:-0} + ${_b:-0} + ${_c:-0}))
	_v=ok
	case $_l in *'"is_error":true'*) _v=$(json_str subtype "$_l") ;; esac
	printf '%s\t%s\t%s\t%s\n' "$_in" "$(json_num output_tokens "$_l")" "$(json_num total_cost_usd "$_l")" "${_v:-error}"
}

# agent_transcript_usage <subagent transcript>: "<tokens in>\t<tokens out>\t<model>", summed over
# its assistant messages, each message once (parallel tool calls repeat one message; the largest
# output count is the final one). The transcript layout is Claude Code's own (kb/claude-subagents.md).
agent_transcript_usage() {
	need_jq
	jq -rs '[.[] | select(.message.usage? != null) | {id: .message.id, model: .message.model, u: .message.usage}]
		| group_by(.id) | map(max_by(.u.output_tokens // 0))
		| [ (map((.u.input_tokens // 0) + (.u.cache_creation_input_tokens // 0) + (.u.cache_read_input_tokens // 0)) | add // 0),
		    (map(.u.output_tokens // 0) | add // 0),
		    (map(.model) | map(select(. != null)) | first // "") ] | @tsv' "$1"
}

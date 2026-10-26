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
	exclude .claude/settings.local.json
	echo "claude: session-start and stop hooks in .claude/settings.local.json (kept out of git)"
}

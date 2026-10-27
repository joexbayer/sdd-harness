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

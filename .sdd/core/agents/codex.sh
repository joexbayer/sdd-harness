# shellcheck shell=sh
# Codex: reads AGENTS.md natively; hooks live in .codex/hooks.json and only run once the
# project is trusted and the hooks are reviewed (/hooks in Codex).
# shellcheck source=/dev/null
. "$(sdd_path agents/_hooks.sh)"

agent_sync() {
	need_jq
	merge_hooks .codex/hooks.json codex
	exclude .codex/hooks.json
	echo "codex: session-start and stop hooks in .codex/hooks.json (kept out of git)"
	install_skills .agents/skills codex
	echo "codex: skills $NAME-new, -plan, -build, -review, -ship, -audit-states in .agents/skills (kept out of git)"
	echo "next    trust the hooks in Codex with /hooks (sdd sets no Codex approval rules yet: approve and ship are yours to run)"
}

# shellcheck shell=sh
# Narrow (a terminal agent harness): reads AGENTS.md itself and calls `sdd hook stop` as its finish
# gate, so there is nothing to sync. sdd runs it headless for roles on non-Claude models.

agent_sync() {
	echo "narrow: reads AGENTS.md and uses $CMD hook stop as its finish gate; nothing to sync"
}

# agent_usage <output file>: "<tokens in>\t<tokens out>\t<cost>\t<verdict>" from the `finish`
# event of `narrow --json` (cost only when the model is priced).
agent_usage() {
	_l=$(grep '"type":"finish"' "$1" 2>/dev/null | tail -n 1)
	[ -n "$_l" ] || { printf '\t\t\tno finish event\n'; return 0; }
	printf '%s\t%s\t%s\t%s\n' "$(json_num in "$_l")" "$(json_num out "$_l")" "$(json_num cost "$_l")" "$(json_str verdict "$_l")"
}

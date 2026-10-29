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

# agent_run <bin> <model> <prompt file> <output file> <args>: one headless run in this repo,
# events as JSON. Only the tier's args are added (e.g. --profile local, or --yolo if you choose).
agent_run() {
	# shellcheck disable=SC2086 # the tier's args are the developer's words, split on purpose
	"$1" -C "$ROOT" -m "$2" --json $5 -p "$(cat "$3")" >"$4"
}

# agent_exit_note <rc>: narrow exits 3 when it could not verify its own work (FR-28.3). That is
# not a failed run: sdd's task tests and check decide. Any other code is a failure.
agent_exit_note() {
	[ "$1" -eq 3 ] || return 1
	echo "⚠ narrow could not verify its own work (exit 3); sdd's task tests and check decide"
}

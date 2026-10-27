# FR-16.1 a role's tier, agent and model (yours first), FR-16.4 sdd run gives the agent the
# item's next step once, headless, with only the tier's args, FR-16.5 one log line per run,
# FR-16.8 failures are logged too.
. "$SRC/tests/lib.sh"
new_repo

# Stub agents: record their arguments and prompt, print a final JSON line like the real ones.
mkdir -p "$T/bin"
cat >"$T/bin/claude" <<'EOF'
#!/bin/sh
echo "$*" >"$STUB/claude.args"; cat >"$STUB/claude.prompt"
echo '{"type":"result","subtype":"success","is_error":false,"total_cost_usd":0.25,"usage":{"input_tokens":1200,"cache_read_input_tokens":800,"output_tokens":300}}'
exit "${CLAUDE_RC:-0}"
EOF
cat >"$T/bin/narrow" <<'EOF'
#!/bin/sh
echo "$*" >"$STUB/narrow.args"
while [ $# -gt 0 ]; do [ "$1" = -p ] && printf '%s\n' "$2" >"$STUB/narrow.prompt"; shift; done
echo '{"type":"start"}'
echo '{"type":"finish","exit":0,"verdict":"passed","tokens":{"in":41000,"out":3000}}'
EOF
chmod +x "$T/bin/claude" "$T/bin/narrow"
mkdir -p "$T/stub"
PATH="$T/bin:$PATH" STUB="$T/stub"
export PATH STUB

planned_item feature "Paging"
awk '$0 == "## Built" { print "- [ ] T-1.1 Page the query (test: true)"; print "" } { print }' "$ITEM" >"$T/i" && cp "$T/i" "$ITEM"
git commit -qam "docs(1): a task" && sdd approve >/dev/null 2>&1

# FR-16.1: missing settings name the exact lines to add.
out=$(sdd run builder 1 2>&1)
assert_eq $? 2 "(no role)"
assert_contains "$out" '[role "builder"]'
setcfg role.builder.tier small
out=$(sdd run builder 1 2>&1)
assert_eq $? 2 "(no tier)"
assert_contains "$out" '[tier "small"]'

# The project says small = claude; the developer's own config says narrow, and wins.
setcfg tier.small.agent claude && setcfg tier.small.model sonnet
mkdir -p "$XDG_CONFIG_HOME/sdd"
git config -f "$XDG_CONFIG_HOME/sdd/config" tier.small.agent narrow
git config -f "$XDG_CONFIG_HOME/sdd/config" tier.small.model qwen3-coder-30b
git config -f "$XDG_CONFIG_HOME/sdd/config" tier.small.args '--profile local'
# The project's args for its claude tier never reach the developer's narrow mapping (D-16.1).
setcfg tier.small.args '--permission-mode acceptEdits'

# FR-16.4, FR-16.5: one headless run with the item's next step; one log line.
out=$(sdd run builder 1 2>&1) || fail "run failed: $out"
assert_contains "$(cat "$T/stub/narrow.args")" '-m qwen3-coder-30b --json --profile local -p'
assert_contains "$(cat "$T/stub/narrow.prompt")" 'Current task: T-1.1 Page the query'
assert_not_contains "$(cat "$T/stub/narrow.args")" 'yolo'
assert_not_contains "$(cat "$T/stub/narrow.args")" 'acceptEdits'
assert_contains "$out" 'run 1 · builder · narrow qwen3-coder-30b · item 1 T-1.1 · 41k in / 3k out · '
assert_contains "$out" 'exit 0 · passed'
log=$(git rev-parse --git-common-dir)/sdd/runs.tsv
assert_eq "$(tail -n 1 "$log" | cut -f3-11,13,14)" "$(printf '1\tbuilder\tnarrow\tqwen3-coder-30b\tbuild\tT-1.1\t41000\t3000\t\t0\tpassed')"

# A planner on claude: the prompt on stdin, cost as claude reports it, the role's own prompt added.
setcfg role.planner.tier big && setcfg tier.big.agent claude && setcfg tier.big.model opus
mkdir -p .sdd/local/prompts && echo "You are the planner for item {{id}}." >.sdd/local/prompts/role-planner.md
out=$(sdd run planner 1 2>&1) || fail "planner run failed: $out"
assert_contains "$(cat "$T/stub/claude.args")" '-p --output-format json --model opus'
assert_contains "$(cat "$T/stub/claude.prompt")" 'You are the planner for item 1.'
assert_contains "$out" '2k in / 300 out · $0.25'

# FR-16.8: a failing agent is logged with its exit code; sdd says so and exits 1.
out=$(CLAUDE_RC=3 sdd run planner 1 2>&1)
assert_eq $? 1 "(agent failed)"
assert_contains "$out" 'the agent exited 3'
assert_eq "$(tail -n 1 "$log" | cut -f1,13)" "$(printf '3\t3')"

# A model name that would not be safe in a file or YAML is refused.
git config -f "$XDG_CONFIG_HOME/sdd/config" tier.small.model "$(printf 'qwen\npermissionMode: x')"
assert_contains "$(sdd run builder 1 2>&1)" 'model a name without spaces or quotes'
git config -f "$XDG_CONFIG_HOME/sdd/config" tier.small.model qwen3-coder-30b

# No role runs while the item waits for the human (here: a plan not approved yet).
git switch -q main && sdd new feature "Waiting" >/dev/null 2>&1
fill specs/changes/2-waiting/item.md plan && git commit -qam "docs(2): plan" && setcfg role.builder.tier small
out=$(sdd run builder 2 2>&1)
assert_eq $? 2 "(human's turn)"
assert_contains "$out" 'is waiting for the human'
git switch -q feature/1-paging

# Only on the item's own branch.
git switch -q main
assert_contains "$(sdd run builder 1 2>&1)" 'item 1 is not checked out here'
exit 0

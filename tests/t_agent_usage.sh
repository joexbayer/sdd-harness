# FR-16.5 reading tokens, cost and verdict from each agent's output: claude -p's result line,
# a Claude Code subagent transcript (each message once), and narrowbot's finish event.
. "$SRC/tests/lib.sh"
# use <agent> <function> <args>: call an adapter function, as sdd itself loads it.
# shellcheck disable=SC1090,SC2034 # the adapter is chosen per call; SDD_HOME is read by common.sh
use() { (SDD_HOME="$SRC/.sdd" && . "$SRC/.sdd/core/lib/common.sh" && . "$SRC/.sdd/core/agents/$1.sh" && shift && "$@"); }
tab=$(printf '\t')

# claude -p --output-format json: input counts cached input too; cost and verdict as reported.
printf '%s\n' '{"type":"result","subtype":"success","is_error":false,"duration_ms":9100,"num_turns":4,"result":"done","total_cost_usd":0.0412,"usage":{"input_tokens":12,"cache_creation_input_tokens":300,"cache_read_input_tokens":4000,"output_tokens":56},"modelUsage":{"claude-opus-5-5":{"inputTokens":12}}}' >"$T/claude.json"
assert_eq "$(use claude agent_usage "$T/claude.json")" "4312${tab}56${tab}0.0412${tab}ok"
printf '%s\n' '{"type":"result","subtype":"error_max_turns","is_error":true,"total_cost_usd":0.5,"usage":{"input_tokens":1,"output_tokens":2}}' >"$T/claude-err.json"
assert_eq "$(use claude agent_usage "$T/claude-err.json")" "1${tab}2${tab}0.5${tab}error_max_turns"
# The real result line of claude -p (Claude Code, 2026-10-27; ids redacted): usage.iterations[]
# repeats the token keys, so the first match (the total) must win.
assert_eq "$(use claude agent_usage "$SRC/tests/data/claude-p-result.json")" "106709${tab}1746${tab}0.006877399999999999${tab}ok"
: >"$T/empty"
assert_eq "$(use claude agent_usage "$T/empty")" "${tab}${tab}${tab}no result"

# A subagent transcript: message m1 appears twice (parallel tool calls), counted once with its
# final output count; lines without usage are skipped.
cat >"$T/agent.jsonl" <<'EOF'
{"type":"user","message":{"role":"user","content":"plan item 4"}}
{"type":"assistant","message":{"id":"m1","model":"claude-opus-5-5","usage":{"input_tokens":100,"cache_read_input_tokens":900,"output_tokens":1}}}
{"type":"assistant","message":{"id":"m1","model":"claude-opus-5-5","usage":{"input_tokens":100,"cache_read_input_tokens":900,"output_tokens":40}}}
{"type":"assistant","message":{"id":"m2","model":"claude-opus-5-5","usage":{"input_tokens":10,"cache_creation_input_tokens":5,"output_tokens":7}}}
EOF
assert_eq "$(use claude agent_transcript_usage "$T/agent.jsonl")" "1015${tab}47${tab}claude-opus-5-5"

# narrowbot --json: the finish event (cost only when priced).
printf '%s\n' '{"type":"start","model":"qwen3-coder-30b"}' '{"type":"finish","exit":0,"verdict":"passed","result":"Done.","end_reason":"","tokens":{"in":812,"out":40},"time":"t"}' >"$T/narrowbot.jsonl"
assert_eq "$(use narrowbot agent_usage "$T/narrowbot.jsonl")" "812${tab}40${tab}${tab}passed"
printf '%s\n' '{"type":"finish","exit":1,"verdict":"failing","tokens":{"in":5,"out":6},"cost":0.002}' >"$T/narrow2.jsonl"
assert_eq "$(use narrowbot agent_usage "$T/narrow2.jsonl")" "5${tab}6${tab}0.002${tab}failing"
exit 0

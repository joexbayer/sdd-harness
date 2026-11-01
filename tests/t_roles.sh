# FR-16.2 sync claude writes a subagent per Claude-model role and the sdd-run skill, FR-16.3 the
# skill hands a role to its subagent or to sdd run, FR-16.6 subagent runs are logged from the
# SubagentStart/Stop hooks with tokens from the transcript.
. "$SRC/tests/lib.sh"
new_repo
setcfg usage.track true   # off by default (FR-16.5); t_usage_off.sh covers that
sdd new feature "Roles" >/dev/null 2>&1

# Roles: planner on a Claude tier (project), builder on a tier the developer maps to narrowbot.
setcfg role.planner.tier big && setcfg tier.big.agent claude && setcfg tier.big.model opus
setcfg role.builder.tier small && setcfg tier.small.agent claude && setcfg tier.small.model haiku
mkdir -p "$XDG_CONFIG_HOME/sdd"
git config -f "$XDG_CONFIG_HOME/sdd/config" tier.small.agent narrowbot
git config -f "$XDG_CONFIG_HOME/sdd/config" tier.small.model qwen3-coder-30b
mkdir -p .claude/agents && printf -- '---\nname: sdd-reviewer\n---\nMine.\n' >.claude/agents/sdd-reviewer.md
mkdir -p .sdd/local/prompts && echo "Plan {{id}} carefully." >.sdd/local/prompts/role-planner.md
setcfg role.odd.tier weird && setcfg tier.weird.agent claude
git config -f .sdd/config tier.weird.model "$(printf 'opus\npermissionMode: bypassPermissions')" && git commit -qam "test: odd tier"

out=$(sdd sync claude 2>&1) || fail "sync failed: $out"
# FR-16.2: a subagent for the Claude role only, with its tier's model; the developer's own file stays.
a=.claude/agents/sdd-planner.md
assert_file "$a"
assert_eq "$(sed -n 2p "$a")" 'name: sdd-planner'
grep -qx 'model: opus' "$a" || fail "planner subagent has no model: opus"
assert_contains "$(cat "$a")" 'Run `.sdd/bin/sdd next`, do exactly the step it gives you'
assert_no_file .claude/agents/sdd-builder.md
assert_contains "$(cat "$a")" 'Plan the given item carefully.'
assert_no_file .claude/agents/sdd-odd.md
assert_contains "$out" 'skipped role odd: tier weird needs a model name'
assert_eq "$(sed -n 4p .claude/agents/sdd-reviewer.md)" 'Mine.'
grep -qx '/.claude/agents/sdd-planner.md' "$(git rev-parse --git-common-dir)/info/exclude" || fail "subagent not excluded"
s=.claude/settings.local.json
assert_eq "$(jq -r '.hooks.SubagentStop[0].matcher' "$s")" 'sdd-.*'
assert_contains "$(jq -r '.hooks.SubagentStart[0].hooks[0].command' "$s")" 'hook subagent-start --agent claude'
# FR-16.3: the sdd-run skill: subagent when there is one, sdd run otherwise.
k=.claude/skills/sdd-run/SKILL.md
assert_file "$k"
assert_contains "$(cat "$k")" 'hand the step to it'
assert_contains "$(cat "$k")" 'run `.sdd/bin/sdd run <role> <id>`'
# A role moved off Claude loses its subagent at the next sync; a second sync adds no duplicate hooks.
git config -f "$XDG_CONFIG_HOME/sdd/config" tier.big.agent narrowbot
git config -f "$XDG_CONFIG_HOME/sdd/config" tier.big.model m
sdd sync claude >/dev/null 2>&1
assert_no_file "$a"
assert_eq "$(jq '.hooks.SubagentStop | length' "$s")" 1
git config -f "$XDG_CONFIG_HOME/sdd/config" --unset tier.big.agent
git config -f "$XDG_CONFIG_HOME/sdd/config" --unset tier.big.model

# FR-16.6: a role subagent's start and stop log one run, tokens from its transcript.
cat >"$T/agent.jsonl" <<'EOF'
{"type":"assistant","message":{"id":"m1","model":"claude-opus-5-5","usage":{"input_tokens":100,"cache_read_input_tokens":900,"output_tokens":40}}}
{"type":"assistant","message":{"id":"m2","model":"claude-opus-5-5","usage":{"input_tokens":10,"output_tokens":7}}}
EOF
hook() { printf '%s' "$2" | sdd hook "$1" --agent claude; }
hook subagent-start "{\"cwd\":\"$R\",\"agent_id\":\"a1\",\"agent_type\":\"sdd-planner\"}"
hook subagent-stop "{\"cwd\":\"$R\",\"agent_id\":\"a1\",\"agent_type\":\"sdd-planner\",\"agent_transcript_path\":\"$T/agent.jsonl\"}"
log=$(git rev-parse --git-common-dir)/sdd/runs.tsv
assert_eq "$(tail -n 1 "$log" | cut -f3-10,13,14)" "$(printf '1\tplanner\tclaude\tclaude-opus-5-5\tplan\t\t1010\t47\t0\tdone')"
# Other subagents are not sdd's to log.
hook subagent-start "{\"cwd\":\"$R\",\"agent_id\":\"a2\",\"agent_type\":\"Explore\"}"
hook subagent-stop "{\"cwd\":\"$R\",\"agent_id\":\"a2\",\"agent_type\":\"Explore\",\"agent_transcript_path\":\"$T/agent.jsonl\"}"
assert_eq "$(grep -vc '^#' "$log")" 1
# NarrowBot has no reply format of its own: its stop hook still blocks the plain way (exit 2).
echo code >code.txt
sdd hook stop --agent narrowbot </dev/null >/dev/null 2>&1
assert_eq $? 2 "(narrowbot stop hook)"
exit 0

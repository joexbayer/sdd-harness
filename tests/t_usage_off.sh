# FR-16.5, FR-16.6, FR-16.7: usage tracking is off by default: runs still run but nothing is
# logged, sync installs no subagent hooks, and sdd usage says how to switch it on.
. "$SRC/tests/lib.sh"
new_repo
mkdir -p "$T/bin"
printf '#!/bin/sh\ncat >/dev/null\necho %s\n' "'{\"type\":\"result\",\"is_error\":false,\"usage\":{\"input_tokens\":5,\"output_tokens\":6}}'" >"$T/bin/claude"
chmod +x "$T/bin/claude"
PATH="$T/bin:$PATH" && export PATH
planned_item feature "Quiet"
setcfg role.planner.tier big && setcfg tier.big.agent claude && setcfg tier.big.model haiku
log=$(git rev-parse --git-common-dir)/sdd/runs.tsv

# FR-16.5: the run happens and is summed up on screen, but nothing is kept.
out=$(sdd run planner 1 2>&1) || fail "run failed: $out"
assert_contains "$out" '5 in / 6 out'
assert_no_file "$log"
assert_no_file "$(git rev-parse --git-common-dir)/sdd/runs/1"
# FR-16.7: usage says it is off and how to switch it on.
out=$(sdd usage)
assert_contains "$out" 'usage tracking is off'
assert_contains "$out" '[usage] track = true'
# FR-16.6: no subagent hooks while off; the subagent hook logs nothing either.
sdd sync claude >/dev/null 2>&1 || fail "sync failed"
assert_eq "$(jq '.hooks.SubagentStop // [] | length' .claude/settings.local.json)" 0
printf '%s' "{\"cwd\":\"$R\",\"agent_id\":\"a1\",\"agent_type\":\"sdd-planner\"}" | sdd hook subagent-start --agent claude
assert_no_file "$(git rev-parse --git-common-dir)/sdd/runs/sub.a1"
# Switched on (here: in the developer's own config), it logs and the hooks appear.
mkdir -p "$XDG_CONFIG_HOME/sdd" && git config -f "$XDG_CONFIG_HOME/sdd/config" usage.track true
sdd run planner 1 >/dev/null 2>&1 || fail "run with tracking failed"
assert_eq "$(grep -vc '^#' "$log")" 1
sdd sync claude >/dev/null 2>&1
assert_eq "$(jq '.hooks.SubagentStop | length' .claude/settings.local.json)" 1
# Switched off again, sync takes sdd's subagent hooks away.
git config -f "$XDG_CONFIG_HOME/sdd/config" usage.track false
sdd sync claude >/dev/null 2>&1
assert_eq "$(jq '.hooks.SubagentStop // [] | length' .claude/settings.local.json)" 0
exit 0

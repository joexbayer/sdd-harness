# FR-1.10 sync claude/codex: hooks merged, existing settings kept, idempotent, excluded.
# FR-1.11 stop hook: warn in lite, block once in standard. FR-1.12 name derived.
# FR-4.1 step skills, FR-4.2 descriptions trigger on plain requests, FR-4.3 ask rules for
# approve and ship, FR-4.4 only sdd's own skills and rules are replaced.
. "$SRC/tests/lib.sh"
new_repo

mkdir -p .claude
printf '{"permissions":{"allow":["Bash(ls:*)"],"ask":["Bash(rm:*)"]}}\n' >.claude/settings.local.json
sdd sync claude >/dev/null 2>&1 || fail "sync claude failed"
sdd sync claude >/dev/null 2>&1 || fail "second sync claude failed"
s=.claude/settings.local.json
assert_eq "$(jq -r '.permissions.allow[0]' "$s")" 'Bash(ls:*)'
assert_eq "$(jq '.hooks.SessionStart | length' "$s")" 1
assert_eq "$(jq '.hooks.Stop | length' "$s")" 1
assert_contains "$(jq -r '.hooks.Stop[0].hooks[0].command' "$s")" '.sdd/bin/sdd" hook stop --agent claude'
assert_eq "$(cat CLAUDE.md)" '@AGENTS.md'
ex=$(git rev-parse --git-path info/exclude)
grep -qx '/.claude/settings.local.json' "$ex" || fail "settings not excluded"
grep -qx '/CLAUDE.md' "$ex" || fail "CLAUDE.md not excluded"
[ -z "$(git status --porcelain)" ] || fail "sync must not leave anything to commit: $(git status --porcelain)"

# Step skills: one per step, named after the tool, kept out of git; tool hints per agent.
for st in new plan build review ship; do
	assert_file ".claude/skills/sdd-$st/SKILL.md"
	assert_contains "$(sed -n 2p ".claude/skills/sdd-$st/SKILL.md")" "name: sdd-$st"
	grep -q '^description: .*Use when' ".claude/skills/sdd-$st/SKILL.md" || fail "sdd-$st: no trigger in description"
	grep -qx "/.claude/skills/sdd-$st" "$ex" || fail "sdd-$st not excluded"
done
assert_contains "$(sed -n 3p .claude/skills/sdd-new/SKILL.md)" "let's build X"
# /sdd-new <request>: the skill picks the type and a title and confirms them before `new`.
assert_contains "$(cat .claude/skills/sdd-new/SKILL.md)" 'Start it?'
assert_contains "$(sed -n 3p .claude/skills/sdd-new/SKILL.md)" 'types /sdd-new followed by what they want'
assert_contains "$(sed -n 3p .claude/skills/sdd-new/SKILL.md)" 'fix this bug'
assert_contains "$(sed -n 3p .claude/skills/sdd-review/SKILL.md)" 'wants to review it'
# Strict YAML: no ": " inside a description's plain value.
for st in new plan build review ship; do
	sed -n 3p ".claude/skills/sdd-$st/SKILL.md" | cut -c14- | grep -q ': ' && fail "sdd-$st: ': ' in description"
done
assert_contains "$(cat .claude/skills/sdd-new/SKILL.md)" 'sdd-plan skill now'
assert_contains "$(cat .claude/skills/sdd-plan/SKILL.md)" 'AskUserQuestion'
assert_contains "$(cat .claude/skills/sdd-plan/SKILL.md)" 'Run `.sdd/bin/sdd next`'

# Ask rules: the human confirms approve, ship and (FR-7.10) tidy --remote, however the call is
# spelled; no duplicates.
assert_eq "$(jq '[.permissions.ask[] | select(test("sdd (approve|ship|tidy --remote)"))] | length' "$s")" 18
asks=$(jq -r '.permissions.ask | join(" ")' "$s")
assert_contains "$asks" 'Bash(.sdd/bin/sdd approve:*)'
assert_contains "$asks" 'Bash(bash .sdd/bin/sdd ship:*)'
assert_contains "$asks" "Bash($(git rev-parse --show-toplevel)/.sdd/bin/sdd approve:*)"
assert_contains "$asks" 'Bash(sdd ship:*)'
assert_contains "$asks" 'Bash(.sdd/bin/sdd tidy --remote:*)'
assert_contains "$asks" 'Bash(sh .sdd/bin/sdd tidy --remote:*)'
assert_contains "$asks" 'Bash(rm:*)'

# Re-sync replaces only sdd's own skills: an edited managed skill comes back, the user's stays.
echo edited >>.claude/skills/sdd-review/SKILL.md
printf -- '---\nname: sdd-build\ndescription: mine\n---\nMy own build skill.\n' >.claude/skills/sdd-build/SKILL.md
out=$(sdd sync claude 2>&1)
assert_contains "$out" 'left .claude/skills/sdd-build/SKILL.md alone'
assert_not_contains "$(cat .claude/skills/sdd-review/SKILL.md)" 'edited'
assert_eq "$(sed -n 5p .claude/skills/sdd-build/SKILL.md)" 'My own build skill.'
assert_eq "$(jq '.permissions.ask | length' "$s")" 19

sdd sync codex >/dev/null 2>&1 || fail "sync codex failed"
assert_eq "$(jq '.hooks.Stop | length' .codex/hooks.json)" 1
assert_file .agents/skills/sdd-plan/SKILL.md
grep -qx '/.agents/skills/sdd-plan' "$ex" || fail "codex skills not excluded"
assert_not_contains "$(cat .agents/skills/sdd-plan/SKILL.md)" 'AskUserQuestion'

# Run the generated hook command exactly as the agent would, from inside the repo.
stop_cmd=$(jq -r '.hooks.Stop[0].hooks[0].command' "$s")
start_cmd=$(jq -r '.hooks.SessionStart[0].hooks[0].command' "$s")
hook() { printf '{"cwd":"%s","stop_hook_active":%s}' "$PWD" "${2:-false}" | sh -c "$1"; }

out=$(hook "$start_cmd")
assert_contains "$out" 'no open items'
assert_contains "$out" '.sdd/bin/sdd next'

sdd new fix "Hooked" >/dev/null 2>&1
f=specs/changes/1-hooked/item.md
out=$(hook "$stop_cmd")
assert_eq "$out" '' "(planning talk with no code changes never trips the gate)"

# FR-60.1: code while the plan waits for the human: warned, never blocked (the next step is theirs).
echo code >code.txt
out=$(hook "$stop_cmd")
assert_eq "$(printf '%s' "$out" | jq -r .decision)" null
assert_contains "$(printf '%s' "$out" | jq -r .systemMessage)" "The next step is the human's"

# Building: blocked until the check passes and "## Built" is written.
fill "$f" plan
sdd approve >/dev/null 2>&1 || fail "approve failed"
out=$(hook "$stop_cmd")
assert_contains "$(printf '%s' "$out" | jq -r .reason)" 'no passing check'
sdd check >/dev/null 2>&1 || fail "check failed"
out=$(hook "$stop_cmd")
assert_contains "$(printf '%s' "$out" | jq -r .reason)" '"## Built" is not written yet'
fill "$f" built
out=$(hook "$stop_cmd")
assert_eq "$out" '' "(verified and written up: stop is fine)"

# Codex gets the same replies; a profile can soften the gate to a warning.
codex_stop=$(jq -r '.hooks.Stop[0].hooks[0].command' .codex/hooks.json)
echo more >>code.txt
assert_eq "$(hook "$codex_stop" | jq -r .decision)" block
git config -f .sdd/config profile.lite.finish warn
assert_contains "$(hook "$codex_stop" | jq -r .systemMessage)" 'is not finished'
git config -f .sdd/config profile.lite.finish block

# An existing CLAUDE.md keeps its content and gains the import once.
printf '# Team notes\n' >CLAUDE.md
sdd sync claude >/dev/null 2>&1
sdd sync claude >/dev/null 2>&1
assert_eq "$(cat CLAUDE.md)" "$(printf '# Team notes\n\n@AGENTS.md')"

# New worktrees get the glue of every synced agent.
git switch -q main 2>/dev/null || { git stash -q -u && git switch -q main; }
sdd new chore "Other" --worktree >/dev/null 2>&1 || fail "new --worktree failed"
assert_file "$T/app.2/.claude/settings.local.json"
assert_file "$T/app.2/.codex/hooks.json"

# A renamed install folder still works: paths derive from where it lives.
mkdir -p "$T/renamed" && cd "$T/renamed" || exit 1
git init -q && echo x >x && git add x && git commit -qm init
cp -R "$SRC/.sdd" .tool
out=$(SDD_SH=$SH "$SH" .tool/bin/sdd init 2>&1) || fail "init via renamed folder failed: $out"
assert_contains "$(cat AGENTS.md)" '.tool/bin/sdd next'
exit 0

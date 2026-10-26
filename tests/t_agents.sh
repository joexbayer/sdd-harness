# FR-1.10 sync claude/codex: hooks merged, existing settings kept, idempotent, excluded.
# FR-1.11 stop hook: warn in lite, block once in standard. FR-1.12 name derived.
. "$SRC/tests/lib.sh"
new_repo

mkdir -p .claude
printf '{"permissions":{"allow":["Bash(ls:*)"]}}\n' >.claude/settings.local.json
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

sdd sync codex >/dev/null 2>&1 || fail "sync codex failed"
assert_eq "$(jq '.hooks.Stop | length' .codex/hooks.json)" 1

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

# Code before the plan is approved: blocked once, then allowed with "unverified:".
echo code >code.txt
out=$(hook "$stop_cmd")
assert_eq "$(printf '%s' "$out" | jq -r .decision)" block
assert_contains "$(printf '%s' "$out" | jq -r .reason)" 'the plan is not ready'
out=$(hook "$stop_cmd" true)
assert_contains "$(printf '%s' "$out" | jq -r .systemMessage)" 'unverified:'

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

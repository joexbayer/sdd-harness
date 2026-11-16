# FR-17.4 the build loop: the sdd-build skill has the main agent take `sdd task next`, give each
# batch to one builder (subagent or sdd run builder), see every task done and committed, stop at
# the first failure, then the check and Built. The loop is the skill's text; the commands it
# names are played here by a script, with a stub builder, to show they make that loop.
. "$SRC/tests/lib.sh"
new_repo
use_narrowbot

# FR-17.4: the skill text, for every agent; the Claude hint names the builder subagent.
setcfg role.builder.tier small && setcfg tier.small.agent claude && setcfg tier.small.model haiku
sdd sync claude >/dev/null 2>&1 || fail "sync claude failed"
sdd sync codex >/dev/null 2>&1 || fail "sync codex failed"
k=.claude/skills/sdd-build/SKILL.md
assert_contains "$(sed -n 3p "$k")" "now let's build"
assert_contains "$(cat "$k")" 'Run `.sdd/bin/sdd task next`'
assert_contains "$(cat "$k")" 'the `sdd-builder` subagent if this agent has one'
assert_contains "$(cat "$k")" '`.sdd/bin/sdd run builder <id>`'
assert_contains "$(cat "$k")" 'run `.sdd/bin/sdd task done <T-id>` yourself'
assert_contains "$(cat "$k")" 'every task ID of the batch in the subject'
assert_contains "$(cat "$k")" 'When a builder reports a failure'
# FR-69.5: one stopping rule, the three cases.
assert_contains "$(cat "$k")" "stop only for a task's test that proves wrong, a box that cannot be ticked, or a
refactor that must change a test"
assert_not_contains "$(cat "$k")" 'do not stop to ask'
# FR-69.6 no tasks ends the loop; FR-69.9 a `by:` batch goes to that role.
assert_contains "$(cat "$k")" '"no open tasks" or "has no tasks" ends the loop'
assert_contains "$(cat "$k")" 'A batch marked `by: <role>` goes to that'
assert_contains "$(cat "$k")" 'before the next batch. Stop only in the three cases below.'
assert_contains "$(cat "$k")" 'until `.sdd/bin/sdd check` passes and "## Built" is written'
assert_contains "$(cat "$k")" 'subagent type `sdd-builder`, one call per batch'
assert_file .claude/agents/sdd-builder.md
assert_contains "$(cat .agents/skills/sdd-build/SKILL.md)" 'Run `.sdd/bin/sdd task next`'
assert_not_contains "$(cat .agents/skills/sdd-build/SKILL.md)" 'In Claude Code'

# The loop, played: S, S, L tasks; a stub builder (sdd run builder on narrowbot) does what next
# tells it: task done for each task of its batch, then one commit naming them.
mkdir -p "$T/bin"
cat >"$T/bin/narrowbot" <<'EOF'
#!/bin/sh
while [ $# -gt 0 ]; do [ "$1" = -p ] && p=$2; shift; done
ids=$(printf '%s\n' "$p" | sed -n 's/^Current batch: \([^(]*[^ (]\) (.*/\1/p; s/^Current task: \(T-[0-9.]*\) .*/\1/p')
echo "$ids" >>"$STUB_LOG"
for t in $ids; do "$SH" "$SRC/.sdd/bin/sdd" task done "$t" >/dev/null 2>&1 || { echo '{"type":"finish","exit":1}'; exit 1; }; done
git add -A && git commit -qm "feat(1): $ids work"
echo '{"type":"finish","exit":0,"verdict":"passed","tokens":{"in":10,"out":1}}'
EOF
chmod +x "$T/bin/narrowbot"
setcfg tier.small.agent narrowbot && setcfg tier.small.model m
sdd new feature "Loop" >/dev/null 2>&1
f=specs/changes/1-loop/item.md
fill "$f" plan
awk '/^## What changes$/ { print; print "FR-1.1 WHEN x THE SYSTEM SHALL y."; next }
/^## Tasks \(optional\)$/ { print
	print "- [ ] T-1.1 One, FR-1.1 (test: true; size: S)"
	print "- [ ] T-1.2 Two, FR-1.1 (test: true; size: S)"
	print "- [ ] T-1.3 Three, FR-1.1 (test: test -f ok.txt; size: L)"
	print ""; next } { print }' "$f" >"$T/f" && cp "$T/f" "$f"
git commit -qam "docs(1): plan" && sdd approve >/dev/null 2>&1 || fail "approve failed"
STUB_LOG="$T/batches"
export STUB_LOG

# build: what the skill says, as a script; stops at the first failure.
build() {
	while :; do
		b=$(sdd task next)
		case $b in "no open tasks"*) return 0 ;; esac
		(export PATH="$T/bin:$PATH"; sdd run builder 1 >/dev/null 2>&1) || return 1
		ids=${b%%"
"*}
		for t in ${ids#batch   }; do
			sdd task | grep -q "^\[x\] $t " || return 1
			[ -n "$(git log --format=%s -1 --grep="$t" main..HEAD)" ] || return 1
		done
	done
}
# FR-17.4: the first failure stops the loop: T-1.3's test fails, so batch 1 is done and kept,
# and nothing after it runs.
build
assert_eq $? 1 "(a failing task stops the loop)"
assert_eq "$(cat "$STUB_LOG")" "$(printf 'T-1.1 T-1.2\nT-1.3')"
grep -q '^- \[x\] T-1.2 ' "$f" || fail "batch 1 not ticked"
grep -q '^- \[ \] T-1.3 ' "$f" || fail "T-1.3 ticked though its test failed"
# FR-17.4: fixed, the loop goes on from where it stopped: one builder per batch, all ticked and
# committed, then the item moves on to the check and Built.
echo ok >ok.txt && git add ok.txt && git commit -qm "test: ok"
: >"$STUB_LOG"
build || fail "loop failed"
assert_eq "$(cat "$STUB_LOG")" 'T-1.3'
assert_contains "$(git log --format=%s main..HEAD)" 'feat(1): T-1.1 T-1.2 work'
assert_contains "$(sdd task next)" 'no open tasks'
assert_not_contains "$(sdd status)" 'task T-'

# FR-69.4: a stop in the plan phase of a type with no approval gate names the section to fill in.
git switch -q main
sdd new hotfix "Broken" >/dev/null 2>&1 || fail "new hotfix failed"
echo code >code.txt
cmd=$(jq -r '.hooks.Stop[0].hooks[0].command' .claude/settings.local.json)
out=$(printf '{"cwd":"%s","stop_hook_active":false}' "$PWD" | sh -c "$cmd")
assert_contains "$(printf '%s' "$out" | jq -r '.systemMessage // .reason')" 'item 2: write "What is broken" in the item, then go on (.sdd/bin/sdd next)'
assert_not_contains "$out" 'stop and ask'
exit 0

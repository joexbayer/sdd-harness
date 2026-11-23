# FR-22.2 the finish steps hand the item to the verifier role (subagent, sdd run, or a fresh
# subagent), whose prompt says what a verifier does; FR-22.3 the verified gate at ship (warn in
# lite and standard, block in strict) and the "Verified by:" line in review.
# FR-62.1, FR-62.2 next says verified only when it was; FR-62.3 lite warns at ship.
. "$SRC/tests/lib.sh"
new_repo

# A stub claude for sdd run: records the prompt it is given.
mkdir -p "$T/bin" "$T/stub"
cat >"$T/bin/claude" <<'EOF'
#!/bin/sh
cat >"$STUB/claude.prompt"
echo '{"type":"result","subtype":"success","is_error":false,"usage":{"input_tokens":1,"output_tokens":1}}'
EOF
chmod +x "$T/bin/claude"
PATH="$T/bin:$PATH" STUB="$T/stub"
export PATH STUB

# built_with <line>: "## Built" written, with <line> in it (empty: no Verified by line).
built_with() {
	L=$1 awk '$0 == "## Built" { print; print "Filled in by the test (built)."; if (ENVIRON["L"] != "") print ENVIRON["L"]; skip = 1; next }
		/^## Review/ { skip = 0 } skip && /Filled in by the test|Verified by:/ { next } { print }' "$ITEM" >"$T/i" && cp "$T/i" "$ITEM"
	git commit -qam "docs: built"
}

planned_item fix "Retry" tasks
done_tasks
# FR-22.2: once no task is open, the finish steps hand the item to the verifier.
out=$(sdd next)
assert_contains "$out" 'hand item 1 to the `verifier` role: its `sdd-verifier` subagent if this agent has'
assert_contains "$out" 'else `.sdd/bin/sdd run verifier 1` if the project sets the role, else a fresh subagent on a'
assert_contains "$out" 'different model than yours'
assert_contains "$out" 'reports only findings, each with the command and its output, and never edits code or the plan'
assert_contains "$out" '  Verified by: <its model>: <n> of <m> FRs proven; <its findings in a few words, or "no findings">'
assert_contains "$out" 'or, when no verifier could run, `Verified by: none` and why (ship refuses it where the `verified` gate blocks).'

# FR-22.2: a verifier role on a Claude model gets its subagent, with what a verifier does.
setcfg role.verifier.tier big && setcfg tier.big.agent claude && setcfg tier.big.model opus
out=$(sdd sync claude 2>&1) || fail "sync failed: $out"
a=.claude/agents/sdd-verifier.md
assert_file "$a"
grep -qx 'model: opus' "$a" || fail "verifier subagent has no model: opus"
assert_contains "$(cat "$a")" 'You are the verifier for this item: you check the build against its requirements'
assert_contains "$(cat "$a")" 'Never edit code, tests or the item file, and never commit.'
assert_contains "$(cat "$a")" 'Verified by: <your model>: <n> of <m> FRs proven;'
# FR-22.2: sdd run verifier gives the agent the same role prompt after the item's step.
out=$(sdd run verifier 1 2>&1) || fail "run verifier failed: $out"
p=$(cat "$STUB/claude.prompt")
assert_contains "$p" 'Phase: build'
assert_contains "$p" 'do not hand the item to another verifier'
assert_contains "$p" 'Prove each one by running something'

# FR-22.3: review shows the line, or that it is missing.
echo retry >retry.txt && git add retry.txt && git commit -qm "fix(1): retry"
sdd check >/dev/null 2>&1 || fail "check failed"
built_with ''
assert_contains "$(sdd review)" 'Verified by: (missing)'
assert_contains "$(sdd review)" 'check   '
# FR-22.3: strict blocks a missing line and "none", naming the gate.
setcfg sdd.profile strict
out=$(sdd ship 2>&1)
assert_eq $? 1 "(strict, no Verified by)"
assert_contains "$out" 'not verified (gate verified)'
built_with '- Verified by: none (no second model here)'
assert_contains "$(sdd review)" 'verify  Verified by: none (no second model here)'
out=$(sdd ship 2>&1)
assert_eq $? 1 "(strict, Verified by: none)"
assert_contains "$out" 'not verified (gate verified)'
# FR-22.3: a real verifier line passes, in strict too.
built_with 'Verified by: claude-opus-5-5: 1 of 1 FRs proven; no findings'
assert_contains "$(sdd review)" 'verify  Verified by: claude-opus-5-5: 1 of 1 FRs proven; no findings'
out=$(sdd ship 2>&1) || fail "strict ship with a verifier line failed: $out"
assert_not_contains "$out" 'not verified'

# FR-22.3: standard warns and ships; lite too (FR-62.3).
setcfg sdd.profile standard
planned_item fix "Backoff" tasks
done_tasks
echo backoff >backoff.txt && git add backoff.txt && git commit -qm "fix(2): backoff"
built_with ''
sdd review >/dev/null
out=$(sdd ship 2>&1) || fail "standard ship without a verifier failed: $out"
assert_contains "$out" 'not verified (gate verified)'
assert_contains "$out" 'shipped 2'
setcfg sdd.profile lite
planned_item fix "Jitter" tasks
done_tasks
echo jitter >jitter.txt && git add jitter.txt && git commit -qm "fix(3): jitter"
built_with ''
out=$(sdd ship 2>&1) || fail "lite ship failed: $out"
assert_contains "$out" 'not verified (gate verified)'

# FR-22.2: the finish gate holds the builder, not a verifier run (sdd run exports its role).
planned_item fix "Cap" tasks
done_tasks
echo cap >cap.txt && git add cap.txt && git commit -qm "fix(4): cap"
sdd hook stop </dev/null >/dev/null 2>&1
assert_eq $? 2 "(an unfinished build blocks the builder)"
SDD_ROLE=verifier sdd hook stop </dev/null >/dev/null 2>&1 || fail "the finish gate held a verifier run"
unset SDD_ROLE # sh keeps a prefix assignment before a function call
# FR-84.1, FR-84.2: a live check for this item turns the block into a warning; a dead pid blocks again.
mark=$(git rev-parse --git-common-dir)/sdd/checks/4.running
sleep 30 &
spid=$!
echo "$spid" >"$mark"
out=$(sdd hook stop </dev/null 2>&1) || fail "stop blocked while the check runs: $out"
assert_contains "$out" 'still running'
kill "$spid"
wait "$spid" 2>/dev/null
sdd hook stop </dev/null >/dev/null 2>&1
assert_eq $? 2 "(a dead check pid blocks as before)"
rm -f "$mark"
# FR-84.1: sdd check itself writes the mark while its commands run, and removes it after.
git config -f .sdd/config --replace-all check.run "cp '$mark' '$T/seen'"
sdd check >/dev/null 2>&1
grep -qx '[0-9][0-9]*' "$T/seen" || fail "the check wrote no pid mark while running"
assert_no_file "$mark"
git config -f .sdd/config --replace-all check.run 'echo ok'
echo ok

# FR-62.1, FR-62.2: the phase line says verified only when it was; FR-62.3: lite warns at ship.
new_repo honest
planned_item fix "Honest" tasks
done_tasks
f=$ITEM
echo code >code.txt && git add -A && git commit -qm "fix(1): code"
fill "$f" built && git commit -qam "docs(1): built" && sdd check >/dev/null 2>&1 || fail "check failed"
assert_contains "$(sdd next 2>&1)" 'Phase: review (written up, NOT verified (no "Verified by:" line); walk through it with:'
awk '/^## Review/ { print "Verified by: none (no second model here)" } { print }' "$f" >"$T/f" && cp "$T/f" "$f"
assert_contains "$(sdd next 2>&1)" 'written up, NOT verified (Verified by: none); walk through it with:'
sed 's/^Verified by: none (no second model here)$/Verified by: sonnet: 1 of 1 FRs proven; no findings/' "$f" >"$T/f" && cp "$T/f" "$f"
assert_contains "$(sdd next 2>&1)" 'Phase: review (verified and written up; walk through it with:'
# A type whose gate is off is not told it lacks a verifier.
git checkout -q -- "$f" && git switch -q main
sdd new roadmap "Plan" >/dev/null 2>&1
r=$(ls specs/changes/*-plan/item.md)
fill "$r" plan && git add -A && git commit -qm "docs(2): plan" && sdd approve >/dev/null 2>&1
fill "$r" built && git commit -qam "docs(2): built" && sdd check >/dev/null 2>&1
out=$(sdd next 2>&1)
assert_contains "$out" 'Phase: review (written up; walk through it with:'
assert_not_contains "$out" 'NOT verified'
# FR-73.10: review leaves out the lines of gates that are off for the type (roadmap: no check, no verifier).
out=$(sdd review 2>&1)
assert_not_contains "$out" 'verify  '
assert_not_contains "$out" 'check   '
# FR-62.3: unverified in the default profile: a warning, and it still ships.
git switch -q fix/1-honest
out=$(sdd ship 2>&1) || fail "lite must still ship: $out"
assert_contains "$out" 'warning: item 1: not verified (gate verified)'

# FR-85.2, FR-85.3: review says what changed since the verified commit; ship warns, never blocks.
new_repo since
planned_item fix "Since" tasks
done_tasks
echo code >code.txt && git add -A && git commit -qm "fix(1): code"
sha=$(git rev-parse --short HEAD)
built_with "Verified by: opus at $sha: 1 of 1 FRs proven; no findings"
assert_contains "$(sdd review)" "verify  Verified by: opus at $sha: 1 of 1 FRs proven; no findings"
assert_contains "$(sdd review)" 'since   no code changed since'
echo more >more.txt && git add -A && git commit -qm "fix(1): more"
assert_contains "$(sdd review)" 'since   more.txt changed after the verifier ran'
built_with 'Verified by: opus: 1 of 1 FRs proven; no findings'
assert_contains "$(sdd review)" 'since   the Verified by line names no commit'
built_with 'Verified by: opus at deadbeef: 1 of 1 FRs proven; no findings'
assert_contains "$(sdd review)" 'since   the verified commit is not in this branch'
sdd check >/dev/null 2>&1 || fail "check failed"
out=$(sdd ship 2>&1) || fail "stale verification must not block: $out"
assert_contains "$out" 'warning: item 1: the verified commit is not in this branch'
exit 0

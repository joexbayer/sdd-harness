# FR-1.1 init vendors .sdd, writes config with detected base and checks, manages AGENTS.md.
. "$SRC/tests/lib.sh"

mkdir -p "$T/go" && cd "$T/go" || exit 1
git init -q
printf 'module example.com/x\n' >go.mod
printf '# Mine\n\nKeep this line.\n' >AGENTS.md
git add -A && git commit -qm init

out=$(sdd init 2>&1) || fail "init exited non-zero: $out"
assert_file .sdd/bin/sdd
assert_file .sdd/core/lib/common.sh
assert_file .sdd/VERSION
assert_eq "$(git config -f .sdd/config sdd.base)" main
assert_eq "$(git config -f .sdd/config --get-all check.run | paste -sd '|' -)" 'go vet ./...|go test ./...'
assert_contains "$(cat AGENTS.md)" 'Keep this line.'
assert_contains "$(cat AGENTS.md)" '.sdd/bin/sdd next'
assert_contains "$(cat AGENTS.md)" 'give every ID its name'

# Idempotent: a second run changes nothing.
before=$(cat AGENTS.md .sdd/config)
sdd init >/dev/null 2>&1 || fail "second init failed"
assert_eq "$(cat AGENTS.md .sdd/config)" "$before" "(second init changed files)"
assert_eq "$(grep -c '<!-- sdd:start -->' AGENTS.md)" 1

# Python: pytest through the interpreter, since its script is often not on PATH.
mkdir -p "$T/py" && cd "$T/py" || exit 1
git init -q && printf '[pytest]\n' >pytest.ini && git add -A && git commit -qm init
sdd init >/dev/null 2>&1
assert_eq "$(git config -f .sdd/config --get-all check.run)" 'python3 -m pytest'

# A repo with no detectable tests gets a warning, not a guess.
mkdir -p "$T/bare" && cd "$T/bare" || exit 1
git init -q && echo x >x && git add x && git commit -qm init
out=$(sdd init 2>&1)
assert_contains "$out" 'no test command detected'
git config -f .sdd/config --get-all check.run >/dev/null && fail "expected no check.run"

# Base detection prefers an existing main over the branch you happen to be on.
mkdir -p "$T/wip" && cd "$T/wip" || exit 1
git init -q && echo x >x && git add x && git commit -qm init
git switch -q -c feature/wip
sdd init >/dev/null 2>&1
assert_eq "$(git config -f .sdd/config sdd.base)" main
exit 0

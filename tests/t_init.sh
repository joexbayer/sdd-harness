# FR-1.1 init vendors .sdd, writes config with detected base and checks, manages AGENTS.md.
# FR-43.1 init on a branch other than the base warns; FR-43.2 on the base it does not.
# FR-44.3 init warns when git ignores the launcher; FR-44.4/FR-44.5 a repo's own gate
# (scripts/check.sh, make check) wins over the language guesses.
. "$SRC/tests/lib.sh"

mkdir -p "$T/go" && cd "$T/go" || exit 1
git init -q
printf 'module example.com/x\n' >go.mod
printf '# Mine\n\nKeep this line.\n' >AGENTS.md
git add -A && git commit -qm init

out=$(sdd init 2>&1) || fail "init exited non-zero: $out"
assert_not_contains "$out" 'not the base' # FR-43.2
assert_not_contains "$out" 'is ignored by git' # FR-44.3
assert_file .sdd/bin/sdd
assert_file .sdd/core/lib/common.sh
assert_file .sdd/VERSION
assert_eq "$(git config -f .sdd/config sdd.base)" main
# Detected test commands; gitleaks joins them when installed on this machine (FR-12.6, t_security.sh).
assert_eq "$(git config -f .sdd/config --get-all check.run | grep -v '^gitleaks ' | paste -sd '|' -)" 'go vet ./...|go test ./...'
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
assert_eq "$(git config -f .sdd/config --get-all check.run | grep -v '^gitleaks ')" 'python3 -m pytest'

# A repo with no detectable tests gets a warning, not a guess.
mkdir -p "$T/bare" && cd "$T/bare" || exit 1
git init -q && echo x >x && git add x && git commit -qm init
out=$(sdd init 2>&1)
assert_contains "$out" 'no test command detected'
[ -z "$(git config -f .sdd/config --get-all check.run | grep -v '^gitleaks ')" ] || fail "expected no detected check.run"

# Base detection prefers an existing main over the branch you happen to be on.
mkdir -p "$T/wip" && cd "$T/wip" || exit 1
git init -q && echo x >x && git add x && git commit -qm init
git switch -q -c feature/wip
out=$(sdd init 2>&1)
assert_eq "$(git config -f .sdd/config sdd.base)" main
# FR-43.1: items branch from main, so an install committed only here would vanish on sdd new.
assert_contains "$out" 'sdd: warning: you are on feature/wip, not the base main: new items branch from main, so commit this install on main (or merge it there) before sdd new'

# FR-44.3: a Go-style `bin/` ignore also matches .sdd/bin/, so the install would be committed
# without its launcher.
mkdir -p "$T/ign" && cd "$T/ign" || exit 1
git init -q && printf 'bin/\n' >.gitignore && git add -A && git commit -qm init
out=$(sdd init 2>&1)
assert_contains "$out" 'sdd: warning: .sdd/bin/sdd is ignored by git (.gitignore:1:bin/): commit it with git add -f, or anchor the pattern to the root (/bin/)'

# FR-44.4: an executable scripts/check.sh is the repo's own gate, used instead of the guesses.
mkdir -p "$T/own/scripts" && cd "$T/own" || exit 1
git init -q && printf 'module example.com/x\n' >go.mod
printf '#!/bin/sh\ngo test ./...\n' >scripts/check.sh && chmod +x scripts/check.sh
git add -A && git commit -qm init
sdd init >/dev/null 2>&1
assert_eq "$(git config -f .sdd/config --get-all check.run | grep -v '^gitleaks ' | paste -sd '|' -)" 'scripts/check.sh'

# FR-44.5: without one, a Makefile check target wins over the guesses.
mkdir -p "$T/mk" && cd "$T/mk" || exit 1
git init -q && printf 'module example.com/x\n' >go.mod
printf 'check:\n\tgo test ./...\n' >Makefile
git add -A && git commit -qm init
sdd init >/dev/null 2>&1
assert_eq "$(git config -f .sdd/config --get-all check.run | grep -v '^gitleaks ' | paste -sd '|' -)" 'make check'
exit 0

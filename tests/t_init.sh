# FR-1.1 init vendors .sdd, writes config with detected base and checks, manages AGENTS.md.
# FR-43.1 init on a branch other than the base warns; FR-43.2 on the base it does not.
# FR-44.3 init warns when git ignores the launcher; FR-44.4/FR-44.5 a repo's own gate
# (scripts/check.sh, make check) wins over the language guesses.
# FR-45.1 rerunning init from another sdd updates bin/ and core/; FR-45.2 says up to date when they
# match; FR-45.3 refuses on uncommitted changes there. FR-49.1 VERSION names the source commit;
# FR-49.2/FR-49.3 a dirty source or one off its base warns; FR-49.4 a source outside git does not.
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
out=$(sdd init 2>&1)
assert_eq "$(git config -f .sdd/config --get-all check.run | grep -v '^gitleaks ' | paste -sd '|' -)" 'make check'
# FR-66.2: init says the gate runs before every ship and asks the human to confirm it.
assert_contains "$out" 'gate    make check runs before every ship. Your real per-change gate? If not, edit [check] run in .sdd/config'

# FR-45.1: an install committed in the repo, then hand-changed (an edit and a file the new sdd
# does not have), is replaced by rerunning init from the source sdd.
cd "$T/go" || exit 1
git add -A && git commit -qm "install sdd"
cfg_before=$(cat .sdd/config)
echo '# stale' >>.sdd/core/cmd/help.sh && touch .sdd/core/old.sh
git add -A && git commit -qm "old sdd"
out=$(sdd init 2>&1) || fail "update failed: $out"
assert_contains "$out" "updated sdd in .sdd/ from $SRC/.sdd: commit .sdd/bin and .sdd/core (and run sdd sync <agent> again if you use it)"
diff -r .sdd/core "$SRC/.sdd/core" >/dev/null 2>&1 || fail "core differs from the source after the update"
[ ! -e .sdd/core/old.sh ] || fail "a file only the old install had is still there"
assert_eq "$(cat .sdd/config)" "$cfg_before" "(the update changed the config)"
git add -A && git commit -qm "update sdd"

# FR-45.2: nothing to update.
out=$(sdd init 2>&1)
assert_contains "$out" 'sdd already installed in .sdd/ and up to date'
assert_not_contains "$out" 'updated sdd'

# FR-45.3: uncommitted changes in core are never overwritten.
echo '# stale' >>.sdd/core/cmd/help.sh && git commit -qam "old sdd again"
echo '# mine' >>.sdd/core/cmd/help.sh
out=$(sdd init 2>&1)
assert_eq $? 1 "(init should refuse)"
assert_contains "$out" 'sdd: .sdd/bin or .sdd/core has uncommitted changes: commit or discard them first (overrides belong in .sdd/local/)'
assert_eq "$(tail -n 1 .sdd/core/cmd/help.sh)" '# mine'

# FR-49.1: a source sdd in its own checkout, clean, on main.
mkdir -p "$T/src" && cp -R "$SRC/.sdd" "$T/src/" && cd "$T/src" || exit 1
git init -q && git add -A && git commit -qm src
c=$(git rev-parse --short=12 HEAD) && v=$(cat .sdd/VERSION) && home=$(cd .sdd && pwd -P)
fresh() { mkdir -p "$T/$1" && cd "$T/$1" && git init -q && echo x >x && git add x && git commit -qm init; }
fresh a
out=$("$SH" "$T/src/.sdd/bin/sdd" init 2>&1) || fail "init from the source failed: $out"
assert_eq "$(cat .sdd/VERSION)" "$v ($c)"
assert_contains "$out" "installed sdd $v ($c) into .sdd/"
assert_not_contains "$out" 'the sdd you install from'

# FR-49.2: uncommitted changes in the source are copied, said, and stamped.
echo '# wip' >>"$T/src/.sdd/core/cmd/help.sh"
fresh b
out=$("$SH" "$T/src/.sdd/bin/sdd" init 2>&1)
assert_contains "$out" "sdd: warning: the sdd you install from ($home) has uncommitted changes, and they are copied too: install from a clean checkout of its base branch"
assert_eq "$(cat .sdd/VERSION)" "$v ($c, uncommitted changes)"
git -C "$T/src" checkout -q -- .

# FR-49.3: a source on another branch than its base.
git -C "$T/src" switch -q -c feature/x
fresh c
out=$("$SH" "$T/src/.sdd/bin/sdd" init 2>&1)
assert_contains "$out" "sdd: warning: the sdd you install from ($home) is on feature/x, not main: unshipped work is copied too"
assert_not_contains "$out" 'has uncommitted changes'

# FR-49.4: a source outside any checkout: the plain version, no warning.
mkdir -p "$T/plain" && cp -R "$SRC/.sdd" "$T/plain/"
fresh d
out=$("$SH" "$T/plain/.sdd/bin/sdd" init 2>&1)
assert_eq "$(cat .sdd/VERSION)" "$v"
assert_not_contains "$out" 'the sdd you install from'
exit 0

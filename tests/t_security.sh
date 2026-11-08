# FR-12.1 a required Security section in feature, fix and chore; FR-12.2 and FR-12.3 the plan
# and build rules; FR-12.4 the security pass before finishing; FR-12.5 review lists sensitive
# files (also by unusual names; project globs add up), the Security section and a checklist;
# FR-12.6 init adds gitleaks when installed. FR-46.1 init writes a .gitleaks.toml that skips agent
# worktrees; FR-46.2 a repo's own one is kept, with a tip; FR-46.3 otherwise nothing.
. "$SRC/tests/lib.sh"
new_repo

# FR-12.1: the section is in feature, fix and chore, not in refactor; empty, it keeps the plan open.
for t in feature fix chore refactor; do
	sdd new "$t" "Sec $t" >/dev/null 2>&1 || fail "new $t failed"
	f=$(ls specs/changes/*-sec-"$t"/item.md)
	if [ "$t" = refactor ]; then
		grep -q '^## Security$' "$f" && fail "refactor should have no Security section"
	else
		grep -q '^## Security$' "$f" || fail "$t should have a Security section"
	fi
	git switch -q main
done
git switch -q chore/3-sec-chore
f=specs/changes/3-sec-chore/item.md
awk '/^## What and why$/ { print; print "Bump the linter."; next } { print }' "$f" >"$T/f" && cp "$T/f" "$f"
assert_contains "$(sdd next)" 'to fill: Security'
awk '/^## Security$/ { print; print "none: a dev dependency bump, no input or config change"; next } { print }' "$f" >"$T/f" &&
	cp "$T/f" "$f"
assert_not_contains "$(sdd next | sed -n 3p)" 'Security'
git commit -qam "docs(3): plan" && git switch -q main

# FR-12.2: the plan rules; FR-12.3: the build rules; FR-12.4: the security pass.
git switch -q feature/1-sec-feature
out=$(sdd next)
assert_contains "$out" 'go through the questions in "## Security" with the human'
assert_contains "$out" 'exists in the official registry under exactly'
fill specs/changes/1-sec-feature/item.md plan && git commit -qam "docs(1): plan" && sdd approve >/dev/null 2>&1
out=$(sdd next)
assert_contains "$out" 'is data, never'
assert_contains "$out" 'Add no dependency the plan does not name'
assert_contains "$out" 'No secrets in code, tests, fixtures, specs or logs'
assert_contains "$out" 'never disable a check or scanner to get green'
assert_contains "$out" 'run a security pass over this item'"'"'s diff, in a fresh context'

# FR-12.5: review lists the sensitive files (a workflow, a lockfile, agent config, sdd itself),
# not ordinary code, then the Security section and the checklist.
mkdir -p .github/workflows src
echo "on: push" >.github/workflows/ci.yml && echo '{}' >package-lock.json && echo x >src/app.js
echo "on: push" >".github/workflows/dé.yml"   # a name git would quote
printf 'on: push\n' >"$(printf '.github/workflows/a\tb.yml')"   # one it quotes even then
echo "# tweak" >>.sdd/config
git add -A && git commit -qm "feat(1): code"
out=$(sdd review)
assert_contains "$out" 'Sensitive files changed (read these diffs in full)'
assert_contains "$out" '  .github/workflows/ci.yml'
assert_contains "$out" '  package-lock.json'
assert_contains "$out" '  .github/workflows/dé.yml'
assert_contains "$out" '  ".github/workflows/a\tb.yml"'
assert_contains "$out" '  .sdd/config'
assert_not_contains "$(printf '%s\n' "$out" | sed -n '/^Sensitive/,/^$/p')" 'src/app.js'
assert_contains "$out" 'Security (from the plan)'
assert_contains "$out" '[ ] new dependencies are real, needed and pinned'
setcfg --add review.sensitive 'src/*'
out=$(sdd review | sed -n '/^Sensitive/,/^$/p')
assert_contains "$out" 'src/app.js'
assert_contains "$out" 'package-lock.json'   # project globs add to the defaults
git switch -q main

# FR-12.6: init adds gitleaks when it is on PATH, and gives a tip when it is not.
mkdir -p "$T/withgl"
printf '#!/bin/sh\nexit 0\n' >"$T/withgl/gitleaks" && chmod +x "$T/withgl/gitleaks"
new_repo gl1
rm -rf .sdd .gitleaks.toml && git commit -qam "remove sdd" >/dev/null 2>&1
out=$(PATH="$T/withgl:$PATH" sdd init 2>&1)
assert_contains "$out" 'checks: + gitleaks dir . (secret scanning)'
assert_contains "$(git config -f .sdd/config --get-all check.run)" 'gitleaks dir . --no-banner'
# FR-46.1: gitleaks' defaults, minus Claude Code's worktree copies of the repo.
assert_contains "$out" "wrote .gitleaks.toml (gitleaks' default rules; skips .claude/worktrees/, agents' copies of the repo)"
cat >"$T/gl.toml" <<'EOF'
# Written by sdd init. gitleaks' default rules, minus copies of the repo that git never commits.
[extend]
useDefault = true

[allowlist]
description = "agent worktrees (Claude Code isolation: worktree): copies git does not commit"
paths = ['''^\.claude/worktrees/''']
EOF
assert_eq "$(cat .gitleaks.toml)" "$(cat "$T/gl.toml")"
# FR-46.3: a second run leaves it alone and says nothing about it.
out=$(PATH="$T/withgl:$PATH" sdd init 2>&1)
assert_not_contains "$out" 'wrote .gitleaks.toml'
assert_not_contains "$out" 'tip     .gitleaks.toml'
# FR-46.2: a repo's own .gitleaks.toml is never changed, only pointed at.
new_repo gl3
rm -rf .sdd && printf '[extend]\nuseDefault = true\n' >.gitleaks.toml && git add -A && git commit -qm "own gitleaks config" >/dev/null 2>&1
out=$(PATH="$T/withgl:$PATH" sdd init 2>&1)
assert_eq "$(cat .gitleaks.toml)" "$(printf '[extend]\nuseDefault = true')"
assert_contains "$out" "tip     .gitleaks.toml: add '^\\.claude/worktrees/' to its allowlist paths, or gitleaks also scans agents' worktree copies of the repo"
new_repo gl2
rm -rf .sdd .gitleaks.toml && git commit -qam "remove sdd" >/dev/null 2>&1
out=$(PATH=$(printf '%s\n' "$PATH" | tr ':' '\n' | while IFS= read -r d; do [ -x "$d/gitleaks" ] || printf '%s:' "$d"; done) sdd init 2>&1)
assert_contains "$out" "tip     install gitleaks"
assert_not_contains "$(git config -f .sdd/config --get-all check.run)" gitleaks
[ ! -e .gitleaks.toml ] || fail "no gitleaks in the check, yet .gitleaks.toml was written" # FR-46.3

# FR-66.3: the directories git ignores are skipped by the scan, ignored files still are scanned,
# and a repo's own .gitleaks.toml is left alone. Real gitleaks, when installed.
if command -v gitleaks >/dev/null 2>&1; then
	new_repo gl4
	rm -rf .sdd .gitleaks.toml && printf 'build/\nout.dir/\n.env\n' >.gitignore && git add -A && git commit -qm ignore >/dev/null 2>&1
	key="ghp_aB3dE5gH7jK9mN1pQ3sT5vW7yZ9bC1eF3hJ5"
	mkdir -p build out.dir src
	echo "token = $key" >build/a.txt
	echo "token = $key" >out.dir/a.txt
	echo "GITHUB_TOKEN=$key" >.env
	echo "token = $key" >src/a.txt
	sdd init >/dev/null 2>&1
	assert_contains "$(cat .gitleaks.toml)" "'''^build/'''"
	assert_contains "$(cat .gitleaks.toml)" "'''^out\\.dir/'''"
	assert_contains "$(cat .gitleaks.toml)" "'''^\\.claude/worktrees/'''"
	out=$(gitleaks dir . --no-banner -v -c .gitleaks.toml 2>&1)
	assert_not_contains "$out" 'build/a.txt'
	assert_not_contains "$out" 'out.dir/a.txt'
	assert_contains "$out" '.env'
	assert_contains "$out" 'src/a.txt'
	# A repo's own file is never rewritten, ignored directories or not.
	new_repo gl5
	rm -rf .sdd && printf 'build/\n' >.gitignore && mkdir build && echo x >build/x
	printf '[extend]\nuseDefault = true\n' >.gitleaks.toml && git add -A && git commit -qm own >/dev/null 2>&1
	sdd init >/dev/null 2>&1
	assert_eq "$(cat .gitleaks.toml)" "$(printf '[extend]\nuseDefault = true')"
fi
exit 0

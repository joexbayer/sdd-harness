# FR-12.1 a required Security section in feature, fix and chore; FR-12.2 and FR-12.3 the plan
# and build rules; FR-12.4 the security pass before finishing; FR-12.5 review lists sensitive
# files, the Security section and a checklist; FR-12.6 init adds gitleaks when installed.
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
echo "# tweak" >>.sdd/config
git add -A && git commit -qm "feat(1): code"
out=$(sdd review)
assert_contains "$out" 'Sensitive files changed (read these diffs in full)'
assert_contains "$out" '  .github/workflows/ci.yml'
assert_contains "$out" '  package-lock.json'
assert_contains "$out" '  .sdd/config'
assert_not_contains "$(printf '%s\n' "$out" | sed -n '/^Sensitive/,/^$/p')" 'src/app.js'
assert_contains "$out" 'Security (from the plan)'
assert_contains "$out" '[ ] new dependencies are real, needed and pinned'
setcfg --add review.sensitive 'src/*'
assert_contains "$(sdd review | sed -n '/^Sensitive/,/^$/p')" 'src/app.js'
git switch -q main

# FR-12.6: init adds gitleaks when it is on PATH, and gives a tip when it is not.
mkdir -p "$T/withgl"
printf '#!/bin/sh\nexit 0\n' >"$T/withgl/gitleaks" && chmod +x "$T/withgl/gitleaks"
new_repo gl1
rm -rf .sdd && git commit -qam "remove sdd" >/dev/null 2>&1
out=$(PATH="$T/withgl:$PATH" sdd init 2>&1)
assert_contains "$out" 'checks: + gitleaks dir . (secret scanning)'
assert_contains "$(git config -f .sdd/config --get-all check.run)" 'gitleaks dir . --no-banner'
new_repo gl2
rm -rf .sdd && git commit -qam "remove sdd" >/dev/null 2>&1
out=$(PATH=$(printf '%s\n' "$PATH" | tr ':' '\n' | while IFS= read -r d; do [ -x "$d/gitleaks" ] || printf '%s:' "$d"; done) sdd init 2>&1)
assert_contains "$out" "tip     install gitleaks"
assert_not_contains "$(git config -f .sdd/config --get-all check.run)" gitleaks
exit 0

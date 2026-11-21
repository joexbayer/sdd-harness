# FR-79.1 a standard is read from specs/standards/<name>.md, else the built-in; FR-79.2 check fails on a
# malformed used standard; FR-79.3 next lists each one on a line; FR-79.4 the plan's Standards: line;
# FR-79.5 the build prompt shows the named rules; FR-79.6 review shows them and a change to specs/standards/;
# FR-79.7 init writes [standards] use and the built-ins are standards in this format. DOD-79.1.
. "$SRC/tests/lib.sh"
new_repo base
mkdir -p specs/standards
cat >specs/standards/api-errors.md <<'EOT'
---
status: enforced
---
API errors: what every HTTP error returns.
API-1 MUST error bodies use problem+json.
API-2 SHOULD put a trace id in every error body.
EOT
setcfg standards.use "asvs-l2 api-errors"
git add specs/standards && git commit -qm "team standard"
sdd new feature "Std base" >/dev/null 2>&1 || fail "new failed"
f=$(ls specs/changes/*-std-base/item.md)
sec() { awk -v l="$1" '/^## Security$/ { print; print l; next } { print }' "$f" >"$T/f" && cp "$T/f" "$f"; }

# FR-79.3: one catalog line per standard, not its rules; a team file replaces a built-in of that name.
out=$(sdd next)
assert_contains "$out" 'api-errors  enforced  2 rules  API errors: what every HTTP error returns.  (specs/standards/api-errors.md)'
assert_contains "$out" 'asvs-l2    advisory  '
assert_contains "$out" '(built-in .sdd/core/standards/asvs-l2.md)'
assert_not_contains "$out" 'API-1'
assert_not_contains "$out" 'ASVS2-1'

# FR-79.4: no Standards line, a name not in use and an unknown one are plan problems.
fill "$f" plan
out=$(sdd analyze 2>&1)
assert_contains "$out" '✗ Standards: no "Standards:" line (in use: asvs-l2 api-errors): name which add work here, or none'
sec "Standards: asvs-l2 (V16 logging), gdpr"
assert_contains "$(sdd analyze 2>&1)" '✗ Standards: gdpr is not in [standards] use (asvs-l2 api-errors)'
git commit -qam "docs: plan"
sec "Standards: none"
assert_not_contains "$(sdd analyze 2>&1)" 'Standards:'
git checkout -q -- "$f"
sec "Standards: asvs-l2 (V1 encoding: names become paths), api-errors"
assert_not_contains "$(sdd analyze 2>&1)" 'Standards:'
git commit -qam "docs: standards"
# FR-79.1: a name with no file, or that is not a plain name, is reported.
setcfg standards.use "asvs-l2 api-errors hipaa ../x"
out=$(sdd analyze 2>&1)
assert_contains "$out" '✗ Standards: unknown standard hipaa (add specs/standards/hipaa.md)'
assert_contains "$out" '✗ Standards: ../x is not a standard name (letters, digits, - and _)'
setcfg standards.use "asvs-l2 api-errors"

# FR-79.4: only a type with a Security section is asked.
git switch -q -c scratch main
sdd new refactor "R" >/dev/null 2>&1 || fail "new refactor failed"
assert_not_contains "$(sdd analyze 2>&1)" 'Standards:'
git switch -q feature/1-std-base

# FR-79.2: check fails on a malformed used standard, naming file and line; a clean one passes.
out=$(sdd check 2>&1) || fail "check failed on clean standards: $out"
printf 'Errors use problem+json.\n' >>specs/standards/api-errors.md
out=$(sdd check 2>&1) && fail "check passed a malformed standard"
assert_contains "$out" '✗ standard api-errors:7: not a rule (<ID> MUST|SHOULD <text>)'
git checkout -q -- specs/standards 2>/dev/null; git checkout -q HEAD -- specs/standards
printf -- '---\nstatus: maybe\n---\nS.\nX-1 MUST a.\n' >specs/standards/api-errors.md
assert_contains "$(sdd check 2>&1)" '✗ standard api-errors:2: status must be advisory or enforced'
printf -- '---\nstatus: advisory\n---\nS.\nAPI-1 MUST a.\nAPI-1 SHOULD b.\n' >specs/standards/api-errors.md
assert_contains "$(sdd check 2>&1)" '✗ standard api-errors:6: duplicate ID API-1 (first at api-errors:5)'
printf 'S.\nAPI-1 MUST a.\n' >specs/standards/api-errors.md
assert_contains "$(sdd check 2>&1)" '✗ standard api-errors:1: front matter must give status: advisory or status: enforced'
git checkout -q HEAD -- specs/standards

# FR-79.5: the build prompt shows the rules of the named standards, with status, and no others.
git commit -qam "docs: plan" >/dev/null 2>&1
sdd approve >/dev/null 2>&1 || fail "approve failed"
out=$(sdd next)
assert_contains "$out" 'Standards (follow these rules): asvs-l2 advisory, api-errors enforced'
assert_contains "$out" 'API-1 MUST error bodies use problem+json.'
assert_contains "$out" 'API-2 SHOULD put a trace id in every error body.'
assert_contains "$out" 'ASVS2-1 '

# FR-79.6: review prints the named rules for the verifier, and a change to specs/standards/ in full.
echo "API-3 MUST log the trace id." >>specs/standards/api-errors.md
mkdir -p src && echo x >src/a.js && git add -A && git commit -qm "feat(1): code"
out=$(sdd review)
assert_contains "$out" 'Standards (the verifier checks the diff against each rule)'
assert_contains "$out" 'API-1 MUST error bodies use problem+json.'
assert_contains "$out" 'Standards diff'
assert_contains "$out" '+API-3 MUST log the trace id.'
verifier=$(cat "$SRC/.sdd/core/prompts/role-verifier.md")
assert_contains "$verifier" 'must-fix'
assert_contains "$verifier" 'rule'
git switch -q main
# FR-79.1: a plan naming ../x reads no file outside specs/standards/ (standard_file's own name check).
sdd new feature "Std path" >/dev/null 2>&1 || fail "new failed"
g=$(ls specs/changes/*-std-path/item.md)
printf -- '---\nstatus: enforced\n---\nS.\nX-1 MUST leak.\n' >specs/x.md
awk '/^## Security$/ { print; print "Standards: ../x"; next } { print }' "$g" >"$T/g" && cp "$T/g" "$g"
git add -A && git commit -qm "docs: plan"
assert_not_contains "$(sdd review 2>&1)" 'X-1 MUST leak'
git switch -q main
# A name written twice in use is linted and listed once.
setcfg standards.use "asvs-l2 asvs-l2"
assert_not_contains "$(sdd check 2>&1)" 'duplicate ID'
setcfg standards.use "asvs-l2 api-errors"

# FR-79.7: init writes [standards] use; the five built-ins are advisory standards that pass the lint.
mkdir "$T/ini" && cd "$T/ini" && git init -q && echo x >README.md && git add -A && git commit -qm init
out=$(sdd init 2>&1)
assert_eq "$(git config -f .sdd/config standards.use)" asvs-l2
assert_contains "$out" 'standards asvs-l2 (OWASP ASVS level 2). Your own: specs/standards/<name>.md, then add the name to [standards] use'
git add -A && git commit -qm adopt >/dev/null 2>&1
# DOD-79.1: a fresh repo's feature lists the standard, and approve needs a Standards line.
sdd new feature "F" >/dev/null 2>&1 || fail "new feature failed"
assert_contains "$(sdd next)" '(built-in .sdd/core/standards/asvs-l2.md)'
f=$(ls specs/changes/*-f/item.md)
fill "$f" plan
git add -A && git commit -qm "docs: plan" >/dev/null 2>&1
out=$(sdd approve 2>&1) && fail "approve without a Standards line passed: $out"
assert_contains "$out" 'no "Standards:" line'
awk '/^## Security$/ { print; print "Standards: none"; next } { print }' "$f" >"$T/f" && cp "$T/f" "$f"
git commit -qam "docs: standards" >/dev/null 2>&1
out=$(sdd approve 2>&1) || fail "approve with a Standards line failed: $out"
git config -f .sdd/config standards.use "asvs-l1 asvs-l2 asvs-l3 masvs llm-top10"
git config -f .sdd/config --add check.run 'echo ok'
for n in asvs-l1 asvs-l2 asvs-l3 masvs llm-top10; do
	assert_contains "$(sed -n 2p "$SRC/.sdd/core/standards/$n.md")" 'status: advisory'
done
out=$(sdd check 2>&1) || fail "the built-in standards fail the lint: $out"
exit 0

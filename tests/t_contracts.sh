# Item 26 (contracts): FR-26.1 the contract type, FR-26.2 only a contract item changes
# specs/contracts/ and it lands no code, FR-26.3 contract names, FR-26.4 approve pins them from the
# base branch, FR-26.5 a changed contract sends its items back to planning, FR-26.6 next lists them
# for the builder, FR-26.7 review shows a contract item's diff in full.
. "$SRC/tests/lib.sh"
new_repo

# FR-26.1: a contract item, with its own sections and prompts.
out=$(sdd new contract "Orders API" 2>&1) || fail "new contract failed: $out"
assert_contains "$out" '1 contract · Orders API'
c=specs/changes/1-orders-api/item.md
assert_contains "$(git branch --show-current)" 'contract/1-orders-api'
for h in '## Why' '## Contract' '## Users' '## Compatibility' '## Security' '## Done when' '## Built' '## Review (optional)'; do
	grep -qx "$h" "$c" || fail "contract template lacks $h"
done
assert_contains "$(sdd next)" 'Under "Compatibility" list every open item using it'

# FR-26.2: a contract item lands no code: check and ship refuse it.
fill "$c" plan && git commit -qam "docs(1): plan" && sdd approve >/dev/null 2>&1 || fail "approve contract failed"
mkdir -p specs/contracts
printf 'openapi: 3.1.0\npaths: {}\n' >specs/contracts/orders-api.yaml
echo code >app.js
fill "$c" built && git add -A && git commit -qm "contract and code"
out=$(sdd check 2>&1)
assert_eq $? 1 "(check of a contract item with code)"
assert_contains "$out" 'a contract item lands no code'
out=$(sdd ship 2>&1)
assert_eq $? 1 "(ship of a contract item with code)"
assert_contains "$out" 'item 1: a contract item lands no code'
git rm -q app.js && git commit -qm "no code"
assert_contains "$(sdd check 2>&1)" '✓ check passed'
sdd ship >/dev/null 2>&1 || fail "ship contract failed: $(sdd ship 2>&1)"
git cat-file -e main:specs/contracts/orders-api.yaml || fail "the contract must land on main"
git switch -q main

# FR-26.2: any other item that changes specs/contracts/ is refused, uncommitted (check) or committed (ship).
sdd new feature "Sneaky" >/dev/null 2>&1
f=specs/changes/2-sneaky/item.md
fill "$f" plan && git commit -qam "docs(2): plan" && sdd approve >/dev/null 2>&1 || fail "approve 2 failed"
fill "$f" built && git commit -qam "docs(2): built"
printf 'openapi: 3.1.0\npaths: { /orders: {} }\n' >specs/contracts/orders-api.yaml
out=$(sdd check 2>&1)
assert_eq $? 1 "(check of a feature editing a contract)"
assert_contains "$out" 'contracts change only through: .sdd/bin/sdd new contract "…"'
git checkout -q -- specs/contracts/orders-api.yaml
echo x >specs/contracts/new-api.yaml
assert_contains "$(sdd check 2>&1)" 'contracts change only through'
git add -A && git commit -qm "sneak a contract"
before=$(git rev-parse HEAD)
out=$(sdd ship 2>&1)
assert_eq $? 1 "(ship of a feature adding a contract)"
assert_contains "$out" 'item 2: contracts change only through'
assert_eq "$(git rev-parse HEAD)" "$before"
git switch -q main
echo ok

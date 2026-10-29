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

# uses <item file> <list>: set its "contracts:" line (frontmatter) and commit it.
uses() {
	awk -v l="$2" '/^contracts:/ { next } { print } /^created: / && !d { if (l != "") print "contracts: " l; d = 1 }' "$1" >"$T/u" &&
		cp "$T/u" "$1" && git commit -qam "docs: contracts $2"
}
# ship_contract "<title>" <shell>: open a contract item from main, run <shell> in it, ship it.
ship_contract() {
	git switch -q main
	sdd new contract "$1" >/dev/null 2>&1 || fail "new contract $1 failed"
	sc=$(for x in specs/changes/*/item.md; do grep -q "^title: $1\$" "$x" && echo "$x"; done)
	fill "$sc" plan && git commit -qam "docs: plan" && sdd approve >/dev/null 2>&1 || fail "approve $1 failed"
	mkdir -p specs/contracts && eval "$2" && fill "$sc" built && git add -A && git commit -qm "contract: $1"
	sdd ship >/dev/null 2>&1 || fail "ship $1 failed: $(sdd ship 2>&1)"
	git switch -q main
}

# A feature built against the contract.
sdd new feature "Orders page" >/dev/null 2>&1
p=specs/changes/3-orders-page/item.md
fill "$p" plan && git commit -qam "docs(3): plan"

# FR-26.3: a name that is not [A-Za-z0-9_-]+ is refused (it would become a path), by approve and next.
uses "$p" '../etc'
out=$(sdd approve 2>&1)
assert_eq $? 1 "(approve with a bad contract name)"
assert_contains "$out" 'contract name "../etc" refused'
assert_contains "$(sdd next)" 'Phase: plan (contract name "../etc" refused'
grep -q '^approved:' "$p" && fail "a bad name must not be approved"

# FR-26.4: a contract that is not on main is refused, naming it.
uses "$p" 'orders-api, payments'
out=$(sdd approve 2>&1)
assert_eq $? 1 "(approve with a contract not on main)"
assert_contains "$out" 'no contract payments on main: ship its contract item first'

# FR-26.3, FR-26.4: orders-api is specs/contracts/orders-api.yaml on main; approve pins its id.
uses "$p" 'orders-api'
out=$(sdd approve 2>&1) || fail "approve 3 failed: $out"
tok=$(sed -n 's/^approved: \([^ ]*\) .*/\1/p' "$p")
assert_eq "${tok#*,}" "orders-api=$(git rev-parse main:specs/contracts/orders-api.yaml)"
assert_contains "$(sdd next)" 'Phase: build'

# FR-26.5: the contract changes on main: the item goes back to planning, naming it, in next and ls.
git switch -q main
assert_contains "$(sdd ls --json | grep '"id":3,')" '"phase":"build"'
ship_contract "Orders API v2" "printf 'openapi: 3.1.0\npaths: { /orders: {} }\n' >specs/contracts/orders-api.yaml"
# D-26.4: the row was not cached as fixed: the list sees the change at once.
assert_contains "$(sdd ls --json | grep '"id":3,')" '"reason":"contract orders-api changed on main after approval'
assert_contains "$(sdd ls --json | grep '"id":3,')" '"reason_code":"contract"'
git switch -q feature/3-orders-page
assert_contains "$(sdd next)" 'Phase: plan (contract orders-api changed on main after approval; check the plan still fits, merge main, then the human re-approves: .sdd/bin/sdd approve)'
assert_contains "$(sdd status)" 'contract orders-api changed'

# FR-26.4: re-approving before merging main is refused: this branch's copy is the old one.
out=$(sdd approve 2>&1)
assert_eq $? 1 "(approve with an old contract copy)"
assert_contains "$out" 'specs/contracts/orders-api.yaml differs from main: merge main first'
git merge -q --no-edit main >/dev/null 2>&1 || fail "merge main failed"
sdd approve >/dev/null 2>&1 || fail "re-approve after merge failed: $(sdd approve 2>&1)"
assert_contains "$(sdd next)" 'Phase: build'

# FR-26.5: changing the contracts: list after approval voids it too.
ship_contract "Billing" "mkdir -p specs/contracts/billing && echo 'type: object' >specs/contracts/billing/invoice.yaml"
git switch -q feature/3-orders-page
git merge -q --no-edit main >/dev/null 2>&1 || fail "merge main failed"
assert_contains "$(sdd next)" 'Phase: build'
uses "$p" 'orders-api, billing'
assert_contains "$(sdd next)" 'Phase: plan (the contracts: list changed after approval'
# FR-26.3: a folder is a contract too, pinned by its tree id.
sdd approve >/dev/null 2>&1 || fail "approve with a folder contract failed: $(sdd approve 2>&1)"
tok=$(sed -n 's/^approved: \([^ ]*\) .*/\1/p' "$p")
assert_eq "${tok#*,}" "orders-api=$(git rev-parse main:specs/contracts/orders-api.yaml),billing=$(git rev-parse main:specs/contracts/billing)"
assert_contains "$(sdd next)" 'Phase: build'

# FR-26.6: in build, next lists the contracts as fixed input (a folder with its /); not in plan.
out=$(sdd next)
assert_contains "$out" 'Contracts (read them; they change only through a contract item): specs/contracts/orders-api.yaml, specs/contracts/billing/'
uses "$p" 'orders-api'
assert_not_contains "$(sdd next)" 'Contracts (read them'

# FR-26.7: review of a contract item shows the contract diff in full; other items' reviews do not.
assert_not_contains "$(sdd review)" 'Contract diff'
git switch -q main
sdd new contract "Orders API v3" >/dev/null 2>&1 || fail "new contract v3 failed"
v3=$(ls specs/changes/*-orders-api-v3/item.md)
fill "$v3" plan && git commit -qam "docs: plan" && sdd approve >/dev/null 2>&1 || fail "approve v3 failed"
printf 'openapi: 3.1.0\npaths: { /orders: {}, /orders/{id}: {} }\n' >specs/contracts/orders-api.yaml
git commit -qam "contract v3"
out=$(sdd review)
assert_contains "$out" 'Contract diff (against where this branch left main; read it in full)'
assert_contains "$out" '  -paths: { /orders: {} }'
assert_contains "$out" '  +paths: { /orders: {}, /orders/{id}: {} }'
echo ok

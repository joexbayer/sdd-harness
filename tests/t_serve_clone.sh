# FR-53.3: in a clone with no checkout (as sdd-server keeps them), an sdd home holding the
# bundled bin/ and core/ plus the repo's .sdd/config lists what `ls --json --all` lists in a full
# clone of the same refs, and runs no file of the repo's own .sdd/.
. "$SRC/tests/lib.sh"
new_repo
git init -q --bare "$T/origin.git" && git remote add origin "$T/origin.git" && git push -q origin main

sdd new feature "One" >/dev/null 2>&1 || fail "new 1 failed"
fill specs/changes/1-one/item.md plan
awk '{ print } $0 == "## Tasks (optional)" { print "- [ ] T-1.1 the form (files: src/a.go, src/b.go; test: go test)"; print "" }' \
	specs/changes/1-one/item.md >"$T/i" && cp "$T/i" specs/changes/1-one/item.md
git commit -qam "plan 1" && git push -q origin HEAD
git switch -q main
sdd new fix "Two" >/dev/null 2>&1 || fail "new 2 failed"
git push -q origin HEAD
git switch -q main
mkdir -p specs/archive/9-gone
printf -- '---\nid: 9\ntype: chore\ntitle: Gone\nstatus: dropped\n---\n# 9 Gone\n' >specs/archive/9-gone/item.md
git add -A && git commit -qm "drop 9" && git push -q origin main

git clone -q "$T/origin.git" "$T/full"
git clone -q --no-checkout "$T/origin.git" "$T/nock"
assert_no_file "$T/nock/.sdd"
# Named .sdd like a vendored copy, so the commands its reasons name read `.sdd/bin/sdd`.
home="$T/homes/x/.sdd"
mkdir -p "$home"
cp -R "$SRC/.sdd/bin" "$SRC/.sdd/core" "$SRC/.sdd/VERSION" "$home/"
git -C "$T/nock" show main:.sdd/config >"$home/config"
nock_ls() { (cd "$T/nock" && "$SH" "$home/bin/sdd" ls --json --all); }

want=$(cd "$T/full" && sdd ls --json --all) || fail "ls in the full clone failed"
assert_eq "$(printf '%s\n' "$want" | jq -r '.id' | tr '\n' ' ')" '1 2 9 '
got=$(nock_ls) || fail "ls in the no-checkout clone failed: $got"
assert_eq "$got" "$want"
# FR-53.2: what the server's `item` reads there: a task's files as a list.
assert_eq "$(cd "$T/nock" && "$SH" "$home/bin/sdd" show 1 --json | jq -c '.tasks | map(.files)')" '[["src/a.go","src/b.go"]]'

# The base now commits an sdd that would write a marker, and a local/ override that would too.
cd "$R" || exit 1
printf '#!/bin/sh\n: >"%s"\n' "$T/pwned" >.sdd/bin/sdd
mkdir -p .sdd/local/cmd && printf ': >"%s"\n' "$T/pwned" >.sdd/local/cmd/ls.sh
git add -A && git commit -qm "a hostile sdd" && git push -q origin main
git -C "$T/nock" fetch -q origin && git -C "$T/nock" update-ref refs/heads/main refs/remotes/origin/main
got=$(nock_ls) || fail "ls in the no-checkout clone failed after the hostile commit: $got"
assert_eq "$(printf '%s\n' "$got" | jq -r '.id' | tr '\n' ' ')" '1 2 9 '
assert_no_file "$T/pwned"

# The fixture is armed: a full clone of the same base runs the repo's own copy.
(cd "$T/full" && git pull -q && sdd ls >/dev/null 2>&1)
assert_file "$T/pwned"
exit 0

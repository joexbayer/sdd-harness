# FR-2.1 ls across archive, local and remote branches; FR-2.2 phase with "?" for a
# teammate's branch; FR-2.3 show; FR-2.4 --json; FR-2.5 guidance comments ignored.
. "$SRC/tests/lib.sh"
new_repo

# facts <file> <id>: add a story, two requirements (one only in a comment), tasks, a
# decision and a question to the plan.
facts() {
	I=$2 awk '{ print }
		/^## What changes$/ {
			i = ENVIRON["I"]
			print "US-" i ".1 As a user I log in, so that I see my data."
			print "FR-" i ".1 WHEN asked THE SYSTEM SHALL log in,"
			print "and remember the device."
			print "  e.g. `login kari` → session"
			print "FR-" i ".2 IF the password is wrong THEN THE SYSTEM SHALL say so."
			print "<!-- FR-" i ".9 only guidance, not a requirement -->"
			print ""
			print "- [x] T-" i ".1 the form"
			print "- [ ] T-" i ".2 the session (files: src/a.go,  src/b.go ; test: go test)"
			print ""
			print "D-" i ".1 Use a cookie, because \"tokens\" leak."
			print "Q-" i ".1 Remember for how long? → recommend: 30 days"
		}' "$1" >"$1.tmp" && mv "$1.tmp" "$1"
}

# 1: shipped, so it comes from the archive on main.
sdd new feature "One" >/dev/null 2>&1
fill specs/changes/1-one/item.md plan && facts specs/changes/1-one/item.md 1
# Ship takes a tick only from task done (FR-15.7): untick T-1.1 and let task done tick it.
sed 's/^- \[x\] T-1.1 /- [ ] T-1.1 /' specs/changes/1-one/item.md >"$T/u" && cp "$T/u" specs/changes/1-one/item.md
sdd approve >/dev/null 2>&1 && fill specs/changes/1-one/item.md built
sdd task 'done' T-1.1 >/dev/null 2>&1 || fail "task done T-1.1 failed"
git commit -qam "feat(1): T-1.1 the form, built" && sdd check >/dev/null 2>&1 && sdd ship >/dev/null 2>&1 || fail "ship 1 failed"

# 2: open on a local branch, also pushed (local wins over origin).
git init -q --bare "$T/origin.git" && git remote add origin "$T/origin.git" && git push -q origin main
sdd new feature "Two" >/dev/null 2>&1
fill specs/changes/2-two/item.md plan && facts specs/changes/2-two/item.md 2
git commit -qam "plan 2" && git push -q origin HEAD
git switch -q main

# 3: a teammate's branch, approved and written up, known here only as origin/...
git clone -q "$T/origin.git" "$T/mate" && cd "$T/mate" || exit 1
sdd new feature "Three" >/dev/null 2>&1
f=$(ls specs/changes/*/item.md)
fill "$f" plan && sdd approve >/dev/null 2>&1 && fill "$f" built
git commit -qam "built 3" && git push -q origin HEAD
three=$(sed -n "s/^id: //p" "$f")
cd "$R" && git fetch -q origin

# 9: dropped, in the archive; its title line ends in CR (a CRLF edit), which JSON must escape.
git switch -q main
mkdir -p specs/archive/9-gone
printf -- '---\nid: 9\ntype: chore\ntitle: Gone\r\nstatus: dropped\n---\n# 9 Gone\n' >specs/archive/9-gone/item.md
git add -A && git commit -qm "drop 9"

out=$(sdd ls) || fail "ls failed: $out"
assert_contains "$out" '1    feature   shipped  done     FR 2   T 1/2    One'
assert_contains "$out" 'FR 2   T 1/2    Two   feature/2-two'
assert_contains "$out" "review?  FR 0   T -      Three   origin/feature/$three-three"
assert_not_contains "$out" 'origin/feature/2-two'
assert_not_contains "$out" 'Gone'
assert_contains "$(sdd ls --all)" 'dropped'
assert_eq "$(sdd ls --all --json | jq -r 'select(.id == 9) | .title')" "$(printf 'Gone\r')"

# --json: one object per line, fixed keys, counts equal to plain grep on the same file.
json=$(sdd ls --json)
assert_eq "$(printf '%s\n' "$json" | jq -s length)" 3
assert_eq "$(printf '%s\n' "$json" | jq -r 'select(.id == 2) | .source')" local
assert_eq "$(printf '%s\n' "$json" | jq -r 'select(.id == 2) | .tasks_done')" \
	"$(git show feature/2-two:specs/changes/2-two/item.md | grep -c '^- \[x\] T-')"
assert_eq "$(printf '%s\n' "$json" | jq -r 'select(.id == 1) | .frs')" \
	"$(grep -c '^FR-1\.[0-9]' specs/archive/1-one/item.md)"

# show: every fact with its ID first; continuation lines joined; example kept apart.
out=$(sdd show 2) || fail "show failed: $out"
assert_contains "$out" 'FR-2.1    WHEN asked THE SYSTEM SHALL log in, and remember the device.'
assert_contains "$out" 'e.g. `login kari` → session'
assert_contains "$out" 'T-2.2     [ ] the session'
assert_contains "$out" 'Q-2.1     [open] Remember for how long?'
assert_not_contains "$out" 'FR-2.9'
j=$(sdd show 2 --json) || fail "show --json failed"
assert_eq "$(printf '%s' "$j" | jq -r '.requirements | map(.id) | join(" ")')" 'FR-2.1 FR-2.2'
assert_eq "$(printf '%s' "$j" | jq -r '.decisions[0].text')" 'Use a cookie, because "tokens" leak.'
assert_eq "$(printf '%s' "$j" | jq -r '.tasks | map(.done) | join(" ")')" 'true false'
assert_eq "$(printf '%s' "$j" | jq -r '.questions[0].decided')" false
# FR-53.2: a task's files: split on commas and trimmed, [] without any.
assert_eq "$(printf '%s' "$j" | jq -c '.tasks | map(.files)')" '[[],["src/a.go","src/b.go"]]'

assert_eq "$(sdd show 1 --json | jq -r '.status')" shipped

# FR-53.1: two people's clones gave out id 12 (kari on feature/12-login, ola on fix/12-typo). ls
# keeps the row it shows today (the first source) and names the other branch.
cd "$T/mate" || exit 1
for b in feature/12-login:Login:kari fix/12-typo:Typo:ola; do
	br=${b%%:*} rest=${b#*:}
	tt=${rest%%:*} who=${rest#*:}
	d=specs/changes/12-${br#*/12-}
	git switch -q -c "$br" main && mkdir -p "$d"
	printf -- '---\nid: 12\ntype: %s\ntitle: %s\nstatus: open\n---\n# 12 %s\n' "${br%%/*}" "$tt" "$tt" >"$d/item.md"
	git add -A && git -c user.name="$who" commit -qm "docs(12): open ${br%%/*} \"$tt\"" && git push -q origin HEAD
	git switch -q main
done
cd "$R" && git fetch -q origin
json=$(sdd ls --json)
assert_eq "$(printf '%s\n' "$json" | jq -s 'map(select(.id == 12)) | length')" 1 "(one row for id 12)"
assert_eq "$(printf '%s\n' "$json" | jq -r 'select(.id == 12) | .branch + " " + .opened_by')" 'origin/feature/12-login kari'
assert_eq "$(printf '%s\n' "$json" | jq -r 'select(.id == 12) | .collides_with')" 'origin/fix/12-typo'
# The same item on a local branch and its remote is no collision.
assert_eq "$(printf '%s\n' "$json" | jq -r 'select(.id == 2) | .collides_with')" ''
assert_eq "$(sdd show 12 --json | jq -r '.collides_with')" 'origin/fix/12-typo'
assert_eq "$(sdd show 2 --json | jq -r '.collides_with')" ''
line=$(sdd ls | grep '^12 ')
case $line in *' · id also on origin/fix/12-typo') ;; *) fail "ls line for 12 should end with the collision: $line" ;; esac
assert_not_contains "$(sdd ls | grep '^2 ')" 'id also on'

sdd show 99 >/dev/null 2>&1
assert_eq $? 1 "(unknown id)"
sdd show >/dev/null 2>&1
assert_eq $? 2 "(usage)"
exit 0

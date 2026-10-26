# FR-5.1 boxed table, FR-5.2 default window, FR-5.3 --since/--last, FR-5.4 derived state,
# FR-5.5 who (teammates too), FR-5.6 --mine, FR-5.7 --md.
. "$SRC/tests/lib.sh"
new_repo
git init -q --bare "$T/origin.git" && git remote add origin "$T/origin.git"

# 1: shipped today.
sdd new feature "One" >/dev/null 2>&1
fill specs/changes/1-one/item.md plan && sdd approve >/dev/null 2>&1 && fill specs/changes/1-one/item.md built
git commit -qam built && sdd check >/dev/null 2>&1 && sdd ship >/dev/null 2>&1 || fail "ship 1 failed"
git push -q origin main

# 2: planning with two open questions and a title with non-ASCII letters.
sdd new feature "Blåbær planning, with a title long enough to wrap in its column" >/dev/null 2>&1
f=$(ls specs/changes/2-*/item.md)
fill "$f" plan
awk '{ print } /^## How$/ { print "Q-2.1 Which berries? → recommend: blue"; print "Q-2.2 How many? → recommend: many" }' "$f" >"$T/p" && cp "$T/p" "$f"
git commit -qam "plan 2" && git push -q origin HEAD
git switch -q main

# 3: a teammate's item, opened by kari and approved by lead, seen only as origin/...
git clone -q "$T/origin.git" "$T/mate" && cd "$T/mate" || exit 1
git config user.name kari
sdd new feature "Kari's thing" >/dev/null 2>&1
f=$(ls specs/changes/3-*/item.md)
fill "$f" plan && git -c user.name=lead commit -qam "plan 3"
git config user.name lead && sdd approve >/dev/null 2>&1 && git config user.name kari
git push -q origin HEAD
cd "$R" && git fetch -q origin

# 4: an open item last touched long ago.
GIT_AUTHOR_DATE=2001-01-01T12:00:00 GIT_COMMITTER_DATE=2001-01-01T12:00:00 sdd new chore "Old" >/dev/null 2>&1
git switch -q main

# FR-5.1 and FR-5.2: a box with a header; open items always, shipped ones from this week.
out=$(sdd summary) || fail "summary failed: $out"
assert_contains "$out" '┌'
assert_contains "$out" '│ item'
assert_contains "$out" '1 (One)'
assert_contains "$out" '4 (Old)'
widths=$(printf '%s\n' "$out" | LC_ALL=C awk '{ s = $0; gsub(/[\200-\277]/, "", s); print length(s) }' | sort -u)
assert_eq "$(printf '%s\n' "$widths" | wc -l | tr -d ' ')" 1 "(every line of the table has the same width, å included)"

# FR-5.4: the state is a sentence made of facts (a wide terminal, so cells do not wrap).
out=$(export COLUMNS=200; sdd summary)
assert_contains "$out" 'planning: 2 open questions; then approval'
assert_contains "$out" 'planning: to fill: What and why'
assert_contains "$out" 'shipped'

# FR-5.5: who opened and who approved, for a teammate's branch too.
assert_contains "$out" 'kari, approved by lead'

# FR-5.3: windows.
out=$(sdd summary --since today)
assert_not_contains "$out" '4 (Old)'
assert_contains "$out" '1 (One)'
assert_contains "$(sdd summary --since 2000-12-31)" '4 (Old)'
assert_contains "$(sdd summary --since 3d)" '2 (Blåbær'
assert_eq "$(sdd summary --last 1 --md | grep -c '^| [0-9]')" 1
assert_contains "$(sdd summary --since 2999-01-01)" 'nothing in this window'
sdd summary --since soon >/dev/null 2>&1
assert_eq $? 2 "(bad --since)"
sdd summary --last x >/dev/null 2>&1
assert_eq $? 2 "(bad --last)"

# Narrow terminals: the table fits when it can, and never hangs when it cannot.
w60=$( (export COLUMNS=60; sdd summary) | LC_ALL=C awk '{ s = $0; gsub(/[\200-\277]/, "", s); if (length(s) > m) m = length(s) } END { print m }')
assert_eq "$w60" 60 "(a 60-column terminal gets a 60-column table)"
(export COLUMNS=20; sdd summary >/dev/null) || fail "summary at 20 columns failed"
assert_contains "$(sdd summary --last 1 --since 2999-01-01 --md)" '| 3 ('
sdd summary --since 2026-13-01 >/dev/null 2>&1
assert_eq $? 2 "(month 13)"
assert_eq "$(sdd ls --json | jq -r 'select(.id == 2) | .reason_code')" approval

# FR-5.6: --mine keeps what the current git user opened or approved.
out=$(sdd summary --mine)
assert_not_contains "$out" 'kari'
assert_contains "$out" '1 (One)'

# FR-5.7: Markdown for PRs and chat; ASCII for plain terminals.
out=$(sdd summary --md)
assert_eq "$(printf '%s\n' "$out" | head -n 1)" '| item | state | who | when |'
assert_contains "$out" "| 3 (Kari's thing) |"
git switch -q feature/2-* 2>/dev/null || git switch -q "$(git branch --format='%(refname:short)' | grep '^feature/2-')"
sed 's/^title: .*/title: Pipes | in titles/' "$(ls specs/changes/2-*/item.md)" >"$T/t" && cp "$T/t" "$(ls specs/changes/2-*/item.md)"
assert_contains "$(sdd summary --md)" '2 (Pipes \| in titles)'
assert_contains "$(sdd summary --ascii)" '+---'
exit 0

# shellcheck shell=sh
# init: install into the current repo. Idempotent: never overwrites config or core.
[ $# -eq 0 ] || usage_die "usage: $NAME init"
need_repo

target="$ROOT/$DIRNAME"
if [ "$(cd "$target" 2>/dev/null && pwd -P)" != "$SDD_HOME" ]; then
	if [ -d "$target/core" ]; then
		echo "$NAME already installed in $DIRNAME/ ($(cat "$target/VERSION" 2>/dev/null)); left as is"
	else
		mkdir -p "$target"
		cp -R "$SDD_HOME/bin" "$SDD_HOME/core" "$SDD_HOME/VERSION" "$target/" || die "copy failed"
		echo "installed $NAME $(cat "$target/VERSION") into $DIRNAME/"
	fi
fi

detect_base() {
	_b=$(git symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null) && { echo "${_b#origin/}"; return; }
	for _b in main master; do
		git rev-parse -q --verify "refs/heads/$_b" >/dev/null && { echo "$_b"; return; }
	done
	current_branch || echo main
}

detect_checks() {
	[ -f go.mod ] && printf '%s\n' 'go vet ./...' 'go test ./...'
	[ -f Cargo.toml ] && echo 'cargo test'
	[ -f package.json ] && grep -q '"test"[[:space:]]*:' package.json && echo 'npm test'
	if [ -f Gemfile ]; then
		if [ -x bin/rails ]; then echo 'bin/rails test'; elif [ -d spec ]; then echo 'bundle exec rspec'; fi
	fi
	# python3 -m: pip often installs pytest without putting its script on PATH.
	{ [ -f pyproject.toml ] || [ -f pytest.ini ] || [ -f setup.py ]; } && echo 'python3 -m pytest'
	return 0
}

config="$target/config"
if [ ! -f "$config" ]; then
	git config -f "$config" sdd.profile lite
	git config -f "$config" sdd.mode solo
	git config -f "$config" sdd.base "$(detect_base)"
	checks=$(detect_checks)
	if [ -z "$checks" ] && [ -f Makefile ] && grep -q '^test:' Makefile; then checks='make test'; fi
	if [ -n "$checks" ]; then
		printf '%s\n' "$checks" | while IFS= read -r c; do git config -f "$config" --add check.run "$c"; done
		echo "checks: $(printf '%s\n' "$checks" | paste -sd ',' - | sed 's/,/, /g')"
	else
		warn "no test command detected: add 'run = <command>' under [check] in $DIRNAME/config"
	fi
	# Secret scanning, when gitleaks is installed: committed keys are the most common leak, and
	# agent-written commits leak more often. Optional by design (C-1); the team can remove it.
	if command -v gitleaks >/dev/null 2>&1; then
		git config -f "$config" --add check.run 'gitleaks dir . --no-banner'
		echo "checks: + gitleaks dir . (secret scanning)"
	else
		echo "tip     install gitleaks and add 'run = gitleaks dir . --no-banner' under [check] to catch committed secrets"
	fi
	echo "wrote $DIRNAME/config (profile lite, base $(git config -f "$config" sdd.base))"
fi

# Managed block in AGENTS.md, between markers; everything outside them is left alone.
start="<!-- $NAME:start -->"
end="<!-- $NAME:end -->"
block=$(cat <<EOF
$start
## Workflow: $NAME
This repo tracks changes with $NAME (\`$DIRNAME/\`). Before changing code, run \`$CMD next\` and follow it.
- One change = one item: \`$SPECS/changes/<id>-<slug>/item.md\` on its own branch.
- Humans plan and review; agents build. Plan with the human (no code), the human approves
  (\`$CMD approve\`), then build hands-off until \`$CMD check\` passes and \`## Built\` is written,
  then walk the human through \`$CMD review\`. Only the human approves, ships and deletes
  remote branches: run \`$CMD approve\`, \`$CMD ship\` or \`$CMD tidy --remote\` only when they ask.
- Start: \`$CMD new <$(types | paste -sd '|' -)> "title"\`
- Small changes (under ~20 lines, no behaviour change) need no item.
- Talking to the human: give every ID its name ("item 3 (constitution)", "FR-3.6 (feature
  branches can't edit it)"), keep it short and plain, and explain terms instead of assuming.
$end
EOF
)
if [ ! -f AGENTS.md ]; then
	printf '%s\n' "$block" >AGENTS.md
	echo "created AGENTS.md"
elif grep -qxF "$start" AGENTS.md; then
	B=$block S=$start E=$end awk '
		$0 == ENVIRON["S"] { print ENVIRON["B"]; skip = 1; next }
		skip && $0 == ENVIRON["E"] { skip = 0; next }
		!skip { print }' AGENTS.md >AGENTS.md.tmp && mv AGENTS.md.tmp AGENTS.md
else
	printf '\n%s\n' "$block" >>AGENTS.md
	echo "added the $NAME block to AGENTS.md"
fi

# A GitHub origin: suggest shipping through pull requests (the team decides, in the committed config).
case $(git remote get-url origin 2>/dev/null) in
*github.com[:/]*)
	git config -f "$target/config" --get sdd.forge >/dev/null ||
		echo "tip     origin is on GitHub: add 'forge = github' under [sdd] in $DIRNAME/config to ship through pull requests"
	;;
esac
echo "next: $CMD new <type> \"title\"   (optional: $CMD sync <$(agents | paste -sd '|' -)>)"

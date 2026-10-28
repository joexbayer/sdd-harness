# shellcheck shell=sh
# shellcheck disable=SC2034 # variables set here are read by the commands
# Shared helpers, sourced by bin/sdd before every command.
# SDD_HOME (the installed folder, e.g. <repo>/.sdd) is set by bin/sdd.

# The tool's name is defined here and only here; folder, markers and paths derive from it
# or from where the tool is installed.
NAME=sdd
SPECS=specs
DIRNAME=${SDD_HOME##*/}
CMD="$DIRNAME/bin/$NAME"
PHASE_FP=
PHASE_REF=

die() { printf '%s: %s\n' "$NAME" "$*" >&2; exit 1; }
usage_die() { printf '%s: %s\n' "$NAME" "$*" >&2; exit 2; }
warn() { printf '%s: warning: %s\n' "$NAME" "$*" >&2; }
joinlist() { printf '%s\n' "$1" | paste -sd ',' - | sed 's/,/, /g'; }

# need_repo: cd to the repository root and set ROOT and ST (machine-local state dir,
# shared by all worktrees of the clone, never committed).
need_repo() {
	ROOT=$(git rev-parse --show-toplevel 2>/dev/null) || die "not inside a git repository"
	cd "$ROOT" || exit 1
	ST="$(git rev-parse --path-format=absolute --git-common-dir)/$NAME"
	mkdir -p "$ST/checks"
	cfg_load
}

# --- paths and config -------------------------------------------------------------

# sdd_path <path>: a file under local/ wins over the same path under core/.
sdd_path() {
	if [ -e "$SDD_HOME/local/$1" ]; then
		printf '%s\n' "$SDD_HOME/local/$1"
	elif [ -e "$SDD_HOME/core/$1" ]; then
		printf '%s\n' "$SDD_HOME/core/$1"
	else
		return 1
	fi
}

user_config() { printf '%s\n' "${XDG_CONFIG_HOME:-$HOME/.config}/$NAME/config"; }

# cfg_load: read the three config files once, into CFG_TAB: lines "<n> <key>=<value>" as
# `git config --list` prints them (git parses the files), n = 1 project, 2 user, 3 core. cfg,
# cfg_all, cfg_every and cfg_mine look keys up there instead of running git each time; before
# need_repo has loaded it (CFG_ON empty) they read the files.
CFG_TAB=
CFG_ON=
cfg_load() {
	CFG_TAB=$(
		_n=0
		for _f in "$SDD_HOME/config" "$(user_config)" "$SDD_HOME/core/config"; do
			_n=$((_n + 1))
			[ -f "$_f" ] || continue
			echo "#$_n"
			git config -f "$_f" --list
		done | awk '/^#[123]$/ { n = substr($0, 2); next } { print n " " $0 }')
	CFG_ON=1
}

# cfg_tab <get|all|every> <key> <files>: look <key> up in CFG_TAB, in the files listed (e.g.
# "123", in lookup order). get: the last value in the first file that has it (git config --get);
# all: every value in the first file that has any (--get-all); every: every value in each file in
# turn. Fails when no file has it. Sections and names compare case-insensitively, as in git.
cfg_tab() {
	CFG_TAB=$CFG_TAB M=$1 K=$2 F=$3 awk '
	function norm(k,   a, b) {
		a = index(k, "."); b = k; sub(/.*[.]/, "", b)
		return a ? tolower(substr(k, 1, a - 1)) substr(k, a, length(k) - a - length(b) + 1) tolower(b) : k
	}
	BEGIN {
		k = norm(ENVIRON["K"]); m = ENVIRON["M"]; fs = ENVIRON["F"]
		n = split(ENVIRON["CFG_TAB"], l, "\n")
		for (i = 1; i <= n; i++) {
			r = substr(l[i], 3); e = index(r, "=")
			if ((e ? substr(r, 1, e - 1) : r) != k) continue
			f = substr(l[i], 1, 1); v = e ? substr(r, e + 1) : ""
			c[f]++; last[f] = v; all[f] = all[f] v "\n"
		}
		for (j = 1; j <= length(fs); j++) {
			f = substr(fs, j, 1)
			if (!c[f]) continue
			found = 1
			if (m == "get") { print last[f]; exit }
			printf "%s", all[f]
			if (m == "all") exit
		}
		exit !found
	}'
}

# cfg <key> [default]: first hit in project, user, core config (git-config format).
cfg() {
	if [ -n "$CFG_ON" ]; then
		cfg_tab get "$1" 123 && return 0
	else
		for _f in "$SDD_HOME/config" "$(user_config)" "$SDD_HOME/core/config"; do
			[ -f "$_f" ] && git config -f "$_f" --get "$1" && return 0
		done
	fi
	[ $# -gt 1 ] && printf '%s\n' "$2" && return 0
	return 1
}

# cfg_all <key>: all values of a multi-valued key, from the first file that has any.
cfg_all() {
	[ -z "$CFG_ON" ] || { cfg_tab all "$1" 123; return; }
	for _f in "$SDD_HOME/config" "$(user_config)" "$SDD_HOME/core/config"; do
		[ -f "$_f" ] && git config -f "$_f" --get-all "$1" && return 0
	done
	return 1
}

# cfg_every <key>: every value of a multi-valued key from core, user and project config
# together: a list that adds up, unlike cfg_all, where the first file with any wins.
cfg_every() {
	[ -z "$CFG_ON" ] || { cfg_tab every "$1" 321; return 0; }
	for _f in "$SDD_HOME/core/config" "$(user_config)" "$SDD_HOME/config"; do
		[ -f "$_f" ] && git config -f "$_f" --get-all "$1"
	done
	return 0
}

# tier_file <tier>: the one config file that defines the tier (sets its agent), the developer's
# own first, then the project's. A tier is read whole from that file: a project's args for one
# agent never reach a developer who maps the tier to another (D-16.1).
tier_file() {
	for _f in "$(user_config)" "$SDD_HOME/config" "$SDD_HOME/core/config"; do
		[ -f "$_f" ] && git config -f "$_f" --get "tier.$1.agent" >/dev/null && { printf '%s\n' "$_f"; return 0; }
	done
	return 1
}

# tier_get <tier> <key>: one setting of the tier, from its file (tier_file).
tier_get() { _tf=$(tier_file "$1") && git config -f "$_tf" --get "tier.$1.$2"; }

# tier_ok <agent> <model>: names safe to use as a file name and inside YAML: an agent is a word,
# a model has no spaces, quotes or newlines.
tier_ok() {
	case $1 in '' | *[!a-z0-9-]*) return 1 ;; esac
	case $2 in '' | *[!A-Za-z0-9._:/@[\]-]*) return 1 ;; esac
}

# cfg_mine <key> [default]: a tier or agent setting, the developer's own config first, then the
# project's: the team names roles, each developer chooses the agent and model behind them.
cfg_mine() {
	if [ -n "$CFG_ON" ]; then
		cfg_tab get "$1" 213 && return 0
	else
		for _f in "$(user_config)" "$SDD_HOME/config" "$SDD_HOME/core/config"; do
			[ -f "$_f" ] && git config -f "$_f" --get "$1" && return 0
		done
	fi
	[ $# -gt 1 ] && printf '%s\n' "$2"
}

# types: every type with a template (core or local).
types() {
	for _d in "$SDD_HOME/core/templates" "$SDD_HOME/local/templates"; do
		[ -d "$_d" ] && ls "$_d"
	done | sed -n 's/\.md$//p' | sort -u
}

# gate_level <gate> <type>: off, warn or block. Off unless the type lists the gate;
# a per-type level beats the profile's level.
gate_level() {
	case " $(cfg "type.$2.gates" || cfg sdd.gates 'planned approved check built') " in
	*" $1 "*) ;;
	*) echo off && return 0 ;;
	esac
	cfg "type.$2.$1" || cfg "profile.$(cfg sdd.profile lite).$1" off
}

# --- text helpers -----------------------------------------------------------------

# render <file> <id> <title> <type>: substitute {{id}} {{title}} {{type}} {{date}}
# {{cmd}} {{base}} {{name}} literally (no regex, so titles may contain any character).
render() {
	R_ID=$2 R_TITLE=$3 R_TYPE=$4 R_DATE=$(date +%F) R_CMD=$CMD R_BASE=$(cfg sdd.base main) R_NAME=$NAME \
		awk '
	function repl(s, from, to,   out, i) {
		out = ""
		while ((i = index(s, from)) > 0) { out = out substr(s, 1, i - 1) to; s = substr(s, i + length(from)) }
		return out s
	}
	{
		$0 = repl($0, "{{id}}", ENVIRON["R_ID"]); $0 = repl($0, "{{title}}", ENVIRON["R_TITLE"])
		$0 = repl($0, "{{type}}", ENVIRON["R_TYPE"]); $0 = repl($0, "{{date}}", ENVIRON["R_DATE"])
		$0 = repl($0, "{{cmd}}", ENVIRON["R_CMD"]); $0 = repl($0, "{{base}}", ENVIRON["R_BASE"])
		$0 = repl($0, "{{name}}", ENVIRON["R_NAME"])
		print
	}' "$1"
}

slugify() {
	printf '%s' "$1" | LC_ALL=C tr '[:upper:]' '[:lower:]' |
		LC_ALL=C sed 's/[^a-z0-9][^a-z0-9]*/-/g; s/^-//' | cut -c1-40 | sed 's/-*$//'
}

# fm_get <key> [file]: value of a frontmatter key (file defaults to stdin).
fm_get() {
	K=$1 awk '
	NR == 1 { if ($0 != "---") exit; next }
	$0 == "---" { exit }
	{ i = index($0, ":"); if (i && substr($0, 1, i - 1) == ENVIRON["K"]) { v = substr($0, i + 1); sub(/^[ \t]+/, "", v); print v; exit } }
	' "${2:--}"
}

# fm_closed <file>: the file starts with a frontmatter block that a second --- closes.
fm_closed() { awk 'NR == 1 { if ($0 != "---") exit 1; next } $0 == "---" { ok = 1; exit } END { exit !ok }' "$1"; }
FM_OPEN="the --- block at the top is not closed; add --- after its last key"

# fm_set <file> <key> <value>: set (or add) a frontmatter key in place. Fails, leaving the
# file as it was, when the block is not closed (a new key would have nowhere to go).
fm_set() {
	_tmp="$1.tmp.$$"
	K=$2 V=$3 awk '
	NR == 1 && $0 == "---" { infm = 1; print; next }
	infm && $0 == "---" { if (!done) print ENVIRON["K"] ": " ENVIRON["V"]; infm = 0; print; next }
	infm { i = index($0, ":"); if (i && substr($0, 1, i - 1) == ENVIRON["K"]) { print ENVIRON["K"] ": " ENVIRON["V"]; done = 1; next } }
	{ print }
	END { if (infm) exit 3 }
	' "$1" >"$_tmp" && mv "$_tmp" "$1" || { rm -f "$_tmp"; return 1; }
}

# uncomment [file]: the text with HTML comments (template guidance) removed.
uncomment() {
	awk '{
		line = $0; out = ""
		while (length(line) > 0) {
			if (inc) {
				e = index(line, "-->"); if (!e) { line = ""; break }
				line = substr(line, e + 3); inc = 0
			} else {
				s = index(line, "<!--"); if (!s) { out = out line; break }
				out = out substr(line, 1, s - 1); line = substr(line, s + 4); inc = 1
			}
		}
		print out
	}' "${1:--}"
}

# An item has two parts. The plan is everything above "## Built" (what the human approves);
# "## Built" and below is written by the agent at the end of the build, for review.

# missing_sections <file> <plan|built>: required "## " sections of that part with no
# content. Sections marked "(optional)" are never required. Below "## Built" only
# "## Review" starts a new section: agents put their own "## " headings inside Built.
missing_sections() {
	uncomment "$1" | P=$2 awk '
	function flush() { if (name != "" && want && !optional && !filled) print name }
	built && /^## / && $0 !~ /^## Review/ { next }
	/^## / {
		flush(); name = substr($0, 4)
		if (name == "Built") built = 1
		want = (ENVIRON["P"] == "built") ? built : !built
		optional = (name ~ /\(optional\)/); filled = 0; next
	}
	name != "" && $0 ~ /[^ \t]/ { filled = 1 }
	END { flush() }'
}

# plan_part <file>: the body above "## Built" (frontmatter excluded).
plan_part() {
	awk 'NR == 1 && $0 == "---" { fm = 1; next } fm { if ($0 == "---") fm = 0; next } $0 == "## Built" { exit } { print }' "$1"
}

# plan_hash <file>: what approval pins. Task boxes count as unticked: sdd ticks them as tasks pass
# (task done), which must not void the approval; every other plan edit does.
plan_hash() { plan_part "$1" | sed 's/^- \[[xX]\] T-/- [ ] T-/' | git hash-object --stdin; }

# approval_ok: approved, and the plan has not changed since.
approval_ok() {
	_ap=$(fm_get approved "$IFILE")
	[ -n "$_ap" ] && [ "${_ap%% *}" = "$(plan_hash "$IFILE")" ]
}

# plan_frs: the requirement ids (FR-<id>.<n>) written in the plan, guidance excluded.
plan_frs() {
	plan_part "$IFILE" | uncomment | grep -oE "FR-$ID\.[0-9]+" | sort -u -t . -k 2,2n
}

# --- git helpers ------------------------------------------------------------------

current_branch() { git symbolic-ref --quiet --short HEAD 2>/dev/null; }

# main_root: the main checkout's folder (first in `git worktree list`), from any worktree.
main_root() { git worktree list --porcelain | awk '/^worktree / { print substr($0, 10); exit }'; }

# worktree_of <branch>: the folder where <branch> is checked out, if any.
worktree_of() {
	git worktree list --porcelain | awk -v b="refs/heads/$1" '
		/^worktree / { w = substr($0, 10) } $0 == "branch " b { print w; exit }'
}

# worktree_path <id>: where an item's worktree goes: ../<repo>.<id>, next to the main checkout.
worktree_path() { _m=$(main_root) && printf '%s/%s.%s\n' "$(dirname "$_m")" "$(basename "$_m")" "$1"; }

# sync_here: give this (new) worktree the agents synced in the clone, as `sync` would. ROOT
# is this worktree for the sync, so its absolute-path ask rules name this folder.
sync_here() {
	[ -f "$ST/agents" ] || return 0
	(
		ROOT=$(pwd -P)
		while IFS= read -r _a; do sync_agent "$_a" >/dev/null || warn "sync $_a failed in $ROOT"; done <"$ST/agents"
	)
}

# id_of <branch-or-dir>: the item id from "<anything>/<id>-<slug>", else fails.
id_of() {
	_last=${1##*/}
	_id=${_last%%-*}
	case $_id in '' | *[!0-9]*) return 1 ;; esac
	[ "$_id" != "$_last" ] || return 1
	printf '%s\n' "$_id"
}

# current_item: the item comes from the branch name only (no pointer file).
# Sets ID, IDIR, IFILE, BRANCH, ITYPE, and IPR when the item was shipped into a PR: archived on
# this branch (by ship with a forge) but not yet on the base.
current_item() {
	BRANCH=$(current_branch) || return 1
	ID=$(id_of "$BRANCH") || return 1
	IPR=
	for _d in "$SPECS/changes/$ID"-*; do
		if [ -f "$_d/item.md" ]; then
			IDIR=$_d
			IFILE=$_d/item.md
			ITYPE=$(fm_get type "$IFILE")
			return 0
		fi
	done
	for _d in "$SPECS/archive/$ID"-*; do
		if [ -f "$_d/item.md" ] && ! git cat-file -e "$(cfg sdd.base main):$_d/item.md" 2>/dev/null; then
			IDIR=$_d
			IFILE=$_d/item.md
			ITYPE=$(fm_get type "$IFILE")
			IPR=1
			return 0
		fi
	done
	return 1
}

# fingerprint: tree hash of the code in the working tree (untracked files included,
# specs/ excluded: writing the plan or Built does not invalidate a check). Uses a
# temporary copy of the index so the real index is never touched.
fingerprint() {
	_idx=$(mktemp "${TMPDIR:-/tmp}/$NAME-index.XXXXXX") || return 1
	_real=$(git rev-parse --path-format=absolute --git-path index)
	if [ -f "$_real" ]; then cp "$_real" "$_idx"; else rm -f "$_idx"; fi
	GIT_INDEX_FILE=$_idx git add -A >/dev/null 2>&1
	GIT_INDEX_FILE=$_idx git rm -r -q --cached --ignore-unmatch -- "$SPECS" >/dev/null 2>&1
	GIT_INDEX_FILE=$_idx git write-tree
	_rc=$?
	rm -f "$_idx"
	return $_rc
}

# code_changed: does this branch change anything outside specs/ (committed, staged,
# unstaged or untracked) compared with where it left the base branch?
code_changed() {
	_mb=$(git merge-base "$(cfg sdd.base main)" HEAD 2>/dev/null) || _mb=HEAD
	{
		git diff --name-only "$_mb"
		git ls-files --others --exclude-standard
	} | grep -v "^$SPECS/" | grep -q .
}

# next_id: allocate an item id, unique across all worktrees of this clone.
next_id() {
	_lock="$ST/lock"
	_n=0
	until mkdir "$_lock" 2>/dev/null; do
		_n=$((_n + 1))
		[ $_n -gt 100 ] && die "id lock busy: $_lock (remove it if no $NAME is running)"
		sleep 0.1
	done
	_last=$(cat "$ST/next-id" 2>/dev/null || echo 0)
	_seen=$(max_seen_id)
	[ "$_seen" -gt "$_last" ] && _last=$_seen
	_id=$((_last + 1))
	echo "$_id" >"$ST/next-id"
	rmdir "$_lock"
	echo "$_id"
}

# max_seen_id: highest id among item branches (local and remote, matched against the
# configured branch templates) and item folders in specs/.
max_seen_id() {
	_types=$(types | paste -sd '|' -)
	_re=$({
		cfg sdd.branch '{type}/{id}-{slug}'
		for _t in $(types); do cfg "type.$_t.branch"; done
	} | sort -u | sed "s/[.]/[.]/g; s/{type}/($_types)/g; s/{id}/[0-9]+/g; s/{slug}/[a-z0-9-]+/g" | paste -sd '|' -)
	{
		{
			git for-each-ref --format='%(refname:lstrip=2)' refs/heads
			git for-each-ref --format='%(refname:lstrip=3)' refs/remotes
		} | grep -E "^($_re)\$"
		for _d in "$SPECS"/changes/* "$SPECS"/archive/*; do [ -d "$_d" ] && echo "${_d##*/}"; done
	} | while IFS= read -r _b; do id_of "$_b"; done | awk '$1 + 0 > m { m = $1 + 0 } END { print m + 0 }'
}

# --- phase and checks -------------------------------------------------------------

# check_record <id> <fingerprint> <result>
check_record() {
	printf 'fp=%s\nresult=%s\nat=%s\n' "$2" "$3" "$(date '+%Y-%m-%d %H:%M')" >"$ST/checks/$1"
}

# check_passed_here <id> [fingerprint]: did a check pass for exactly this code?
check_passed_here() {
	_rec="$ST/checks/$1"
	[ -f "$_rec" ] || return 1
	_fp=${2:-$(fingerprint)}
	grep -qx "fp=$_fp" "$_rec" && grep -qx 'result=pass' "$_rec"
}

# phase_check_passed: check_passed_here for the code item_phase judges: the working tree, or the
# committed code of the ref the item was read from (PHASE_REF, see item_load), fingerprinted only
# when a check was recorded for the item at all.
phase_check_passed() {
	[ -f "$ST/checks/$ID" ] || return 1
	[ -z "${PHASE_REF:-}" ] || [ -n "$PHASE_FP" ] ||
		PHASE_FP=$(git ls-tree "$PHASE_REF" | S=$SPECS awk -F '\t' '$2 != ENVIRON["S"]' | git mktree)
	check_passed_here "$ID" ${PHASE_FP:+"$PHASE_FP"}
}

# item_phase: sets PHASE (plan|build|review|done), WHY (one line for people), TASK (the current task,
# in build), WHYCODE (the same
# as a stable word for programs: frontmatter|status|fill|approval|changed|task|check|built|ready)
# and MISSING.
#   plan    the human's time: header not closed, plan empty, or not (or no longer) approved
#   build   the agent's time: no passing check for this code, or "## Built" empty
#   review  the human's time: verified and written up
item_phase() {
	WHY=
	TASK=
	WHYCODE=
	MISSING=$(missing_sections "$IFILE" plan)
	if ! fm_closed "$IFILE"; then
		PHASE=plan
		WHY="item.md: $FM_OPEN"
		WHYCODE=frontmatter
	elif [ -n "${IPR:-}" ]; then
		PHASE='pr'
		WHY="shipped into a pull request, waiting to merge: $CMD ship merges it"
		WHYCODE='pr'
	elif [ "$(fm_get status "$IFILE")" != open ]; then
		PHASE='done'
		WHY="status: $(fm_get status "$IFILE")"
		WHYCODE=status
	elif [ -n "$MISSING" ]; then
		PHASE=plan
		WHY="to fill: $(joinlist "$MISSING")"
		WHYCODE=fill
	elif [ "$(gate_level approved "$ITYPE")" = block ] && ! approval_ok; then
		PHASE=plan
		if [ -n "$(fm_get approved "$IFILE")" ]; then
			WHY="the plan changed after approval; the human re-approves with: $CMD approve"
			WHYCODE=changed
		else
			WHY="waiting for the human to approve the plan: $CMD approve"
			WHYCODE=approval
		fi
	else
		# Open tasks come first: the builder works them in order (task done ticks them).
		_t=$(task_rows | awk -F '\t' '$2 == "open" && !f { f = $1 "\t" $3 } END { if (f != "") print f "\t" NR }')
		MISSING=$(missing_sections "$IFILE" built)
		if [ -n "$_t" ]; then
			PHASE=build
			WHY="task $(tsv 1 "$_t") of $(tsv 3 "$_t"): $(tsv 2 "$_t")"
			WHYCODE=task
			TASK=$(tsv 1 "$_t")
		elif [ "$(gate_level check "$ITYPE")" != off ] && ! phase_check_passed; then
			PHASE=build
			WHY="no passing check for the current code"
			WHYCODE=check
		elif [ -n "$MISSING" ]; then
			PHASE=build
			WHY="\"## Built\" is not written yet"
			WHYCODE=built
		else
			PHASE=review
			WHY="verified and written up; walk through it with: $CMD review"
			WHYCODE=ready
		fi
	fi
}

# task_rows: the current item's tasks (IFILE, ID), one per line, in plan order:
# "<task id>\t<open|done>\t<what>\t<files>\t<test>\t<expect>\t<FR ids>\t<bad>". <bad> is 1 when the
# line has attributes that do not end it (a wrapped line, words after them): sdd must not guess.
# Attributes sit in a final "(files: …; test: …; expect: fail)"; a value runs to the next
# "; <key>:", so a test command may contain ";" and parentheses.
task_rows() {
	parse_item "$IFILE" "$ID" | awk -F '\t' -v OFS='\t' '
		$1 != "task" || $2 !~ /^T-[0-9]+\.[0-9]+$/ { next }
		{
			txt = $4; what = txt; files = ""; test = ""; expect = ""; frs = ""; bad = 0
			p = 0
			for (k = 1; k <= 3; k++) {
				key = (k == 1 ? "files:" : k == 2 ? "test:" : "expect:")
				i = index(txt, " (" key); if (i && (p == 0 || i < p)) p = i
			}
			if (p && substr(txt, length(txt)) != ")") bad = 1
			if (p && substr(txt, length(txt)) == ")") {
				what = substr(txt, 1, p - 1); a = "; " substr(txt, p + 2, length(txt) - p - 2)
				n = 0
				while (match(a, /; (files|test|expect): /)) {
					if (n) val[n] = substr(a, 1, RSTART - 1)
					kk = substr(a, RSTART + 2, RLENGTH - 4); a = substr(a, RSTART + RLENGTH); n++; name[n] = kk
				}
				if (n) val[n] = a
				for (j = 1; j <= n; j++) {
					if (name[j] == "files") files = val[j]; else if (name[j] == "test") test = val[j]; else expect = val[j]
				}
			}
			s = what
			while (match(s, /FR-[0-9]+\.[0-9]+/)) { frs = frs (frs == "" ? "" : " ") substr(s, RSTART, RLENGTH); s = substr(s, RSTART + RLENGTH) }
			sub(/(,? FR-[0-9]+\.[0-9]+)+[ ,]*$/, "", what); sub(/[ ,]+$/, "", what)
			print $2, $3, what, files, test, expect, frs, bad
		}'
}

# task_commit <task id>: the newest commit on this branch (since the base) whose subject names
# the task, as a whole ID: T-4.1 is not T-4.10.
task_commit() {
	git log --format='%h %s' "$(cfg sdd.base main)..HEAD" 2>/dev/null |
		T=$1 awk '{ s = " " substr($0, index($0, " ") + 1) " "; t = ENVIRON["T"]
			while ((i = index(s, t)) > 0) {
				if (substr(s, i - 1, 1) !~ /[A-Za-z0-9.-]/ && substr(s, i + length(t), 1) !~ /[0-9]/) { print $1; exit }
				s = substr(s, i + length(t))
			} }'
}

# usage_on: usage tracking is switched on ([usage] track = true, yours or the project's); off by
# default, so nothing about runs is kept unless someone asks for it.
usage_on() { [ "$(cfg_mine usage.track false)" = true ]; }

# run_slot: a new run number and its folder .git/sdd/runs/<n>/ (mkdir is the lock); sets RUN, RUNDIR.
# With tracking off, a temporary folder that the caller removes (RUN is "-").
run_slot() {
	if ! usage_on; then
		RUN=-
		RUNDIR=$(mktemp -d "${TMPDIR:-/tmp}/$NAME-run.XXXXXX") || die "could not make a temporary folder"
		return 0
	fi
	mkdir -p "$ST/runs"
	RUN=1
	while ! mkdir "$ST/runs/$RUN" 2>/dev/null; do RUN=$((RUN + 1)); done
	RUNDIR="$ST/runs/$RUN"
}

# run_log <run> <started> <item> <role> <agent> <model> <phase> <task> <in> <out> <cost> <seconds>
# <exit> <verdict>: one line in this clone's .git/sdd/runs.tsv (usage.sh reads these columns) when
# tracking is on; printed for people either way.
run_log() {
	_line=$(printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s' "$@")
	if usage_on; then
		[ -s "$ST/runs.tsv" ] ||
			printf '# run\tstarted\titem\trole\tagent\tmodel\tphase\ttask\tin\tout\tcost\tseconds\texit\tverdict\n' >"$ST/runs.tsv"
		printf '%s\n' "$_line" >>"$ST/runs.tsv"
	fi
	printf '%s\n' "$_line" | awk -F '\t' '
		function k(x) { return x == "" ? "?" : x >= 1000 ? sprintf("%.0fk", x / 1000) : x }
		{ printf "run %s · %s · %s %s · item %s%s · %s in / %s out%s · %ss · exit %s · %s\n", $1, $4, $5, $6, $3,
			($8 == "" ? "" : " " $8), k($9), k($10), ($11 == "" ? "" : sprintf(" · $%.4f", $11)), $12, $13, ($14 == "" ? "-" : $14) }'
}

# masked: the input lines that hide a failure ("cmd || true", "|| :", "|| exit 0").
masked() { grep -E '\|\|[[:space:]]*(true|:|exit[[:space:]]+0)([[:space:];]|$)'; }

# run_check <id>: run every check.run command from the repo root, stdin closed. Exit 0
# pass, 1 fail, 3 when the output shows zero tests ran. Records the result for <id> (if
# given) and sets CHECK_LOG, CHECK_NOTRUN to the first command the shell could not run, and
# CHECK_DIRTIED to the files the run itself created or changed (the pass is for the code before),
# and CHECK_ARTICLES to the constitution's problems (see check_articles).
run_check() {
	_cmds=$(cfg_all check.run) || die "no check configured: add 'run = <command>' under [check] in $DIRNAME/config"
	_bad=$(printf '%s\n' "$_cmds" | masked)
	[ -z "$_bad" ] || die "refusing a check that hides failures: $_bad"
	_fp=$(fingerprint)
	CHECK_LOG="$ST/checks/${1:-none}.log"
	: >"$CHECK_LOG"
	_rc=0
	CHECK_NOTRUN=
	while IFS= read -r _c; do
		[ -n "$_c" ] || continue
		printf '$ %s\n' "$_c" >>"$CHECK_LOG"
		sh -c "$_c" </dev/null >>"$CHECK_LOG" 2>&1
		_e=$?
		[ $_e -eq 0 ] || { _rc=1; printf '[exit %s]\n' "$_e" >>"$CHECK_LOG"; }
		case $_e in 126 | 127) [ -n "$CHECK_NOTRUN" ] || CHECK_NOTRUN=$_c ;; esac
	done <<EOF
$_cmds
EOF
	check_articles "$CHECK_LOG" || _rc=1
	CHECK_DIRTIED=
	_fp2=$(fingerprint)
	[ "$_fp2" = "$_fp" ] || CHECK_DIRTIED=$(git diff-tree -r --name-only "$_fp" "$_fp2" 2>/dev/null)
	if [ $_rc -eq 0 ]; then
		_pats=$(cfg_all check.no-tests || true)
		if [ -n "$_pats" ] && printf '%s\n' "$_pats" | grep -Eqi -f /dev/stdin "$CHECK_LOG" 2>/dev/null; then
			_rc=3
		fi
	fi
	if [ -n "${1:-}" ]; then
		case $_rc in 0) check_record "$1" "$_fp" pass ;; 1) check_record "$1" "$_fp" fail ;; *) check_record "$1" "$_fp" empty ;; esac
	fi
	return $_rc
}

# --- agents -----------------------------------------------------------------------

# sync_agent <agent>: install per-developer glue for one agent (see agents/<agent>.sh).
sync_agent() {
	_a=$(sdd_path "agents/$1.sh") || usage_die "unknown agent: $1 (agents: $(agents | tr '\n' ' '))"
	(
		# shellcheck source=/dev/null
		. "$_a"
		agent_sync
	)
}

# install_skills <dir> <agent>: one skill per step, <dir>/<name>-<step>/SKILL.md, from
# agents/skills/<step>.md plus <step>.<agent>.md (that agent's tool hints), kept out of git.
# Only folders sdd made (marked <name>-managed) are replaced; a user's own skill stays.
install_skills() {
	for _st in $(ls "$SDD_HOME/core/agents/skills" | sed -n 's/^\([a-z0-9-]*\)\.md$/\1/p'); do
		_f="$1/$NAME-$_st/SKILL.md"
		if [ -f "$_f" ] && ! grep -q "^<!-- $NAME-managed:" "$_f"; then
			warn "left $_f alone: it was not made by $NAME"
			continue
		fi
		mkdir -p "${_f%/SKILL.md}"
		{
			render "$(sdd_path "agents/skills/$_st.md")" '' '' ''
			if _h=$(sdd_path "agents/skills/$_st.$2.md"); then echo; render "$_h" '' '' ''; fi
		} >"$_f.tmp.$$" && mv "$_f.tmp.$$" "$_f" || { rm -f "$_f.tmp.$$"; die "could not write $_f"; }
		exclude "${_f%/SKILL.md}"
	done
}

agents() {
	for _d in "$SDD_HOME/core/agents" "$SDD_HOME/local/agents"; do
		[ -d "$_d" ] && ls "$_d"
	done | sed -n 's/^\([a-z0-9-]*\)\.sh$/\1/p' | sort -u
}

# json_num <key> <json line>, json_str <key> <json line>: the first "<key>": value in one line
# of an agent's JSON output (numbers; strings without escaped quotes), or nothing. The first,
# because totals come before their parts (claude's usage, then usage.iterations[]). awk only (C-1):
# enough for the few flat fields sdd reads from an agent's final line.
json_num() {
	K=$1 awk '{ i = index($0, "\"" ENVIRON["K"] "\":"); if (!i) exit
		s = substr($0, i + length(ENVIRON["K"]) + 3); sub(/^[ \t]*/, "", s)
		if (match(s, /^[0-9][0-9.eE+-]*/)) print substr(s, 1, RLENGTH); exit }' <<EOF
$2
EOF
}
json_str() {
	K=$1 awk '{ i = index($0, "\"" ENVIRON["K"] "\":"); if (!i) exit
		s = substr($0, i + length(ENVIRON["K"]) + 3); sub(/^[ \t]*/, "", s)
		if (substr(s, 1, 1) == "\"") { s = substr(s, 2); print substr(s, 1, index(s, "\"") - 1) }; exit }' <<EOF
$2
EOF
}

# exclude <path>: keep a generated file out of git for this clone only.
exclude() {
	_ex=$(git rev-parse --path-format=absolute --git-path info/exclude)
	mkdir -p "$(dirname "$_ex")"
	grep -qxF "/$1" "$_ex" 2>/dev/null || printf '/%s\n' "$1" >>"$_ex"
}

# --- query (ls, show) -------------------------------------------------------------
# Every reader (ls, show, and later the MCP server through `--json`) goes through these, so
# the item grammar is parsed in one place. Items are read with `git show`, never a checkout.

# forge_load: load core/forges/<forge>.sh when the project sets `forge` under [sdd]; fails when
# none is set. The forge file defines forge_ready, forge_pr_list, forge_pr_state and the rest.
forge_load() {
	_fg=$(cfg sdd.forge) || return 1
	_ff=$(sdd_path "forges/$_fg.sh") || die "unknown forge: $_fg (set under [sdd] in $DIRNAME/config)"
	# shellcheck source=/dev/null
	. "$_ff"
}

# tsv <n> <line>: field n of a tab-separated line. Not `IFS=<tab> read`: tabs count as
# whitespace there, so an empty field (a PR with no review yet) would shift the rest.
tsv() { printf '%s\n' "$2" | cut -f "$1"; }

# AWK_PR: an awk function for a forge's PR line (see core/forges/): pr_words() puts its facts
# into words for people, e.g. "PR #12 open: approved, CI passing".
AWK_PR='function pr_words(   rv, ci) {
	rv = $4 == "APPROVED" ? "approved" : $4 == "CHANGES_REQUESTED" ? "changes requested" : $4 == "REVIEW_REQUIRED" ? "review required" : "no review yet"
	ci = $5 == "none" ? "no CI" : "CI " $5
	return "PR #" $2 " " tolower($3) ": " rv ", " ci
}'

# pr_note <branch>: the branch's PR in words with its URL, "PR state unknown: …" when the forge
# cannot be asked, or nothing without a forge or a PR.
pr_note() {
	forge_load || return 0
	_why=$(forge_ready) || { echo "PR state unknown: $_why"; return 0; }
	_l=$(forge_pr_state "$1" 2>/dev/null) || { echo "PR state unknown: $FORGE_NAME did not answer"; return 0; }
	printf '%s\n' "$_l" | awk -F '\t' "$AWK_PR"'NF { print pr_words() "   " $6 }'
}

# pr_table: every PR as "<branch>\t<number>\t<state>\t<review>\t<ci>\t<url>\t<words>", newest
# first: the forge's PR line with the words in place of the head sha, so ls appends fields
# 2-7 to a row as they are (row_json reads them as $18..$23). One forge call for all items;
# fails, saying why, when the forge cannot be asked.
pr_table() {
	_why=$(forge_ready) || { echo "$_why"; return 1; }
	_all=$(forge_pr_list 2>/dev/null) || { echo "$FORGE_NAME did not answer"; return 1; }
	printf '%s\n' "$_all" | awk -F '\t' -v OFS='\t' "$AWK_PR"'NF { $7 = pr_words(); print }'
}

# AWK_JSON: awk functions to prepend to a program. esc(s) makes s safe inside a JSON string
# (character by character, because gsub's backslash handling differs between awks; tabs never
# reach it, and CR from CRLF files is escaped). row_json() renders an item_row line ($1..$17,
# plus $18..$23 = a PR's number, state, review, ci, url, words when ls joined one) as the fields
# every reader sees, so a new column is added here and nowhere else.
AWK_JSON='function esc(s,   o, i, c) {
	o = ""
	for (i = 1; i <= length(s); i++) {
		c = substr(s, i, 1)
		if (c == "\\") o = o "\\\\"; else if (c == "\"") o = o "\\\""; else if (c == "\r") o = o "\\r"; else o = o c
	}
	return o
}
function row_json() {
	return sprintf("\"id\":%d,\"type\":\"%s\",\"status\":\"%s\",\"phase\":\"%s\",\"frs\":%d,\"tasks_done\":%d,\"tasks_total\":%d,\"title\":\"%s\",\"branch\":\"%s\",\"source\":\"%s\"", \
		$1, esc($2), esc($3), esc($4), $5, $6, $7, esc($8), esc($9), esc($10)) \
		sprintf(",\"questions_open\":%d,\"approved_by\":\"%s\",\"opened_by\":\"%s\",\"shipped\":\"%s\",\"active\":\"%s\",\"reason\":\"%s\"", \
		$11, esc($12), esc($13), esc($14), esc($15), esc($16)) \
		sprintf(",\"reason_code\":\"%s\"", esc($17)) \
		($18 == "" ? "" : sprintf(",\"pr\":{\"number\":%d,\"state\":\"%s\",\"review\":\"%s\",\"ci\":\"%s\",\"url\":\"%s\"}", \
			$18, esc($19), esc($20), esc($21), esc($22)))
}
'

# item_sources: "<origin>\t<ref>\t<path>\t<blob>" for every item, the first source of an id
# winning: archive (on the base branch), worktree (the current item), local and remote branches,
# then base (specs/changes on the base branch). <blob> is the item file's hash in <ref>, empty
# for the worktree (its file may have edits).
item_sources() {
	_base=$(cfg sdd.base main)
	{
		git ls-tree -r "$_base" -- "$SPECS/archive" 2>/dev/null | O=archive R=$_base P1='' P2='' awk -F '\t' "$AWK_TREE"
		current_item && printf 'worktree\t%s\t%s\t\n' "$BRANCH" "$IFILE"
		for _kind in heads remotes; do
			git for-each-ref --format='%(refname:short)' "refs/$_kind" | while IFS= read -r _b; do
				case $_b in */HEAD | HEAD) continue ;; esac
				_bid=$(id_of "$_b") || continue
				# An item's own branch carries it under changes/, or under archive/ once shipped into a PR.
				git ls-tree -r "$_b" -- "$SPECS/changes/" "$SPECS/archive/" 2>/dev/null |
					O=$([ $_kind = heads ] && echo local || echo remote) R=$_b \
						P1="$SPECS/changes/$_bid-" P2="$SPECS/archive/$_bid-" awk -F '\t' "$AWK_TREE"
			done
		done
		git ls-tree -r "$_base" -- "$SPECS/changes" 2>/dev/null | O=base R=$_base P1='' P2='' awk -F '\t' "$AWK_TREE"
	} | awk -F '\t' '{
		# The id from the folder name, as id_of has it: the digits before its first "-".
		d = $3; sub(/\/item\.md$/, "", d); sub(/.*\//, "", d); i = d; sub(/-.*/, "", i)
		if (i == "" || i ~ /[^0-9]/ || i == d || seen[i]++) next
		print
	}'
}

# AWK_TREE: `git ls-tree -r` lines to item_sources lines: every */item.md, as origin O and ref R.
# With P1 and P2 set, only an item folder directly under one of those prefixes (an item branch's
# own item).
AWK_TREE='{
	p = $2
	if (p !~ /\/item\.md$/) next
	if (ENVIRON["P1"] != "") {
		if (index(p, ENVIRON["P1"]) == 1) r = substr(p, length(ENVIRON["P1"]) + 1)
		else if (index(p, ENVIRON["P2"]) == 1) r = substr(p, length(ENVIRON["P2"]) + 1)
		else next
		if (r !~ /^[^\/]*\/item\.md$/) next
	}
	b = $1; sub(/.* /, "", b)
	print ENVIRON["O"] "\t" ENVIRON["R"] "\t" p "\t" b
}'

# item_load <origin> <ref> <path>: point IFILE/ID/ITYPE at that item (a temp copy unless it
# is the working file; ITMP names it for cleanup) and set PHASE_REF to the ref, so item_phase
# judges that ref's committed code instead of the working tree.
item_load() {
	ITMP=
	IPR=
	PHASE_FP=
	PHASE_REF=
	if [ "$1" = worktree ]; then
		IFILE=$3
	else
		ITMP=$(mktemp "${TMPDIR:-/tmp}/$NAME-item.XXXXXX") || return 1
		git show "$2:$3" >"$ITMP" 2>/dev/null || { rm -f "$ITMP"; return 1; }
		IFILE=$ITMP
		PHASE_REF=$2
	fi
	# An item archived on a branch but not on the base was shipped into a PR (see current_item).
	case $1:$3 in archive:*) ;; *:"$SPECS/archive/"*) IPR=1 ;; esac
	# The id comes from the folder name, like everywhere else; the frontmatter repeats it.
	ID=$(id_of "${3%/item.md}")
	ITYPE=$(fm_get type "$IFILE")
}

# item_facts <origin>: for a loaded item (item_load), what its file, origin and path and the
# config decide, as TSV: 1 cache (1 when only those decide it, see item_rows) 2 id 3 type
# 4 status 5 phase 6 frs 7 tasks_done 8 tasks_total 9 title 10 questions_open 11 approved_by
# 12 shipped 13 reason 14 reason_code.
item_facts() {
	item_phase
	# A teammate's check results live on their machine: say what the file alone cannot.
	if [ "$1" = remote ] && [ "$PHASE" = build ] && [ -z "$(missing_sections "$IFILE" built)" ]; then
		PHASE='review?'
	fi
	_counts=$(parse_item "$IFILE" "$ID" | awk -F '\t' '
		$1 == "fr" { f++ } $1 == "task" { t++; if ($3 == "done") d++ } $1 == "q" && $3 == "open" { q++ }
		END { printf "%d\t%d\t%d\t%d", f, d, t, q }')
	_ap=$(fm_get approved "$IFILE")
	# "approved: <plan hash> <date> <name, may contain spaces>"
	if [ -n "$_ap" ]; then
		_ap=${_ap#* }
		_ap=${_ap#* }
	fi
	# The check's result (check, built, ready) and the working tree depend on more than the file.
	_fixed=1
	case $1:$WHYCODE in worktree:* | *:check | *:built | *:ready) _fixed=0 ;; esac
	printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$_fixed" "$ID" "$ITYPE" "$(fm_get status "$IFILE")" \
		"$PHASE" "${_counts%"$(printf '\t')"*}" "$(fm_get title "$IFILE")" "${_counts##*"$(printf '\t')"}" \
		"$_ap" "$(fm_get shipped "$IFILE")" "$WHY" "$WHYCODE"
}

# item_row <origin> <ref> <path>: one TSV summary line (see row_json):
#  1 id  2 type  3 status  4 phase  5 frs  6 tasks_done  7 tasks_total  8 title  9 branch
# 10 origin  11 questions_open  12 approved_by  13 opened_by  14 shipped  15 active  16 reason
# 17 reason_code (WHYCODE)
# "active" is the shipped date, else the last commit on the branch (today if the working
# tree has edits); "opened_by" is the author of the item's open commit.
item_row() {
	item_load "$@" || return 1
	_facts=$(item_facts "$1")
	[ -z "$ITMP" ] || rm -f "$ITMP"
	PHASE_FP=
	PHASE_REF=
	printf '%s\t%s\t%s\t%s\n' "$1" "$2" "$3" "${_facts#*"$(printf '\t')"}" | item_rows_finish
}

# item_rows [origin]: item_row for every item (item_sources), or only those from <origin>. The
# facts an item's file decides (item_facts) are cached in .git/sdd/cache/ (cache_file) under the
# file's hash, its origin and path; the rest (branch, opened_by, active) is read from git for
# all rows at once. A row whose facts depend on more (a check result, the working tree) is
# never cached. Deleting the cache changes nothing but speed (C-2).
item_rows() {
	_cf=$(cache_file) || _cf=/dev/null
	_src=$(item_sources | O=${1:-} awk -F '\t' 'ENVIRON["O"] == "" || $1 == ENVIRON["O"]')
	[ -n "$_src" ] || return 0
	# Facts for the files the cache does not know yet; the ones only their file decides go into it.
	_new=$(printf '%s\n' "$_src" | C=$_cf awk -F '\t' "$AWK_CACHE"'!(($4 SUBSEP $1 SUBSEP $3) in c) || $1 == "worktree"' |
		while IFS="$(printf '\t')" read -r _o _r _p _bl; do
			item_load "$_o" "$_r" "$_p" || continue
			_facts=$(item_facts "$_o")
			[ -z "$ITMP" ] || rm -f "$ITMP"
			_fixed=${_facts%%"$(printf '\t')"*}
			_facts=${_facts#*"$(printf '\t')"}
			[ -z "$_bl" ] || [ "$_fixed" != 1 ] ||
				printf '%s\t%s\t%s\t%s\n' "$_bl" "$_o" "$_p" "$_facts" >>"$_cf"
			printf '%s\t%s\t%s\t%s\n' "$_o" "$_r" "$_p" "$_facts"
		done)
	printf '%s\n' "$_src" | N=$_new C=$_cf awk -F '\t' "$AWK_CACHE"'
		BEGIN { n = split(ENVIRON["N"], l, "\n"); for (i = 1; i <= n; i++) { split(l[i], f, "\t"); nf[f[1] SUBSEP f[3]] = substr(l[i], length(f[1] f[2] f[3]) + 4) } }
		{
			if (($1 SUBSEP $3) in nf) x = nf[$1 SUBSEP $3]
			else if (($4 SUBSEP $1 SUBSEP $3) in c) x = c[$4 SUBSEP $1 SUBSEP $3]
			else next
			print $1 "\t" $2 "\t" $3 "\t" x
		}' | item_rows_finish
}

# AWK_CACHE: load the cache file C into c[<blob>, <origin>, <path>] = the cached facts (item_facts
# without its first field). Lines of the wrong shape (a write cut short) are skipped.
AWK_CACHE='BEGIN {
	while ((getline cl < ENVIRON["C"]) > 0) {
		if (split(cl, cf, "\t") != 16) continue
		ck = cf[1] SUBSEP cf[2] SUBSEP cf[3]
		if (!(ck in c)) c[ck] = substr(cl, length(cf[1] cf[2] cf[3]) + 4)
	}
}
'

# item_rows_finish: "<origin>\t<ref>\t<path>\t<facts without the cache field>" lines (13 facts)
# to item_row lines, adding what git says: opened_by (open_authors) and active.
item_rows_finish() {
	_in=$(cat)
	[ -n "$_in" ] || return 0
	_tab=$(printf '\t')
	# Per ref: who opened which item, and the day of its last commit (for rows not shipped).
	_git=$(printf '%s\n' "$_in" | cut -f2 | sort -u | while IFS= read -r _r; do
		open_authors "$_r" | R=$_r awk '{ print "a\t" ENVIRON["R"] "\t" $0 }'
		printf '%s\n' "$_in" | R=$_r awk -F '\t' '$2 == ENVIRON["R"] && $14 == "" { f = 1 } END { exit !f }' &&
			printf 'd\t%s\t%s\n' "$_r" "$(git log -1 --format=%cs "$_r" 2>/dev/null)"
	done)
	_today=
	case $_in in worktree"$_tab"* | *"
worktree$_tab"*) [ -z "$(git status --porcelain 2>/dev/null)" ] || _today=$(date +%F) ;; esac
	printf '%s\n' "$_in" | G=$_git TODAY=$_today awk -F '\t' -v OFS='\t' '
		BEGIN {
			n = split(ENVIRON["G"], l, "\n")
			for (i = 1; i <= n; i++) {
				split(l[i], f, "\t")
				if (f[1] == "a") by[f[2] SUBSEP f[3]] = f[4]; else day[f[2]] = f[3]
			}
		}
		{
			# $4 id 5 type 6 status 7 phase 8 frs 9 done 10 total 11 title 12 q 13 approved_by
			# 14 shipped 15 reason 16 reason_code
			act = $14 != "" ? $14 : ($1 == "worktree" && ENVIRON["TODAY"] != "") ? ENVIRON["TODAY"] : day[$2]
			print $4, $5, $6, $7, $8, $9, $10, $11, ($1 == "archive" ? "" : $2), $1, $12, $13, by[$2 SUBSEP $4], $14, act, $15, $16
		}'
}

# open_authors <ref>: "<id>\t<author>" for every item opened in <ref>'s history: the author of
# the newest commit with a "docs(<id>): open " line, as `git log -1 --grep` finds it for one id.
open_authors() {
	git log --format='%x01%an%n%B' --grep='^docs([0-9][0-9]*): open ' "$1" 2>/dev/null | awk '
		substr($0, 1, 1) == "\001" { a = substr($0, 2); next }
		/^docs\([0-9]+\): open / { i = substr($0, 6, index($0, ")") - 6); if (!(i in s)) { s[i] = 1; print i "\t" a } }'
}

# cache_file: this clone's cache of item facts for this sdd code and config:
# .git/sdd/cache/facts.<hash of both>. Other cache files (older code or config) are removed when
# a new one starts.
cache_file() {
	_ck=$({
		cat "$SDD_HOME/VERSION" "$SDD_HOME/core/lib/common.sh" 2>/dev/null
		printf '%s\n%s\n' "$CMD" "$CFG_TAB"
	} | git hash-object --stdin) || return 1
	_cf="$ST/cache/facts.$_ck"
	if [ ! -f "$_cf" ]; then
		mkdir -p "$ST/cache" || return 1
		rm -f "$ST/cache"/facts.*
		: >"$_cf" || return 1
	fi
	printf '%s\n' "$_cf"
}

# parse_item <file> <id>: the facts in the plan part of an item, guidance comments removed,
# as TSV "kind id state text example". kind is us|fr|task|d|q|dod; state is open|done for
# tasks, open|decided for questions. A fact is a line starting with its ID (tasks:
# "- [ ] T-<id>.<n>" or "- [x] …"); following lines continue it until a blank line, and
# "e.g." lines are its example.
parse_item() {
	plan_part "$1" | uncomment | I=$2 awk '
	function emit() {
		if (k == "q") st = (index(txt, "decided:") ? "decided" : "open")
		if (k != "") printf "%s\t%s\t%s\t%s\t%s\n", k, id, st, txt, eg
		k = ""; txt = ""; eg = ""; st = ""
	}
	function start(kind, s,   n) {
		n = index(s, " "); id = (n ? substr(s, 1, n - 1) : s); txt = (n ? substr(s, n + 1) : "")
		sub(/^[ \t]+/, "", txt)
		k = (substr(id, index(id, "-") + 1, length(ENVIRON["I"]) + 1) == ENVIRON["I"] ".") ? kind : ""
	}
	{ gsub(/\t/, " ") }
	/^```/ { emit(); fence = !fence; next }
	fence { next }
	/^- \[[ xX]\] T-[0-9]+\.[0-9]+/ { emit(); start("task", substr($0, 7)); st = (substr($0, 4, 1) == " ") ? "open" : "done"; next }
	/^(US|FR|D|Q|DOD)-[0-9]+\.[0-9]+([ ]|$)/ {
		emit(); p = substr($0, 1, index($0, "-") - 1)
		start(p == "US" ? "us" : p == "FR" ? "fr" : p == "D" ? "d" : p == "Q" ? "q" : "dod", $0); next
	}
	k != "" && /^[ ]*e\.g\./ { l = $0; sub(/^[ ]*e\.g\.[ ]*/, "", l); eg = (eg == "" ? l : eg " " l); next }
	k != "" && /^#/ { emit(); next }
	k != "" && /[^ ]/ { l = $0; sub(/^[ ]+/, "", l); if (eg != "") eg = eg " " l; else txt = txt " " l; next }
	{ emit() }
	END { emit() }'
}

# --- constitution -----------------------------------------------------------------
# specs/constitution.md holds a system's ground truths. Each article is enforced, either by a
# command that runs inside `check` or by the human at every review, and it changes only
# through an `amendment` item.
CONST="$SPECS/constitution.md"

# articles: per article "C-<n>\t<review|check>\t<command or ->\t<rule>", or "!\t<C-n>\t<problem>"
# for one that is malformed. An article is "C-<n> <rule>" at the start of a line, followed by
# indented "Why: …" and "Enforced: review" or "Enforced: check <command>" lines.
articles() {
	[ -f "$CONST" ] || return 0
	uncomment "$CONST" | awk '
	function flush() {
		if (id == "") return
		if (!why) print "!\t" id "\tno \"Why:\" line"
		else if (enf == "") print "!\t" id "\tno \"Enforced:\" line"
		else if (enf == "review") print id "\treview\t-\t" rule
		else if (enf ~ /^check [^ ]/) print id "\tcheck\t" substr(enf, 7) "\t" rule
		else print "!\t" id "\t\"Enforced:\" must be review or check <command>"
		id = ""
	}
	{ gsub(/\t/, " ") }
	/^C-[0-9]+ / { flush(); id = $1; rule = substr($0, length($1) + 2); why = 0; enf = ""; next }
	id != "" && /^[ ]+Why:/ { why = 1; next }
	id != "" && /^[ ]+Enforced:/ { enf = $0; sub(/^[ ]+Enforced:[ ]*/, "", enf); sub(/[ ]+$/, "", enf); next }
	/^[^ ]/ { flush() }
	END { flush() }'
}

# check_articles <log>: the constitution's own gate. Fails, with CHECK_ARTICLES holding one
# problem per line, when an article is malformed, the constitution is over budget, or an
# "Enforced: check" command fails (its output goes to <log>).
check_articles() {
	CHECK_ARTICLES=
	[ -f "$CONST" ] || return 0
	_arts=$(articles)
	_n=$(printf '%s\n' "$_arts" | grep -c '^C-')
	_max=$(cfg constitution.max-articles 30)
	[ "$_n" -le "$_max" ] || CHECK_ARTICLES="over budget ($_n of $_max articles)"
	_tab=$(printf '\t')
	while IFS="$_tab" read -r _id _kind _cmd _rule; do
		_p=
		if [ "$_id" = '!' ]; then
			_p="$_kind: $_cmd"
		elif [ "$_kind" = check ]; then
			if printf '%s\n' "$_cmd" | masked >/dev/null; then
				_p="$_id $_rule (its check hides failures: $_cmd)"
			else
				printf '$ %s   # %s\n' "$_cmd" "$_id" >>"$1"
				sh -c "$_cmd" </dev/null >>"$1" 2>&1 || _p="$_id $_rule (its check failed)"
			fi
		fi
		[ -z "$_p" ] || CHECK_ARTICLES="${CHECK_ARTICLES:+$CHECK_ARTICLES
}$_p"
	done <<EOF2
$_arts
EOF2
	[ -z "$CHECK_ARTICLES" ]
}

# constitution_guard: on an item branch the constitution (once it is on the base branch)
# changes only through an amendment, and an amendment changes nothing outside specs/.
# Prints the reason and fails otherwise.
constitution_guard() {
	_mb=$(git merge-base "$(cfg sdd.base main)" HEAD 2>/dev/null) ||
		{ echo "base branch '$(cfg sdd.base main)' not found, so the constitution cannot be checked (set base under [sdd] in $DIRNAME/config)"; return 1; }
	if [ "$ITYPE" = amendment ]; then
		! code_changed || { echo "an amendment lands no code: move code changes to their own items and list them under Impact"; return 1; }
		return 0
	fi
	git cat-file -e "$_mb:$CONST" 2>/dev/null || return 0
	git diff --quiet "$_mb" -- "$CONST" || { echo "the constitution changes only through: $CMD new amendment \"…\""; return 1; }
}

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
# human_only <verb>: refuse inside a role run (sdd run sets SDD_RUN for its agent; "-" when usage
# tracking is off): approve, ship and tidy --remote are the human's (FR-21.1). It stops a careless
# agent, not a hostile one, which could unset it (D-21.1).
human_only() {
	[ -n "${SDD_RUN:-}" ] || return 0
	_r=" (run $SDD_RUN)"
	[ "$SDD_RUN" != - ] || _r=
	usage_die "$1 is the human's: a role run$_r cannot $1"
}

# need_repo: cd to the repository root and set ROOT and ST (machine-local state dir,
# shared by all worktrees of the clone, never committed).
need_repo() { find_repo || die "not inside a git repository"; }

# find_repo: need_repo, but fails quietly outside a repository (hooks). A no-op when it already
# ran in this process (a command run inside another, like status in hook session-start).
# Also sets GD, this worktree's own git dir. bin/sdd's rev-parse (RP) is reused when it ran here.
ROOT=
GD=
RP=
RP_PWD=
find_repo() {
	[ -z "$ROOT" ] || [ "$PWD" != "$ROOT" ] || return 0
	if [ -n "$RP" ] && [ "$RP_PWD" = "$PWD" ]; then
		_rp=$RP
	else
		_rp=$(git rev-parse --show-toplevel --path-format=absolute --git-common-dir --absolute-git-dir 2>/dev/null) || return 1
	fi
	ROOT=${_rp%%"
"*}
	_rp=${_rp#*"
"}
	ST="${_rp%%"
"*}/$NAME"
	GD=${_rp#*"
"}
	cd "$ROOT" || exit 1
	[ -d "$ST/checks" ] || mkdir -p "$ST/checks"
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
# cfg_all, cfg_every, cfg_mine and gate_level look keys up there instead of running git each
# time. need_repo loads it; a lookup before that loads it itself.
# Inside a repo it is cached in <git dir>/sdd-config, a file the shell sources (no process runs),
# used while it is strictly newer than each config file and the files (and which of them
# exist) are the same; an edit, even in the second the cache was written, rebuilds it.
CFG_TAB=
CFG_ON=
CFG_KEY=
cfg_load() {
	_key=
	_uc="${XDG_CONFIG_HOME:-$HOME/.config}/$NAME/config"
	for _f in "$SDD_HOME/config" "$_uc" "$SDD_HOME/core/config"; do
		if [ -f "$_f" ]; then _key="$_key+$_f"; else _key="$_key-$_f"; fi
	done
	_cc=${GD:+$GD/$NAME-config}
	if [ -n "$_cc" ] && [ -f "$_cc" ] && cfg_fresh "$_cc"; then
		# shellcheck source=/dev/null
		. "$_cc"
		[ "$CFG_KEY" != "$_key" ] || { CFG_ON=1; return 0; }
	fi
	CFG_TAB=$(
		_n=0
		for _f in "$SDD_HOME/config" "$_uc" "$SDD_HOME/core/config"; do
			_n=$((_n + 1))
			[ -f "$_f" ] || continue
			echo "#$_n"
			git config -f "$_f" --list
		done | awk '/^#[123]$/ { n = substr($0, 2); next } { print n " " $0 }')
	CFG_ON=1
	[ -n "$_cc" ] || return 0
	{
		printf "CFG_KEY='%s'\nCFG_TAB='" "$(printf '%s' "$_key" | sed "s/'/'\\\\''/g")"
		printf '%s' "$CFG_TAB" | sed "s/'/'\\\\''/g"
		printf "'\n"
	} >"$_cc.$$" 2>/dev/null && mv -f "$_cc.$$" "$_cc" 2>/dev/null || rm -f "$_cc.$$"
}

# cfg_fresh <cache>: the cache is newer than every config file that exists (_uc: cfg_load's).
cfg_fresh() {
	for _f in "$SDD_HOME/config" "$_uc" "$SDD_HOME/core/config"; do
		[ ! -e "$_f" ] || [ "$1" -nt "$_f" ] || return 1
	done
}

# AWK_CFG: cfg_get(key, files) in awk, over ENVIRON["CFG_TAB"]: the last value of <key> in the
# first of <files> (e.g. "123", in lookup order) that has it, as `git config --get` finds it;
# cfg_found says whether one did. cfg_vals[f] holds all of a file's values, one per line.
# Sections and names compare case-insensitively, as in git.
AWK_CFG='function cfg_get(key, files,   a, b, i, j, r, e, f, n, l, last) {
	a = index(key, "."); b = key; sub(/.*[.]/, "", b)
	if (a) key = tolower(substr(key, 1, a - 1)) substr(key, a, length(key) - a - length(b) + 1) tolower(b)
	n = split(ENVIRON["CFG_TAB"], l, "\n")
	for (f in cfg_vals) delete cfg_vals[f]
	for (i = 1; i <= n; i++) {
		r = substr(l[i], 3); e = index(r, "=")
		if ((e ? substr(r, 1, e - 1) : r) != key) continue
		f = substr(l[i], 1, 1); last[f] = e ? substr(r, e + 1) : ""
		cfg_vals[f] = cfg_vals[f] last[f] "\n"
	}
	cfg_found = 0
	for (j = 1; j <= length(files); j++) {
		f = substr(files, j, 1)
		if (f in cfg_vals) { cfg_found = 1; return last[f] }
	}
	return ""
}
'

# cfg_tab <get|all|every> <key> <files>: look <key> up in CFG_TAB (see AWK_CFG). get: its value;
# all: every value in the first file that has any (--get-all); every: every value in each of
# <files> in turn. Fails when none has it.
cfg_tab() {
	[ -n "$CFG_ON" ] || cfg_load
	CFG_TAB=$CFG_TAB M=$1 K=$2 F=$3 awk "$AWK_CFG"'BEGIN {
		v = cfg_get(ENVIRON["K"], ENVIRON["F"]); m = ENVIRON["M"]; fs = ENVIRON["F"]
		if (!cfg_found) exit 1
		if (m == "get") { print v; exit }
		for (j = 1; j <= length(fs); j++) {
			f = substr(fs, j, 1)
			if (!(f in cfg_vals)) continue
			printf "%s", cfg_vals[f]
			if (m == "all") exit
		}
	}'
}

# cfg <key> [default]: first hit in project, user, core config (git-config format).
cfg() {
	cfg_tab get "$1" 123 && return 0
	[ $# -gt 1 ] && printf '%s\n' "$2" && return 0
	return 1
}

# cfg_all <key>: all values of a multi-valued key, from the first file that has any.
cfg_all() { cfg_tab all "$1" 123; }

# cfg_every <key>: every value of a multi-valued key from core, user and project config
# together: a list that adds up, unlike cfg_all, where the first file with any wins.
cfg_every() { cfg_tab every "$1" 321 || return 0; }

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
	cfg_tab get "$1" 213 && return 0
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
	[ -n "$CFG_ON" ] || cfg_load
	CFG_TAB=$CFG_TAB G=$1 T=$2 awk "$AWK_CFG"'BEGIN {
		g = ENVIRON["G"]; t = ENVIRON["T"]
		gates = cfg_get("type." t ".gates", "123")
		if (!cfg_found) { gates = cfg_get("sdd.gates", "123"); if (!cfg_found) gates = "planned approved check built" }
		if (!index(" " gates " ", " " g " ")) { print "off"; exit }
		v = cfg_get("type." t "." g, "123"); if (cfg_found) { print v; exit }
		p = cfg_get("sdd.profile", "123"); if (!cfg_found) p = "lite"
		v = cfg_get("profile." p "." g, "123"); print (cfg_found ? v : "off")
	}'
}

# --- text helpers -----------------------------------------------------------------

# render <file> <id> <title> <type>: substitute {{id}} {{title}} {{type}} {{date}}
# {{cmd}} {{base}} {{name}} literally (no regex, so titles may contain any character). A line that
# is just {{max-size}} becomes RENDER_SIZE (next sets it; FR-39.1), or nothing when that is empty.
RENDER_DATE=
RENDER_BASE=
RENDER_SIZE=
render() {
	[ -n "$RENDER_DATE" ] || RENDER_DATE=$(date +%F)
	[ -n "$RENDER_BASE" ] || RENDER_BASE=$(cfg sdd.base main)
	R_ID=$2 R_TITLE=$3 R_TYPE=$4 R_DATE=$RENDER_DATE R_CMD=$CMD R_BASE=$RENDER_BASE R_NAME=$NAME \
		R_SIZE=$RENDER_SIZE awk '
	function repl(s, from, to,   out, i) {
		out = ""
		while ((i = index(s, from)) > 0) { out = out substr(s, 1, i - 1) to; s = substr(s, i + length(from)) }
		return out s
	}
	$0 == "{{max-size}}" { if (ENVIRON["R_SIZE"] != "") $0 = ENVIRON["R_SIZE"]; else next }
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

# extensions_on: the extensions turned on: team and user config add up (FR-61.3).
extensions_on() { cfg_every sdd.extension | awk '!seen[$0]++'; }

# ext_prompt <step> <id> <title> <type>: each on extension's text for that step, when the tool it
# needs is installed (FR-61.4). Text only: nothing in an extension folder is ever run (FR-61.6).
ext_prompt() {
	for _e in $(extensions_on); do
		case $_e in *[!a-z0-9-]*) continue ;; esac
		_ed=$(sdd_path "extensions/$_e") && [ -f "$_ed/$1.md" ] || continue
		_en=$(git config -f "$_ed/extension" extension.needs 2>/dev/null)
		[ -z "$_en" ] || command -v "$_en" >/dev/null 2>&1 || continue
		echo
		render "$_ed/$1.md" "$2" "$3" "$4"
	done
}

# plan_changes: what the plan part changed since the last approval, as a unified diff under a
# heading; nothing when it was never approved or did not change (FR-60.2). Ticks do not count.
plan_changes() {
	_c=$(git log -1 --format=%H --fixed-strings --grep="docs($ID): approve plan" 2>/dev/null)
	[ -n "$_c" ] || return 0
	git show "$_c:$IFILE" >"$ST/plan-was.$$" 2>/dev/null || { rm -f "$ST/plan-was.$$"; return 0; }
	plan_part "$ST/plan-was.$$" | sed 's/^- \[[xX]\] T-/- [ ] T-/' >"$ST/plan-a.$$"
	plan_part "$IFILE" | sed 's/^- \[[xX]\] T-/- [ ] T-/' >"$ST/plan-b.$$"
	_d=$(diff -u "$ST/plan-a.$$" "$ST/plan-b.$$" | tail -n +3)
	rm -f "$ST/plan-was.$$" "$ST/plan-a.$$" "$ST/plan-b.$$"
	[ -z "$_d" ] || printf 'Plan changes since the last approval:\n%s\n' "$_d"
}

# plan_hash <file>: what approval pins. Task boxes count as unticked: sdd ticks them as tasks pass
# (task done), which must not void the approval; every other plan edit does. Cached for one file
# in <git dir>/sdd-plan ("<file> <hash>"), used while strictly newer than the file.
plan_hash() {
	_pc=${GD:+$GD/$NAME-plan}
	if [ -n "$_pc" ] && [ "$PWD" = "$ROOT" ] && [ "$_pc" -nt "$1" ] 2>/dev/null &&
		{ IFS=' ' read -r _pf _ph <"$_pc"; } 2>/dev/null && [ "$_pf" = "$1" ] && [ -n "$_ph" ]; then
		printf '%s\n' "$_ph"
		return 0
	fi
	_ph=$(awk 'NR == 1 && $0 == "---" { fm = 1; next } fm { if ($0 == "---") fm = 0; next } $0 == "## Built" { exit }
		/^- \[[xX]\] T-/ { $0 = "- [ ] T-" substr($0, 9) } { print }' "$1" | git hash-object --stdin) || return 1
	case $1 in *' '* | '') ;; *)
		[ -z "$_pc" ] || [ "$PWD" != "$ROOT" ] ||
			{ printf '%s %s\n' "$1" "$_ph" >"$_pc.$$" && mv -f "$_pc.$$" "$_pc"; } 2>/dev/null || rm -f "$_pc.$$"
		;;
	esac
	printf '%s\n' "$_ph"
}

# approval_ok: approved, and the plan (with the contracts it names) has not changed since.
approval_ok() {
	_ap=$(fm_get approved "$IFILE")
	[ -n "$_ap" ] && approval_pin "$(fm_get contracts "$IFILE")" && [ "${_ap%% *}" = "$APIN" ]
}

# approval_pin <contracts: list>: what approve pins (D-26.3) into APIN: the plan hash (also in
# PHASH), then ",<name>=<object id>" per contract (contract_ids). Items without contracts pin the
# plan hash alone, as before item 26. Fails, CBAD saying why, when a contract cannot be pinned.
approval_pin() {
	PHASH=$(plan_hash "$IFILE") || return 1
	contract_ids "$1"
	APIN=$PHASH$CPINS
	[ -z "$CBAD" ]
}

# approval_current: the approved gate as item_phase judges it (from IR_*): not blocking, or the
# approval pins what approval_pin says now.
approval_current() {
	CBAD=
	[ "$(gate_level approved "$ITYPE")" = block ] || return 0
	approval_pin "$IR_CONTRACTS" && [ -n "$IR_APPROVED" ] && [ "${IR_APPROVED%% *}" = "$APIN" ]
}

# contract_ids <contracts: list>: each name in an item's "contracts:" (FR-26.3) resolved to the
# entry of specs/contracts/ on the base branch with that name, extension removed (a file or a
# folder; D-26.4: the base branch's copy is the truth). Sets CROWS ("<name>\t<object id>\t<path>"
# per name, a folder's path ending in /), CPINS (",<name>=<id>" per name, in list order; id "none"
# when it cannot be resolved) and CBAD (the first problem, or empty). A name must be
# [A-Za-z0-9_-]+: it becomes a path. One git call per process (CTREE), and none for an empty list.
contract_ids() {
	CROWS='' CPINS='' CBAD=''
	[ -n "$1" ] || return 0
	contract_tree
	_cx=$(printf '%s\n' "$CTREE" | L=$1 B=$(cfg sdd.base main) C=$CMD awk -F '\t' '
		NF >= 2 {
			split($1, m, " "); p = $2; n = p; sub(/.*\//, "", n)
			if (m[2] == "blob") sub(/\.[^.]*$/, "", n); else p = p "/"
			if (n in id) dup[n] = 1
			id[n] = m[3]; path[n] = p
		}
		END {
			k = split(ENVIRON["L"], x, /[, ]+/); pins = ""; bad = ""; rows = ""
			for (i = 1; i <= k; i++) {
				c = x[i]; if (c == "") continue
				if (c !~ /^[A-Za-z0-9_-]+$/) { e = "contract name \"" c "\" refused: a name is letters, digits, _ and - (the file name in specs/contracts/ without its extension)"; c = "?" }
				else if (!(c in id)) e = "no contract " c " on " ENVIRON["B"] ": ship its contract item first (" ENVIRON["C"] " new contract \"…\")"
				else if (c in dup) e = "contract " c " names more than one entry of specs/contracts/ on " ENVIRON["B"] ": rename one"
				else e = ""
				if (e != "" && bad == "") bad = e
				pins = pins "," c "=" (e == "" ? id[c] : "none")
				if (e == "") rows = rows c "\t" id[c] "\t" path[c] "\n"
			}
			printf "%s\n%s\n%s", bad, pins, rows
		}')
	CBAD=${_cx%%"
"*}
	_cx=${_cx#*"
"}
	CPINS=${_cx%%"
"*}
	CROWS=${_cx#*"
"}
	[ "$CROWS" != "$_cx" ] || CROWS=
}
# contract_tree: the base branch's specs/contracts/ entries (`git ls-tree`), read once per
# process into CTREE.
contract_tree() {
	[ -n "${CTREE+x}" ] || CTREE=$(git ls-tree "$(cfg sdd.base main)" -- "$CONTRACTS/" 2>/dev/null)
}
unset CTREE

# verified_by: the last "Verified by:" line in "## Built" (FR-22.3), a list bullet and guidance
# removed; empty when there is none. Built runs up to "## Review", as in missing_sections.
verified_by() {
	uncomment "$IFILE" | awk '
		/^## / && !(on && $0 !~ /^## Review/) { on = ($0 == "## Built"); next }
		on { s = $0; sub(/^[ \t]*([-*][ \t]+)?/, "", s); if (index(s, "Verified by:") == 1) v = s }
		END { if (v != "") print v }'
}

# verified: "## Built" names a verifier run, not "Verified by: none" (or none at all).
verified() {
	_v=$(verified_by)
	_v=$(printf '%s\n' "${_v#Verified by:}" | tr -d ' \t' | tr 'A-Z' 'a-z')
	case $_v in '' | none*) return 1 ;; esac
}

# review_print: what sdd review records of the item's code change (FR-22.4): a first line
# "patch=<git patch-id of the diff from the merge base, specs/ left out>" (empty when no code
# changed), then "<blob after>\t<path>" per changed file, to name what changed since. A rebase
# that keeps the change keeps the patch id. A contract item lands no code: what it changes is
# specs/contracts/, so that is what it records (FR-28.4).
review_print() {
	_mb=$(git merge-base "$(cfg sdd.base main)" HEAD) || return 1
	if [ "${ITYPE:-}" = contract ]; then set -- "$CONTRACTS"; else set -- . ":(exclude)$SPECS"; fi
	_p=$(git diff --binary --no-color --no-ext-diff --no-renames "$_mb" HEAD -- "$@" |
		git patch-id --stable | cut -d ' ' -f 1)
	echo "patch=$_p"
	git -c core.quotePath=false diff --raw --no-abbrev --no-renames "$_mb" HEAD -- "$@" |
		awk -F '\t' '{ split($1, m, " "); print m[4] "\t" $2 }'
}

# plan_frs: the requirement ids (FR-<id>.<n>) written in the plan, guidance excluded.
plan_frs() {
	plan_part "$IFILE" | uncomment | grep -oE "FR-$ID\.[0-9]+" | sort -u -t . -k 2,2n
}

# plan_findings: the problems in a plan that need no judgement (FR-19.1), from parse_item's lines
# on stdin (or IR_FACTS), in plan order: "<id>\t<short name>\t<problem>". An FR no task names
# (when there are tasks), an FR with no example, an open question, an ID written twice, a task
# naming an FR the plan lacks, a task line task_rows cannot read; for roadmap entries (FR-24.2) an
# unknown type, an after: that is not an earlier entry, a line entry_row cannot read, and a roadmap
# with none; a task sized above [build] max-size (FR-39.1). The short name is the start of the
# text: an FR's after "SHALL", a question's up to its "?"; an entry has none.
plan_findings() {
	max_size
	TY=${ITYPE:-} I=${ID:-} MS=$MAX_SIZE TYPES=$(types | paste -sd ' ' -) awk -F '\t' "$AWK_TASK$AWK_ENTRY"'
	function short(s,   n, w, i, o) {
		n = split(s, w, " "); o = ""
		for (i = 1; i <= n && i <= 6; i++) o = o (i > 1 ? " " : "") w[i]
		if (o !~ /\?$/) sub(/[,.;:]+$/, "", o)
		return o (n > 6 ? "…" : "")
	}
	function say(i, p) { print id[i] "\t" name[i] "\t" p }
	$1 == "" { next }
	($2 in times) { times[$2]++; next }
	{
		n++; id[n] = $2; kind[n] = $1; times[$2] = 1; s = $4
		if ($1 == "fr") { fr[$2] = 1; noeg[n] = ($5 == ""); if ((i = index(s, "SHALL "))) s = substr(s, i + 6) }
		if ($1 == "q" && (i = index(s, "?"))) s = substr(s, 1, i)
		if ($1 == "q") open[n] = ($3 != "decided")
		if ($1 == "r") {
			split(entry_row($2, $4), r, "\t"); entries++; epos[$2] = n
			bad[n] = r[5]; after[n] = r[4]
			if (r[5] == "" && !index(" " ENVIRON["TYPES"] " ", " " r[2] " ")) bad[n] = "unknown type " r[2] " (types: " ENVIRON["TYPES"] ")"
		}
		if ($1 == "task") {
			tasks++
			if ($2 !~ /^T-[0-9]+\.[0-9]+$/) bad[n] = "its ID must be T-<item>.<n>"
			else {
				split(task_row($2, $3, $4), r, "\t"); s = r[3]; bad[n] = r[8]; names[n] = r[7]
				if (r[8] == "" && index("SML", r[9]) > index("SML", ENVIRON["MS"])) big[n] = r[9]
				if ((i = index(s, " ("))) s = substr(s, 1, i - 1)
				m = split(r[7], x, " "); for (j = 1; j <= m; j++) named[x[j]] = 1
			}
		}
		name[n] = ($1 == "r") ? "" : short(s)
	}
	END {
		if (ENVIRON["TY"] == "roadmap" && !entries)
			print "Items\t\tno entries: list them as - R-" ENVIRON["I"] ".1 <type>: <title>"
		for (i = 1; i <= n; i++) {
			if (times[id[i]] > 1) say(i, times[id[i]] == 2 ? "written twice" : "written " times[id[i]] " times")
			if (noeg[i]) say(i, "no e.g. example under it")
			if (kind[i] == "fr" && tasks && !(id[i] in named)) say(i, "no task names it")
			if (open[i]) say(i, "not decided")
			if (bad[i] != "") say(i, (kind[i] == "r" && bad[i] ~ /^unknown type/) ? bad[i] : "cannot read it: " bad[i])
			if (big[i] != "") say(i, "size " big[i] ", above the builder\047s max-size " ENVIRON["MS"] ": split it")
			m = split(after[i], x, " ")
			for (j = 1; j <= m; j++)
				if (!(x[j] in epos)) say(i, "after " x[j] ", which is not an entry")
				else if (epos[x[j]] >= i) say(i, "after " x[j] ", which is not an earlier entry")
			m = split(names[i], x, " ")
			for (j = 1; j <= m; j++) if (!(x[j] in fr)) say(i, "names " x[j] ", which the plan does not have")
		}
	}'
}

# AWK_ENTRY: entry_row(id, text) in awk: a roadmap entry (parse_item's "r" fact, text
# "<type>: <title> (after: R-<id>.<k>, …)") as "<id>\t<type>\t<title>\t<after, space-separated>\t<bad>",
# <bad> empty or why the line cannot be read (FR-24.2).
AWK_ENTRY='function entry_row(id, txt,   i, ty, ti, af, a, n, x, j, r, bad) {
	ty = ""; ti = ""; af = ""; bad = ""
	i = index(txt, ": ")
	if (!i || (ty = substr(txt, 1, i - 1)) ~ /[ ]/ || ty == "") { ty = ""; bad = "write it as - " id " <type>: <title>" }
	else {
		ti = substr(txt, i + 2)
		if ((i = index(ti, " (after:"))) {
			if (substr(ti, length(ti)) != ")") bad = "(after: …) must end its line"
			else {
				a = substr(ti, i + 8, length(ti) - i - 8); ti = substr(ti, 1, i - 1)
				n = split(a, x, ",")
				for (j = 1; j <= n; j++) {
					r = x[j]; gsub(/^[ ]+|[ ]+$/, "", r)
					if (r !~ /^R-[0-9]+\.[0-9]+$/) { bad = "after: lists entry IDs, e.g. (after: R-1.1, R-1.2)"; break }
					af = af (af == "" ? "" : " ") r
				}
			}
		}
		sub(/[ ]+$/, "", ti)
		if (bad == "" && ti == "") bad = "it has no title"
	}
	return id "\t" ty "\t" ti "\t" af "\t" bad
}
'

# max_size: MAX_SIZE, the largest task size the builder takes, [build] max-size (FR-39.1): S, M or
# L; any other value warns and counts as L. Read once per run.
MAX_SIZE=
max_size() {
	[ -z "$MAX_SIZE" ] || return 0
	MAX_SIZE=$(cfg build.max-size L)
	case $MAX_SIZE in
	S | M | L) ;;
	*)
		warn "[build] max-size must be S, M or L, not $MAX_SIZE: counting it as L"
		MAX_SIZE=L
		;;
	esac
}

# findings_lines: plan_findings lines on stdin as people read them: "✗ <id> (<name>): <problem>".
findings_lines() { awk -F '\t' '{ printf "✗ %s%s: %s\n", $1, ($2 == "" ? "" : " (" $2 ")"), $3 }'; }

# --- git helpers ------------------------------------------------------------------

# current_branch: read from this worktree's HEAD file when still in it (no process); git answers
# anywhere else, and for a HEAD that names no branch file (reftable writes refs/heads/.invalid).
current_branch() {
	_h=
	if [ -n "$GD" ] && [ "$PWD" = "$ROOT" ] && { IFS= read -r _h <"$GD/HEAD" || [ -n "$_h" ]; } 2>/dev/null; then
		case $_h in
		'ref: refs/heads/.invalid') ;;
		'ref: refs/heads/'*) printf '%s\n' "${_h#ref: refs/heads/}"; return 0 ;;
		'ref: '*) ;;
		*) return 1 ;;
		esac
	fi
	git symbolic-ref --quiet --short HEAD 2>/dev/null
}

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
# One diff from the merge base (git 2.30+, else merge-base then diff); untracked files are listed
# only when no tracked file outside specs/ changed.
code_changed() {
	_b=$(cfg sdd.base main)
	{ git diff --name-only --merge-base "$_b" 2>/dev/null || {
		_mb=$(git merge-base "$_b" HEAD 2>/dev/null) || _mb=HEAD
		git diff --name-only "$_mb"
	}; } | grep -v "^$SPECS/" | grep -q . && return 0
	git ls-files --others --exclude-standard | grep -v "^$SPECS/" | grep -q .
}

# changed_paths: paths this branch changed outside specs/ since it left the base branch:
# committed, uncommitted and untracked, relative to the repo root.
changed_paths() {
	_b=$(cfg sdd.base main)
	{
		# --no-renames: a rename lists its old path too (src/a.go → docs/a.md is not docs-only).
		git -C "$ROOT" diff --name-only --no-renames --merge-base "$_b" 2>/dev/null || {
			_mb=$(git -C "$ROOT" merge-base "$_b" HEAD 2>/dev/null) || _mb=HEAD
			git -C "$ROOT" diff --name-only --no-renames "$_mb"
		}
		git -C "$ROOT" ls-files --others --exclude-standard
	} | grep -v "^$SPECS/" | sort -u
}

# docs_only: every changed path matches a [check] docs glob (a case pattern, so * also matches
# /), and something changed. FR-48.1.
docs_only() {
	_globs=$(cfg_all check.docs) || return 1
	_paths=$(changed_paths)
	[ -n "$_paths" ] || return 1
	printf '%s\n' "$_paths" | while IFS= read -r _p; do
		_hit=
		while IFS= read -r _g; do
			# shellcheck disable=SC2254 # the glob is the pattern
			case $_p in $_g) _hit=1 && break ;; esac
		done <<EOF
$_globs
EOF
		[ -n "$_hit" ] || exit 1
	done
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

# check_record <id> <fingerprint> <result> <seconds>
check_record() {
	printf 'fp=%s\nresult=%s\nat=%s\nsecs=%s\n' "$2" "$3" "$(date '+%Y-%m-%d %H:%M')" "$4" >"$ST/checks/$1"
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
# as a stable word for programs: frontmatter|status|fill|approval|changed|task|check|built|ready),
# MISSING (the empty required sections it judged, joined) and the IR_* facts of item_read.
#   plan    the human's time: header not closed, plan empty, or not (or no longer) approved
#   build   the agent's time: no passing check for this code, or "## Built" empty
#   review  the human's time: verified and written up
item_phase() {
	WHY=
	TASK=
	WHYCODE=
	item_read
	MISSING=$IR_MISS_PLAN
	if [ -z "$IR_CLOSED" ]; then
		PHASE=plan
		WHY="item.md: $FM_OPEN"
		WHYCODE=frontmatter
	elif [ -n "${IPR:-}" ]; then
		PHASE='pr'
		WHY="shipped into a pull request, waiting to merge: $CMD ship merges it"
		WHYCODE='pr'
	elif [ "$IR_STATUS" != open ]; then
		PHASE='done'
		WHY="status: $IR_STATUS"
		WHYCODE=status
	elif [ -n "$MISSING" ]; then
		PHASE=plan
		WHY="to fill: $MISSING"
		WHYCODE=fill
	elif ! approval_current; then
		PHASE=plan
		_tok=${IR_APPROVED%% *}
		if [ -z "$IR_APPROVED" ] && [ -n "$CBAD" ]; then
			WHY="$CBAD; then the human approves: $CMD approve"
			WHYCODE=contract
		elif [ -z "$IR_APPROVED" ]; then
			WHY="waiting for the human to approve the plan: $CMD approve"
			WHYCODE=approval
		elif [ "${_tok%%,*}" != "$PHASH" ]; then
			WHY="the plan changed after approval; the human re-approves with: $CMD approve"
			WHYCODE=changed
		else
			# FR-26.5: the plan is as approved, so a pinned contract changed, or the list did.
			_cc=$(O=${_tok#"${_tok%%,*}"} N=$CPINS awk 'BEGIN {
				a = split(ENVIRON["O"], o, ","); b = split(ENVIRON["N"], n, ",")
				for (i = 2; i <= a; i++) { split(o[i], p, "="); was[p[1]] = p[2]; ol = ol " " p[1] }
				for (i = 2; i <= b; i++) { split(n[i], p, "="); nl = nl " " p[1]; if (was[p[1]] != p[2]) ch = ch (ch == "" ? "" : ", ") p[1] }
				print (ol != nl ? "" : ch) }')
			if [ -z "$_cc" ]; then
				WHY="the contracts: list changed after approval; the human re-approves with: $CMD approve"
				WHYCODE=changed
			else
				WHY="contract $_cc changed on $(cfg sdd.base main) after approval; check the plan still fits, merge $(cfg sdd.base main), then the human re-approves: $CMD approve"
				WHYCODE=contract
			fi
		fi
	else
		# Open tasks come first: the builder works them in order (task done ticks them).
		MISSING=$IR_MISS_BUILT
		if [ -n "$IR_TASK" ]; then
			PHASE=build
			TASK=${IR_TASK%%"$(printf '\t')"*}
			_t=${IR_TASK#*"$(printf '\t')"}
			_t=${_t#*"$(printf '\t')"}
			WHY="task $TASK of $IR_TASKS: ${_t%%"$(printf '\t')"*}"
			WHYCODE=task
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
# "<task id>\t<open|done>\t<what>\t<files>\t<test>\t<expect>\t<FR ids>\t<bad>\t<size>\t<reason>\t<by>".
# <bad> is empty, or why sdd cannot read the line (attributes that do not end it, an attribute it
# does not know, a size not S, M or L, an expect: fail… it cannot read): sdd must not guess. <size>
# is S, M or L (M when none is given). <expect> is "fail" for `expect: fail` and
# `expect: fail "<text>"`; <reason> is that text, which the red run's output must contain (FR-22.1).
# <by> is the role that builds the task (`by: planner`, FR-36.1), empty for the builder.
# Attributes sit in a final "(files: …; test: …; expect: fail; size: S; by: planner)"; a value runs to the
# next "; <key>:", so a test command may contain ";" and parentheses.
task_rows() {
	parse_item "$IFILE" "$ID" | awk -F '\t' "$AWK_TASK"'$1 == "task" && $2 ~ /^T-[0-9]+\.[0-9]+$/ { print task_row($2, $3, $4) }'
}

# AWK_TASK: task_row(id, state, text) in awk: a task fact (parse_item) as a task_rows line.
AWK_TASK='function task_row(id, st, txt,   what, files, test, expect, size, frs, bad, p, k, key, i, a, n, kk, val, name, j, s, why, by) {
	what = txt; files = ""; test = ""; expect = ""; size = "M"; frs = ""; bad = ""; why = ""; by = ""
	p = 0
	for (k = 1; k <= 5; k++) {
		key = (k == 1 ? "files:" : k == 2 ? "test:" : k == 3 ? "expect:" : k == 4 ? "size:" : "by:")
		i = index(txt, " (" key); if (i && (p == 0 || i < p)) p = i
	}
	if (p && substr(txt, length(txt)) != ")") bad = "its attributes must end its line, e.g. … (files: a.js; test: npm test)"
	if (p && substr(txt, length(txt)) == ")") {
		what = substr(txt, 1, p - 1); a = "; " substr(txt, p + 2, length(txt) - p - 2)
		n = 0
		while (match(a, /; [A-Za-z][A-Za-z0-9_-]*: /)) {
			if (n) val[n] = substr(a, 1, RSTART - 1)
			kk = substr(a, RSTART + 2, RLENGTH - 4); a = substr(a, RSTART + RLENGTH); n++; name[n] = kk
		}
		if (n) val[n] = a
		for (j = 1; j <= n; j++) {
			if (name[j] == "files") files = val[j]; else if (name[j] == "test") test = val[j]
			else if (name[j] == "expect") expect = val[j]; else if (name[j] == "size") size = val[j]
			else if (name[j] == "by") by = val[j]
			else if (bad == "") bad = "unknown attribute " name[j] " (known: files, test, expect, size, by)"
		}
		if (bad == "" && size !~ /^[SML]$/) bad = "size must be S, M or L, not " size
		if (bad == "" && by != "" && by !~ /^[a-z][a-z0-9-]*$/) bad = "by: must be a role name (a lowercase word)"
		if (expect ~ /^fail ".+"$/) { why = substr(expect, 7, length(expect) - 7); expect = "fail" }
		else if (bad == "" && expect ~ /^fail/ && expect != "fail") bad = "expect must be fail or fail \"<text>\", not " expect
	}
	s = what
	while (match(s, /FR-[0-9]+\.[0-9]+/)) { frs = frs (frs == "" ? "" : " ") substr(s, RSTART, RLENGTH); s = substr(s, RSTART + RLENGTH) }
	sub(/(,? FR-[0-9]+\.[0-9]+)+[ ,]*$/, "", what); sub(/[ ,]+$/, "", what)
	return id "\t" st "\t" what "\t" files "\t" test "\t" expect "\t" frs "\t" bad "\t" size "\t" why "\t" by
}
'

# task_batch: of the task_rows lines on stdin, the next batch the builder works at once: the first
# open task, joined by the open S tasks right after it while it is S too, up to [build] batch (3).
# M and L tasks run alone, so a batch is the same every run (D-17.1). A batch ends after an
# `expect: fail` task: its test must be red when ticked, so the code that turns it green waits
# for the next batch (a builder handed both writes both, and the red run then passes). A batch
# belongs to one role (`by:`, the builder when none, FR-36.2): it ends where the role changes.
task_batch() {
	B=$(cfg build.batch 3) awk -F '\t' '
		$2 != "open" { next }
		n == 0 { print; n = 1; small = ($9 == "S"); by = $11; if ($6 == "fail") exit; next }
		!small || $9 != "S" || n >= ENVIRON["B"] + 0 || ($11 == "" ? "builder" : $11) != (by == "" ? "builder" : by) { exit }
		{ print; n++; if ($6 == "fail") exit }'
}

# ir_batch: task_batch for the item item_read read (IR_FACTS), without reading it again.
ir_batch() {
	printf '%s\n' "$IR_FACTS" | awk -F '\t' "$AWK_TASK"'$1 == "task" && $2 ~ /^T-[0-9]+\.[0-9]+$/ { print task_row($2, $3, $4) }' | task_batch
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

# unnamed_ticks: ticked tasks whose tick is committed at HEAD but no commit subject since the base
# names (ship refuses them). Ticks not committed yet are left out: the build commits next.
unnamed_ticks() {
	_head=$(git show "HEAD:$IFILE" 2>/dev/null) || return 0
	task_rows | awk -F '\t' '$2 == "done" { print $1 }' | while IFS= read -r _t; do
		printf '%s\n' "$_head" | grep -qF -- "- [x] $_t " || continue
		[ -n "$(task_commit "$_t")" ] || echo "$_t"
	done
}

# unnamed_note: FR-51.3's line for unnamed_ticks, or nothing.
unnamed_note() {
	_u=$(unnamed_ticks)
	[ -z "$_u" ] || echo "⚠ ticked and committed, but no commit subject names them: $(joinlist "$_u"). Ship refuses this: name each task ID in a commit subject (amend that commit while it is the last one)."
}

# bent_tests: one line per file of a done `by: planner` task that changed after the commit naming
# the task (later commits or the working tree), unless "## Built" names the file (FR-58.1).
bent_tests() {
	_built=$(awk '/^## Built/ { on = 1; next } /^## / { on = 0 } on' "$IFILE")
	_tab=$(printf '\t')
	task_rows | awk -F '\t' '$2 == "done" && $11 == "planner" { print $1 "\t" $4 }' |
		while IFS="$_tab" read -r _t _files; do
			_c=$(task_commit "$_t")
			[ -n "$_c" ] || continue
			for _f in $(printf '%s\n' "$_files" | tr ',' ' '); do
				[ -n "$(git diff --name-only "$_c" -- "$_f")" ] || continue
				printf '%s\n' "$_built" | grep -qF -- "$_f" && continue
				echo "item $ID: $_t's test $_f (written by the planner) changed after it was written: undo it, or say why under \"## Built\" naming the file"
			done
		done
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
# CHECK_ARTICLES to the constitution's problems (see check_articles), and CHECK_SECS to how long
# the commands took (FR-35.1).
run_check() {
	# [check] run always runs; [check] code is skipped when only docs changed (FR-48.1).
	_cmds=$(cfg_all check.run)
	_code=$(cfg_all check.code)
	[ -n "$_cmds$_code" ] || die "no check configured: add 'run = <command>' under [check] in $DIRNAME/config"
	CHECK_SKIPPED=
	if [ -n "$_code" ] && docs_only; then
		CHECK_SKIPPED=$(joinlist "$_code")
	elif [ -n "$_code" ]; then
		_cmds=${_cmds:+$_cmds
}$_code
	fi
	_bad=$(printf '%s\n' "$_cmds" | masked)
	[ -z "$_bad" ] || die "refusing a check that hides failures: $_bad"
	_fp=$(fingerprint)
	CHECK_LOG="$ST/checks/${1:-none}.log"
	: >"$CHECK_LOG"
	_rc=0
	CHECK_NOTRUN=
	_t0=$(date +%s)
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
	CHECK_SECS=$(($(date +%s) - _t0))
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
		case $_rc in 0) _res=pass ;; 1) _res=fail ;; *) _res=empty ;; esac
		check_record "$1" "$_fp" "$_res" "$CHECK_SECS"
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
# 2-7 to a row as they are (row_json reads them as $21..$26). One forge call for all items;
# fails, saying why, when the forge cannot be asked.
pr_table() {
	_why=$(forge_ready) || { echo "$_why"; return 1; }
	_all=$(forge_pr_list 2>/dev/null) || { echo "$FORGE_NAME did not answer"; return 1; }
	printf '%s\n' "$_all" | awk -F '\t' -v OFS='\t' "$AWK_PR"'NF { $7 = pr_words(); print }'
}

# AWK_JSON: awk functions to prepend to a program. esc(s) makes s safe inside a JSON string
# (character by character, because gsub's backslash handling differs between awks; tabs never
# reach it, and CR from CRLF files is escaped). row_json() renders an item_row line ($1..$20,
# plus $21..$26 = a PR's number, state, review, ci, url, words when ls joined one) as the fields
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
		sprintf(",\"reason_code\":\"%s\",\"roadmap\":\"%s\",\"depends\":\"%s\",\"collides_with\":\"%s\"", esc($17), esc($18), esc($19), esc($20)) \
		($21 == "" ? "" : sprintf(",\"pr\":{\"number\":%d,\"state\":\"%s\",\"review\":\"%s\",\"ci\":\"%s\",\"url\":\"%s\"}", \
			$21, esc($22), esc($23), esc($24), esc($25)))
}
'

# item_sources: "<origin>\t<ref>\t<path>\t<blob>\t<collides>" for every item, the first source of
# an id winning: archive (on the base branch), worktree (the current item), local and remote
# branches, then base (specs/changes on the base branch). <blob> is the item file's hash in <ref>,
# empty for the worktree (its file may have edits). <collides> (FR-53.1) names, comma-separated,
# the first ref of each other item folder with the same id (two people's solo-mode ids): the same
# folder on a local branch and its remote is the same item, not a collision.
item_sources() {
	_base=$(cfg sdd.base main)
	# Everything but the worktree row follows from the branch tips alone: cached in
	# .git/sdd/cache/sources under one for-each-ref's output, so an unchanged repo costs one git call.
	_refs=$(git for-each-ref --format='%(objectname) %(refname)' refs/heads refs/remotes)
	_key=$(printf '%s\n%s\n%s\n' "$_base" "$SPECS" "$_refs" | cksum)
	_scf="$ST/cache/sources"
	_sv=
	[ "$(head -n 1 "$_scf" 2>/dev/null)" != "$_key" ] || _sv=$(sed 1d "$_scf")
	if [ -z "$_sv" ]; then
		_sv=$(
			git ls-tree -r "$_base" -- "$SPECS/archive" 2>/dev/null | O=archive R=$_base P1='' P2='' awk -F '\t' "$AWK_TREE"
			# The worktree row goes here (see below): it beats the branches.
			echo worktree
			printf '%s\n' "$_refs" | while read -r _ _ref; do
				# No case here: macOS /bin/sh (bash 3.2) cannot parse one inside $( ).
				_b=${_ref#refs/heads/} _o=local
				[ "$_b" != "$_ref" ] || _b=${_ref#refs/remotes/} _o=remote
				[ "$_b" != "$_ref" ] && [ "${_b##*/}" != HEAD ] || continue
				_bid=$(id_of "$_b") || continue
				# An item's own branch carries it under changes/, or under archive/ once shipped into a PR.
				git ls-tree -r "$_b" -- "$SPECS/changes/" "$SPECS/archive/" 2>/dev/null |
					O=$_o R=$_b P1="$SPECS/changes/$_bid-" P2="$SPECS/archive/$_bid-" awk -F '\t' "$AWK_TREE"
			done
			git ls-tree -r "$_base" -- "$SPECS/changes" 2>/dev/null | O=base R=$_base P1='' P2='' awk -F '\t' "$AWK_TREE"
		)
		# Written whole, then moved: a reader never sees half a file. Unwritable: no cache.
		if _stmp=$(mkdir -p "$ST/cache" && mktemp "$ST/cache/sources.XXXXXX"); then
			printf '%s\n%s\n' "$_key" "$_sv" >"$_stmp" && mv -f "$_stmp" "$_scf" || rm -f "$_stmp"
		fi
	fi
	_wrow=
	! current_item || _wrow=$(printf 'worktree\t%s\t%s\t' "$BRANCH" "$IFILE")
	printf '%s\n' "$_sv" | W=$_wrow awk -F '\t' '
	$0 == "worktree" { if (ENVIRON["W"] == "") next; $0 = ENVIRON["W"] }
	{
		# The id from the folder name, as id_of has it: the digits before its first "-".
		d = $3; sub(/\/item\.md$/, "", d); sub(/.*\//, "", d); i = d; sub(/-.*/, "", i)
		if (i == "" || i ~ /[^0-9]/ || i == d) next
		if (!(i in win)) { win[i] = ++n; line[n] = $0; key[n] = i; fold[i SUBSEP d] = 1; next }
		if (!((i SUBSEP d) in fold)) { fold[i SUBSEP d] = 1; cw[i] = cw[i] (cw[i] == "" ? "" : ",") $2 }
	}
	END { for (k = 1; k <= n; k++) print line[k] "\t" cw[key[k]] }'
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
	# type and contracts (as fm_get reads them) in one awk: item_rows reads the contracts' ids
	# (contract_tree) before the item's facts, whose subshell would lose them.
	_fm=$(awk 'NR == 1 { if ($0 != "---") exit; next } $0 == "---" { exit }
		{ i = index($0, ":"); k = substr($0, 1, i - 1)
			if (i && (k == "type" || k == "contracts") && !(k in f)) { v = substr($0, i + 1); sub(/^[ \t]+/, "", v); f[k] = v } }
		END { printf "%s\n%s", f["type"], f["contracts"] }' "$IFILE")
	ITYPE=${_fm%%"
"*}
	ILCONTRACTS=${_fm#*"
"}
	[ "$ILCONTRACTS" != "$_fm" ] || ILCONTRACTS=
}

# item_facts <origin>: for a loaded item (item_load), what its file, origin and path and the
# config decide, as TSV: 1 cache (1 when only those decide it, see item_rows) 2 id 3 type
# 4 status 5 phase 6 frs 7 tasks_done 8 tasks_total 9 title 10 questions_open 11 approved_by
# 12 shipped 13 reason 14 reason_code 15 roadmap (the entry it was opened from) 16 depends.
item_facts() {
	item_phase
	# A teammate's check results live on their machine: say what the file alone cannot.
	if [ "$1" = remote ] && [ "$PHASE" = build ] && [ -z "$IR_MISS_BUILT" ]; then
		PHASE='review?'
	fi
	_ap=$IR_APPROVED
	# "approved: <plan hash> <date> <name, may contain spaces>"
	if [ -n "$_ap" ]; then
		_ap=${_ap#* }
		_ap=${_ap#* }
	fi
	# The check's result (check, built, ready) and the working tree depend on more than the file.
	_fixed=1
	case $1:$WHYCODE in worktree:* | *:check | *:built | *:ready) _fixed=0 ;; esac
	# D-26.4: an open item's contracts are judged on the base branch, which the file does not decide.
	[ -z "$IR_CONTRACTS" ] || [ "$IR_STATUS" != open ] || _fixed=0
	printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$_fixed" "$ID" "$ITYPE" "$IR_STATUS" \
		"$PHASE" "${IR_COUNTS%"$(printf '\t')"*}" "$IR_TITLE" "${IR_COUNTS##*"$(printf '\t')"}" \
		"$_ap" "$IR_SHIPPED" "$WHY" "$WHYCODE" "$IR_ROADMAP" "$IR_DEPENDS"
}

# item_row <origin> <ref> <path> [collides]: one TSV summary line (see row_json):
#  1 id  2 type  3 status  4 phase  5 frs  6 tasks_done  7 tasks_total  8 title  9 branch
# 10 origin  11 questions_open  12 approved_by  13 opened_by  14 shipped  15 active  16 reason
# 17 reason_code (WHYCODE)  18 roadmap (R-<id>.<n> it was opened from)  19 depends (as written)
# 20 collides_with (item_sources)
# "active" is the shipped date, else the last commit on the branch (today if the working
# tree has edits); "opened_by" is the author of the item's open commit.
item_row() {
	item_load "$@" || return 1
	_facts=$(item_facts "$1")
	[ -z "$ITMP" ] || rm -f "$ITMP"
	PHASE_FP=
	PHASE_REF=
	printf '%s\t%s\t%s\t%s\t%s\n' "$1" "$2" "$3" "${_facts#*"$(printf '\t')"}" "${4:-}" | item_rows_finish
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
	_new=$(printf '%s\n' "$_src" | C=$_cf awk -F '\t' "$AWK_CACHE"'!(($4 SUBSEP $1 SUBSEP $3) in c) || $1 == "worktree" { print $1 "\t" $2 "\t" $3 "\t" $4 }' |
		while IFS="$(printf '\t')" read -r _o _r _p _bl; do
			item_load "$_o" "$_r" "$_p" || continue
			[ -z "$ILCONTRACTS" ] || contract_tree
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
			print $1 "\t" $2 "\t" $3 "\t" x "\t" $5
		}' | item_rows_finish
}

# AWK_CACHE: load the cache file C into c[<blob>, <origin>, <path>] = the cached facts (item_facts
# without its first field). Lines of the wrong shape (a write cut short) are skipped.
AWK_CACHE='BEGIN {
	while ((getline cl < ENVIRON["C"]) > 0) {
		if (split(cl, cf, "\t") != 18) continue
		ck = cf[1] SUBSEP cf[2] SUBSEP cf[3]
		if (!(ck in c)) c[ck] = substr(cl, length(cf[1] cf[2] cf[3]) + 4)
	}
}
'

# item_rows_finish: "<origin>\t<ref>\t<path>\t<facts without the cache field>\t<collides>" lines
# (15 facts) to item_row lines, adding what git says: opened_by (open_authors) and active.
item_rows_finish() {
	_in=$(cat)
	[ -n "$_in" ] || return 0
	_tab=$(printf '\t')
	_git=
	_today=
	# Per ref: who opened which item, and the day of its last commit (for rows not shipped).
	# dep_rows needs neither, so it skips these git calls.
	if [ -z "${_IR_LIGHT:-}" ]; then
		_git=$(printf '%s\n' "$_in" | cut -f2 | sort -u | while IFS= read -r _r; do
			open_authors "$_r" | R=$_r awk '{ print "a\t" ENVIRON["R"] "\t" $0 }'
			printf '%s\n' "$_in" | R=$_r awk -F '\t' '$2 == ENVIRON["R"] && $14 == "" { f = 1 } END { exit !f }' &&
				printf 'd\t%s\t%s\n' "$_r" "$(git log -1 --format=%cs "$_r" 2>/dev/null)"
		done)
		case $_in in worktree"$_tab"* | *"
worktree$_tab"*) [ -z "$(git status --porcelain 2>/dev/null)" ] || _today=$(date +%F) ;; esac
	fi
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
			# 14 shipped 15 reason 16 reason_code 17 roadmap 18 depends 19 collides
			act = $14 != "" ? $14 : ($1 == "worktree" && ENVIRON["TODAY"] != "") ? ENVIRON["TODAY"] : day[$2]
			print $4, $5, $6, $7, $8, $9, $10, $11, ($1 == "archive" ? "" : $2), $1, $12, $13, by[$2 SUBSEP $4], $14, act, $15, $16, $17, $18, $19
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
# as TSV "kind id state text example". kind is us|fr|task|d|q|dod|r (a roadmap entry, "- R-<id>.<n>
# <type>: <title> (after: …)", read by entry_row); state is open|done for
# tasks, open|decided for questions. A fact is a line starting with its ID (tasks:
# "- [ ] T-<id>.<n>" or "- [x] …"); following lines continue it until a blank line, and
# "e.g." lines are its example.
parse_item() {
	plan_part "$1" | uncomment | I=$2 awk 'function out(s) { print s }'"$AWK_PARSE"
}

# AWK_PARSE: parse_item's rules, for uncommented plan lines; each fact goes to out(line).
AWK_PARSE='
function emit() {
	if (k == "q") st = (index(txt, "decided:") ? "decided" : "open")
	if (k != "") out(k "\t" id "\t" st "\t" txt "\t" eg)
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
/^- R-[0-9]+\.[0-9]+([ ]|$)/ { emit(); start("r", substr($0, 3)); next }
/^(US|FR|D|Q|DOD)-[0-9]+\.[0-9]+([ ]|$)/ {
	emit(); p = substr($0, 1, index($0, "-") - 1)
	start(p == "US" ? "us" : p == "FR" ? "fr" : p == "D" ? "d" : p == "Q" ? "q" : "dod", $0); next
}
k != "" && /^[ ]*e\.g\./ { l = $0; sub(/^[ ]*e\.g\.[ ]*/, "", l); eg = (eg == "" ? l : eg " " l); next }
k != "" && /^#/ { emit(); next }
k != "" && /[^ ]/ { l = $0; sub(/^[ ]+/, "", l); if (eg != "") eg = eg " " l; else txt = txt " " l; next }
{ emit() }
END { emit() }'

# item_read: read the item file (IFILE, for ID) once, for item_phase and the commands after it,
# with the same rules as the helpers named here. Sets IR_CLOSED (1 when fm_closed), IR_TYPE,
# IR_STATUS, IR_TITLE, IR_APPROVED and IR_SHIPPED (fm_get), IR_MISS_PLAN and IR_MISS_BUILT
# (missing_sections of each part, joined as joinlist does), IR_TASK (the first open task_rows
# line), IR_TASKS (how many task_rows lines), IR_COUNTS ("<frs>\t<tasks done>\t<tasks>\t<open
# questions>"), IR_ROADMAP and IR_DEPENDS (fm_get roadmap, depends: FR-24.3, FR-24.4),
# IR_CONTRACTS (fm_get contracts: FR-26.3) and
# IR_FACTS (parse_item's lines).
item_read() {
	_s=$(I=$ID awk "$AWK_TASK"'
	function out(s,   f) {
		facts = facts s "\n"; split(s, f, "\t")
		if (f[1] == "fr") nfr++
		if (f[1] == "task") { nt++; if (f[3] == "done") nd++ }
		if (f[1] == "q" && f[3] == "open") nq++
		if (f[1] == "task" && f[2] ~ /^T-[0-9]+\.[0-9]+$/) { ntask++; if (f[3] == "open" && task == "") task = task_row(f[2], f[3], f[4]) }
	}
	# uncomment, one line at a time, with a state per stream w.
	function unc(line, w,   o, e, b) {
		o = ""
		while (length(line) > 0) {
			if (inc[w]) {
				e = index(line, "-->"); if (!e) { line = ""; break }
				line = substr(line, e + 3); inc[w] = 0
			} else {
				b = index(line, "<!--"); if (!b) { o = o line; break }
				o = o substr(line, 1, b - 1); line = substr(line, b + 4); inc[w] = 1
			}
		}
		return o
	}
	# missing_sections, for both parts at once, over the whole file uncommented.
	function mflush() {
		if (mname != "" && !mopt && !mfilled) { if (mpart) mb = mb (mb == "" ? "" : ",") mname; else mp = mp (mp == "" ? "" : ",") mname }
	}
	function whole(l) {
		l = unc(l, "w")
		if (mbuilt && l ~ /^## / && l !~ /^## Review/) return
		if (l ~ /^## /) {
			mflush(); mname = substr(l, 4)
			if (mname == "Built") mbuilt = 1
			mpart = mbuilt; mopt = (mname ~ /\(optional\)/); mfilled = 0; return
		}
		if (mname != "" && l ~ /[^ \t]/) mfilled = 1
	}
	{ whole($0) }
	# The frontmatter (fm_get: the first of each key; fm_closed), then the plan part (plan_part).
	NR == 1 && $0 == "---" { infm = 1; next }
	infm {
		if ($0 == "---") { infm = 0; closed = 1; next }
		i = index($0, ":")
		if (i && !((kk = substr($0, 1, i - 1)) in fm)) { v = substr($0, i + 1); sub(/^[ \t]+/, "", v); fm[kk] = v }
		next
	}
	$0 == "## Built" { past = 1 }
	past { next }
	{ $0 = unc($0, "p") }
	'"$AWK_PARSE"'
	END {
		mflush(); gsub(/,/, ", ", mp); gsub(/,/, ", ", mb)
		printf "%s\n%s\n%s\n%s\n%s\n%s\n%s\n%s\n%s\n%d\n%d\t%d\t%d\t%d\n%s\n%s\n%s\n%s", closed ? 1 : "", fm["type"], fm["status"],
			fm["title"], fm["approved"], fm["shipped"], mp, mb, task, ntask, nfr, nd, nt, nq, fm["roadmap"], fm["depends"], fm["contracts"], facts
	}' "$IFILE")
	{
		IFS= read -r IR_CLOSED
		IFS= read -r IR_TYPE
		IFS= read -r IR_STATUS
		IFS= read -r IR_TITLE
		IFS= read -r IR_APPROVED
		IFS= read -r IR_SHIPPED
		IFS= read -r IR_MISS_PLAN
		IFS= read -r IR_MISS_BUILT
		IFS= read -r IR_TASK
		IFS= read -r IR_TASKS
		IFS= read -r IR_COUNTS
		IFS= read -r IR_ROADMAP
		IFS= read -r IR_DEPENDS
		IFS= read -r IR_CONTRACTS
	} <<EOF
$_s
EOF
	_s="$_s
"
	for _ln in 1 2 3 4 5 6 7 8 9 10 11 12 13 14; do _s=${_s#*"
"}; done
	IR_FACTS=${_s%"
"}
}

# --- roadmaps (item 24) -----------------------------------------------------------
# A roadmap (type roadmap) lists items as entries "- R-<id>.<n> <type>: <title> (after: …)". Once
# it has shipped, each entry opens one item (new --from), which carries "roadmap: R-<id>.<n>" and
# "depends: <its after: list>" in its frontmatter. An entry's state is derived from those items.

# shipped_roadmaps [id]: the entries of every roadmap shipped to the base branch (or only roadmap
# <id>), read from the base branch (D-24.5), one line each: "<roadmap id>\t<roadmap title>\t" and
# entry_row's fields. Fails when there is none. On the base branch itself the archive is read from
# the working tree, so `next` there runs no git process when no roadmap has shipped.
shipped_roadmaps() {
	_rb=$(cfg sdd.base main)
	_rg=${1:-*}
	if [ "$(current_branch)" = "$_rb" ]; then
		_rl=$(grep -l -x 'type: roadmap' "$SPECS"/archive/$_rg-*/item.md 2>/dev/null)
		_rf=
	else
		_rl=$(git grep -l -x 'type: roadmap' "$_rb" -- "$SPECS/archive/$_rg-*/item.md" 2>/dev/null | sed 's/^[^:]*://')
		_rf=$_rb
	fi
	[ -n "$_rl" ] || return 1
	_rt=$(mktemp "${TMPDIR:-/tmp}/$NAME-roadmap.XXXXXX") || return 1
	_rout=$(printf '%s\n' "$_rl" | while IFS= read -r _rp; do
		_ri=$(id_of "${_rp%/item.md}") || continue
		[ -z "${1:-}" ] || [ "$1" = "$_ri" ] || continue
		if [ -n "$_rf" ]; then git show "$_rf:$_rp" >"$_rt" 2>/dev/null || continue; else cp "$_rp" "$_rt" || continue; fi
		[ "$(fm_get type "$_rt")" = roadmap ] && [ "$(fm_get status "$_rt")" = shipped ] || continue
		parse_item "$_rt" "$_ri" | R=$_ri RT=$(fm_get title "$_rt") awk -F '\t' "$AWK_ENTRY"'
			$1 == "r" && !seen[$2]++ { print ENVIRON["R"] "\t" ENVIRON["RT"] "\t" entry_row($2, $4) }'
	done)
	rm -f "$_rt"
	[ -n "$_rout" ] || return 1
	printf '%s\n' "$_rout"
}

# AWK_DEPS: awk functions over item_rows lines in ENVIRON["ROWS"] (FR-24.4). deps_load() first;
# then dep_met(ref) says whether a ref (an item ID like 31, or an entry like R-30.1) has shipped:
# the item, or the item opened from the entry (roadmap: R-30.1); dep_words(ref) names it for people,
# e.g. "31 (Auth API)"; deps_unmet(list) joins the words of the unmet refs in a depends: list.
# entry_item(ref) is the item opened from an entry ("" when none, or only dropped ones), est[ref]
# its status: a shipped one beats an open one, which beats a dropped one.
AWK_DEPS='function deps_rank(s) { return s == "shipped" ? 3 : s == "open" ? 2 : s == "dropped" ? 1 : 0 }
function deps_load(   n, l, i, f) {
	n = split(ENVIRON["ROWS"], l, "\n")
	for (i = 1; i <= n; i++) {
		if (split(l[i], f, "\t") < 19) continue
		if (!(f[1] in ist)) { ist[f[1]] = f[3]; iti[f[1]] = f[8] }
		if (f[18] != "" && deps_rank(f[3]) > deps_rank(est[f[18]])) { est[f[18]] = f[3]; eid[f[18]] = f[1]; eti[f[18]] = f[8] }
	}
}
function entry_item(r) { return (est[r] == "" || est[r] == "dropped") ? "" : eid[r] }
function dep_met(r) { return (r ~ /^R-/) ? est[r] == "shipped" : ist[r] == "shipped" }
function dep_words(r) {
	if (r ~ /^R-/) return entry_item(r) == "" ? r " (not opened yet)" : eid[r] " (" eti[r] ", " r ")"
	if (ist[r] == "") return r " (no such item)"
	return r " (" iti[r] (ist[r] == "dropped" ? ", dropped" : "") ")"
}
function deps_unmet(list,   n, x, i, o) {
	n = split(list, x, /[, ]+/); o = ""
	for (i = 1; i <= n; i++) if (x[i] != "" && !dep_met(x[i])) o = o (o == "" ? "" : ", ") dep_words(x[i])
	return o
}
'

# dep_rows: item_rows without opened_by and active (empty), which dependency state never reads;
# read once per process into DEP_ROWS, as waits_for and AWK_DEPS's callers need it.
dep_rows() {
	[ -n "${DEP_ROWS+x}" ] && return 0
	DEP_ROWS=$(_IR_LIGHT=1 && item_rows)
}
unset DEP_ROWS

# waits_for <depends list>: the refs of an item's depends: that have not shipped, in words
# (deps_unmet, e.g. "31 (Auth API)"), into WAITS; empty when every one has (FR-24.6). Reads the
# item rows only when the list is not empty, so items without depends: cost nothing.
waits_for() {
	WAITS=
	[ -n "$1" ] || return 0
	dep_rows
	WAITS=$(ROWS=$DEP_ROWS D=$1 awk "$AWK_DEPS"'BEGIN { deps_load(); print deps_unmet(ENVIRON["D"]) }')
}

# --- constitution -----------------------------------------------------------------
# specs/constitution.md holds a system's ground truths. Each article is enforced, either by a
# command that runs inside `check` or by the human at every review, and it changes only
# through an `amendment` item.
CONST="$SPECS/constitution.md"
# Contracts (item 26): the interfaces items build against, one file or folder each.
CONTRACTS="$SPECS/contracts"

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
	# A rule written over several lines: its indented lines before Why: are part of it (FR-49.5).
	id != "" && !why && enf == "" && /^[ ]+[^ ]/ { l = $0; sub(/^[ ]+/, "", l); rule = rule " " l; next }
	/^[^ ]/ { flush() }
	END { flush() }'
}

# no_articles: a constitution in another format (prose articles) yields no rules, silently
# otherwise (FR-44.1). Prints the warning line, or nothing.
no_articles() {
	[ -f "$CONST" ] || return 0
	articles | grep -q '^C-' && return 0
	echo "⚠ $CONST has no C-<n> articles, so no rule is shown or enforced: write each rule as \"C-1 <rule>\" with indented Why: and Enforced: lines (through an amendment item)"
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
# changes only through an amendment, and an amendment changes nothing outside specs/. Likewise
# contracts (specs/contracts/, FR-26.2): only a contract item changes them, from the first one
# on, and a contract item changes nothing outside specs/. Prints the reason and fails otherwise.
constitution_guard() {
	_mb=$(git merge-base "$(cfg sdd.base main)" HEAD 2>/dev/null) ||
		{ echo "base branch '$(cfg sdd.base main)' not found, so the constitution cannot be checked (set base under [sdd] in $DIRNAME/config)"; return 1; }
	if [ "$ITYPE" = amendment ]; then
		! code_changed || { echo "an amendment lands no code: move code changes to their own items and list them under Impact"; return 1; }
		return 0
	fi
	if [ "$ITYPE" = contract ]; then
		! code_changed || { echo "a contract item lands no code: move code changes to the items under Users"; return 1; }
	elif ! git diff --quiet "$_mb" -- "$CONTRACTS" || [ -n "$(git ls-files --others --exclude-standard -- "$CONTRACTS")" ]; then
		echo "contracts change only through: $CMD new contract \"…\" ($CONTRACTS/ changed here)"
		return 1
	fi
	git cat-file -e "$_mb:$CONST" 2>/dev/null || return 0
	git diff --quiet "$_mb" -- "$CONST" || { echo "the constitution changes only through: $CMD new amendment \"…\""; return 1; }
}

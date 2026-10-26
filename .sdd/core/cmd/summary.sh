# shellcheck shell=sh
# summary [--since <when>] [--last <n>] [--mine] [--md] [--ascii]: recent work as a table for
# people: item, state, who, when. By default every open item plus what shipped in the last
# 7 days. <when> is today, yesterday, <n>d or YYYY-MM-DD. Everything shown is derived.
since=
last=
mine=
fmt=box
while [ $# -gt 0 ]; do
	case $1 in
	--since) [ $# -gt 1 ] || usage_die "usage: $NAME summary --since today|yesterday|<n>d|YYYY-MM-DD"; since=$2; shift ;;
	--last) [ $# -gt 1 ] && [ -n "$2" ] && [ -z "$(printf '%s' "$2" | tr -d 0-9)" ] || usage_die "usage: $NAME summary --last <n>"; last=$2; shift ;;
	--mine) mine=1 ;;
	--md) fmt=md ;;
	--ascii) fmt=ascii ;;
	*) usage_die "usage: $NAME summary [--since <when>] [--last <n>] [--mine] [--md] [--ascii]" ;;
	esac
	shift
done
case $since in
'' | today | yesterday | *[0-9]d) ;;
[0-9][0-9][0-9][0-9]-0[1-9]-[0-3][0-9] | [0-9][0-9][0-9][0-9]-1[0-2]-[0-3][0-9]) ;;
*) usage_die "--since takes today, yesterday, <n>d or YYYY-MM-DD (got: $since)" ;;
esac
need_repo
me=$(git config user.name || true)
[ -z "$mine" ] || [ -n "$me" ] || die "--mine needs your git user.name (git config user.name \"…\")"

rows=$(item_sources | while IFS="$(printf '\t')" read -r o r p; do item_row "$o" "$r" "$p"; done |
	awk -F '\t' '$10 == "archive" || $3 == "open"')

# Pick the rows, then turn facts into the four cells: item, state, who, when. The fields are
# item_row's (lib/common.sh): $1 id, $3 status, $4 phase, $6/$7 tasks, $8 title,
# $11 questions open, $12 approved by, $13 opened by, $15 active, $16 reason, $17 reason code.
cells=$(printf '%s\n' "$rows" | TODAY=$(date +%F) SINCE=$since LAST=$last MINE=$mine ME=$me awk -F '\t' '
	function days(d,   y, m, dd, era, yoe, doy, doe) {
		y = substr(d, 1, 4) + 0; m = substr(d, 6, 2) + 0; dd = substr(d, 9, 2) + 0
		if (m <= 2) y--
		era = int((y >= 0 ? y : y - 399) / 400); yoe = y - era * 400
		doy = int((153 * (m + (m > 2 ? -3 : 9)) + 2) / 5) + dd - 1
		doe = yoe * 365 + int(yoe / 4) - int(yoe / 100) + doy
		return era * 146097 + doe
	}
	function plural(n, w) { return n " " w (n == 1 ? "" : "s") }
	function state(   s, extra) {
		if ($3 == "shipped") return "shipped"
		if ($3 == "dropped") return "dropped"
		if ($4 == "plan") {
			if ($17 == "fill") return "planning: " $16
			if ($17 == "changed") s = "planning: the plan changed after approval; it needs re-approval"
			else if ($11 > 0) s = "planning: " plural($11, "open question") "; then approval"
			else s = "planning: plan ready, waiting for approval"
			return s
		}
		extra = ($7 > 0) ? "; " $6 "/" $7 " tasks done" : ""
		if ($4 == "build") return ($17 == "built" ? "building: check passed, Built not written yet" : "building: no passing check yet") extra
		if ($4 == "review?") return "in review? (its check ran on a teammate'"'"'s machine)" extra
		if ($4 == "review") return "in review: check passed, Built written; ready to review and ship" extra
		return $4
	}
	function when(d,   n) {
		if (d == "") return "-"
		n = days(ENVIRON["TODAY"]) - days(d)
		return n == 0 ? "today" : n == 1 ? "yesterday" : n < 7 ? n " days ago" : d
	}
	BEGIN {
		today = days(ENVIRON["TODAY"]); s = ENVIRON["SINCE"]
		if (s == "") cut = today - 7
		else if (s == "today") cut = today
		else if (s == "yesterday") cut = today - 1
		else if (s ~ /d$/) cut = today - substr(s, 1, length(s) - 1)
		else cut = days(s)
	}
	$3 == "dropped" { next }
	ENVIRON["MINE"] != "" && $13 != ENVIRON["ME"] && $12 != ENVIRON["ME"] { next }
	{
		act = ($15 == "" ? -1 : days($15))
		if (ENVIRON["LAST"] == "") {
			# Default: open items always; anything else only inside the window.
			if (!(ENVIRON["SINCE"] == "" && $3 == "open") && act < cut) next
		}
		who = ($13 == "" ? $12 : $13)
		if ($12 != "" && $12 != $13 && $13 != "") who = $13 ", approved by " $12
		if (who == "") who = "-"
		printf "%d\t%s\t%s (%s)\t%s\t%s\t%s\n", act, $1, $1, $8, state(), who, when($15)
	}' | sort -t "$(printf '\t')" -k1,1nr -k2,2nr | { if [ -n "$last" ]; then head -n "$last"; else cat; fi } |
	sort -t "$(printf '\t')" -k2,2n | cut -f3-)

if [ -z "$cells" ]; then
	echo "nothing in this window"
	echo "next    $CMD summary --since 30d, or $CMD ls"
	exit 0
fi

if [ "$fmt" = md ]; then
	printf '%s\n' "$cells" | awk -F '\t' '
		function cell(s) { gsub(/\|/, "\\|", s); return s }
		BEGIN { print "| item | state | who | when |"; print "|---|---|---|---|" }
		{ printf "| %s | %s | %s | %s |\n", cell($1), cell($2), cell($3), cell($4) }'
	exit 0
fi

# Box table. Widths count characters, not bytes (UTF-8 lead bytes only), so å and é line up.
printf '%s\n' "$cells" | LC_ALL=C W=${COLUMNS:-100} F=$fmt awk -F '\t' '
	function clen(s) { gsub(/[\200-\277]/, "", s); return length(s) }
	function cut(s, n,   i, c, out) {
		out = ""; c = 0
		for (i = 1; i <= length(s); i++) {
			if (substr(s, i, 1) !~ /[\200-\277]/) { if (c == n) break; c++ }
			out = out substr(s, i, 1)
		}
		return out
	}
	function pad(s, w) { while (clen(s) < w) s = s " "; return s }
	function rep(s, n,   o) { o = ""; while (n-- > 0) o = o s; return o }
	# wrap(text, width, lines): word wrap into lines[1..n]; returns n. Overlong words are cut.
	function wrap(t, w, L,   n, word, line, k, i, words) {
		if (w < 1) w = 1
		n = 0; line = ""
		k = split(t, words, " ")
		for (i = 1; i <= k; i++) {
			word = words[i]
			while (clen(word) > w) {
				if (line != "") { L[++n] = line; line = "" }
				L[++n] = cut(word, w); word = substr(word, length(cut(word, w)) + 1)
			}
			if (line == "") line = word
			else if (clen(line) + 1 + clen(word) <= w) line = line " " word
			else { L[++n] = line; line = word }
		}
		if (line != "" || n == 0) L[++n] = line
		return n
	}
	function hline(l, m, r,   i, o) {
		o = l
		for (i = 1; i <= 4; i++) o = o rep(H, w[i] + 2) (i < 4 ? m : r)
		print o
	}
	function row(c1, c2, c3, c4,   a, b, c, d, na, nb, nc, nd, n, i) {
		na = wrap(c1, w[1], a); nb = wrap(c2, w[2], b); nc = wrap(c3, w[3], c); nd = wrap(c4, w[4], d)
		n = na; if (nb > n) n = nb; if (nc > n) n = nc; if (nd > n) n = nd
		for (i = 1; i <= n; i++)
			print V " " pad(i <= na ? a[i] : "", w[1]) " " V " " pad(i <= nb ? b[i] : "", w[2]) " " V " " \
				pad(i <= nc ? c[i] : "", w[3]) " " V " " pad(i <= nd ? d[i] : "", w[4]) " " V
	}
	{ for (i = 1; i <= 4; i++) { cell[NR, i] = $i; if (clen($i) > max[i]) max[i] = clen($i) } }
	END {
		if (ENVIRON["F"] == "ascii") { H = "-"; V = "|"; TL = TM = TR = ML = MM = MR = BL = BM = BR = "+" }
		else { H = "─"; V = "│"; TL = "┌"; TM = "┬"; TR = "┐"; ML = "├"; MM = "┼"; MR = "┤"; BL = "└"; BM = "┴"; BR = "┘" }
		split("item state who when", head, " ")
		for (i = 1; i <= 4; i++) if (clen(head[i]) > max[i]) max[i] = clen(head[i])
		# 13 characters go to borders and padding. who and when keep their width until the
		# item and state columns would drop below 24 together; then who shrinks too.
		w[4] = max[4]; w[3] = (max[3] > 24 ? 24 : max[3])
		room = ENVIRON["W"] - 13 - w[3] - w[4]
		if (room < 24) { w[3] -= 24 - room; if (w[3] < 4) w[3] = 4; room = ENVIRON["W"] - 13 - w[3] - w[4] }
		if (room < 16) room = 16
		w[1] = (max[1] > 30 ? 30 : max[1]); if (w[1] > int(room * 0.4)) w[1] = int(room * 0.4)
		if (w[1] < 6) w[1] = 6
		w[2] = room - w[1]; if (w[2] > max[2]) w[2] = max[2]; if (w[2] < 10) w[2] = 10
		hline(TL, TM, TR)
		row(head[1], head[2], head[3], head[4])
		for (r = 1; r <= NR; r++) {
			hline(ML, MM, MR)
			row(cell[r, 1], cell[r, 2], cell[r, 3], cell[r, 4])
		}
		hline(BL, BM, BR)
	}'

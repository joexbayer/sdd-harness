# shellcheck shell=sh
# approve: the human's hand-off from planning to the agent's hands-off build. Pins a hash
# of the plan (everything above "## Built") and commits it; editing the plan afterwards
# clears the approval.
[ $# -eq 0 ] || usage_die "usage: $NAME approve"
human_only approve
need_repo
current_item || die "not on an item branch (see: $CMD status)"
fm_closed "$IFILE" || die "item $ID: $FM_OPEN"
[ "$(fm_get status "$IFILE")" = open ] || die "item $ID is not open"

missing=$(missing_sections "$IFILE" plan)
[ -z "$missing" ] || die "the plan is incomplete (empty: $(joinlist "$missing"))"
if approval_ok; then
	echo "item $ID: the plan is already approved and unchanged"
	exit 0
fi
# The analyzed gate (FR-19.2): the problems analyze finds warn or block, at this type's level.
level=$(gate_level analyzed "$ITYPE")
if [ "$level" != off ]; then
	found=$(parse_item "$IFILE" "$ID" | plan_findings | findings_lines)
	if [ -n "$found" ]; then
		printf '%s\n' "$found" >&2
		[ "$level" != block ] || die "the plan has the problems above: fix them, then approve again (see: $CMD analyze)"
		warn "the plan has the problems above; approving anyway (gate analyzed: $level)"
	fi
fi

who=$(git config user.name || echo unknown)
fm_set "$IFILE" approved "$(plan_hash "$IFILE") $(date +%F) $who"
git add -- "$IFILE" || die "could not add $IFILE"
git commit -q -m "docs($ID): approve plan" -- "$IFILE" || die "could not commit $IFILE"

echo "✓ plan for item $ID approved by $who"
echo "next    tell the agent to build; it works hands-off from $CMD next. When it is done, you run: $CMD review"

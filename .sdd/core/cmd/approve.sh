# shellcheck shell=sh
# approve: the human's hand-off from planning to the agent's hands-off build. Pins a hash
# of the plan (everything above "## Built") and commits it; editing the plan afterwards
# clears the approval.
[ $# -eq 0 ] || usage_die "usage: $NAME approve"
need_repo
current_item || die "not on an item branch (see: $CMD status)"
[ "$(fm_get status "$IFILE")" = open ] || die "item $ID is not open"

missing=$(missing_sections "$IFILE" plan)
[ -z "$missing" ] || die "the plan is incomplete (empty: $(joinlist "$missing"))"
if approval_ok; then
	echo "item $ID: the plan is already approved and unchanged"
	exit 0
fi

who=$(git config user.name || echo unknown)
fm_set "$IFILE" approved "$(plan_hash "$IFILE") $(date +%F) $who"
git add -- "$IFILE" || die "could not add $IFILE"
git commit -q -m "docs($ID): approve plan" -- "$IFILE" || die "could not commit $IFILE"

echo "✓ plan for item $ID approved by $who"
echo "next    tell the agent to build; it works hands-off from $CMD next. When it is done, you run: $CMD review"

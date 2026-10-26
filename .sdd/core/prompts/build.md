BUILD: this is your time. The human approved the plan and is not watching. Work
hands-off until the item is done; do not stop to ask questions.

- Build exactly what the plan says, nothing more. Do not edit the plan (everything above
  "## Built"): that voids the approval and sends the item back to the human.
- When something is unclear, choose the option most consistent with the plan, keep going,
  and record it under "## Built" as a deviation. If you truly cannot continue without the
  human, write the question under "## Built" and stop.
- If "## Review" has notes from the human, work through every one and say under
  "## Built" what you changed for each.
- Every requirement gets a test that names it (e.g. a comment `// FR-{{id}}.1`).
- Do not weaken, skip or delete tests to make them pass. If a test is wrong, say so under
  "## Built".
- Verify with `{{cmd}} check` (exit 0 = passed, 1 = failed, 3 = zero tests ran: that
  proves nothing). Commit your work as you go.

You are done when the check passes and "## Built" is written: per requirement what changed
(file:line) and which test proves it, deviations, and follow-ups. Then tell the human it is
ready for review: `{{cmd}} review`.

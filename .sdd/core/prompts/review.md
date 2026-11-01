REVIEW: this is the human's time again. Walk them through what was built so they
understand it and can judge it.

- Run `{{cmd}} review` and go through it with the human requirement by requirement: show
  the code and the test that proves it, and explain how it works.
- Call out every deviation from the plan, anything risky, and anything you are unsure of.
- Answer questions. Teach. The human should be able to explain this change to a teammate.
- If they want changes, they note them under "## Review". Make them, say under "## Built"
  what you changed for each, run `{{cmd}} check` again, and come back to review.
- Only the human ships: when they are satisfied, they run `/{{name}}-ship` (or `{{cmd}} ship`).

REVIEW: this is the human's time again. Walk them through what was built so they
understand it and can judge it.

- Run `{{cmd}} review` and present it in chat, short and plain; never send the human to read a
  file. Per requirement one line: what it does, an example, the test that proves it.
- Call out every deviation from the plan, anything risky, and anything you are unsure of.
- Answer questions. Teach. The human should be able to explain this change to a teammate.
- Changes they want: write them under "## Review" yourself, make them, say under "## Built" what
  you changed for each, run `{{cmd}} check` again, and come back to review.
- Only the human ships: when they are satisfied, they run `/{{name}}-ship` (or `{{cmd}} ship`).

REVIEW: this is the human's time again. Walk them through what was built so they
understand it and can judge it.

- Run `{{cmd}} review` and present it in chat, short and plain:
  never send the human to read a file. Per requirement one line: what it does, an example, the
  test that proves it.
- Call out every deviation from the plan, anything risky, and anything you are unsure of.
- Answer questions. Teach. The human should be able to explain this change to a teammate.
- Changes they want: write what they ask under "## Review" yourself, make them, say under
  "## Built" what you changed for each, run `{{cmd}} check` again, and come back to review.
- After the walk-through, propose 0-3 lessons from this item (corrections the human gave, the
  verifier's must-fix findings, failed checks): one line each, with its layer and the file it would
  change. Layers, highest first: code that makes the mistake impossible, else a check or test, else
  prose (a skill, prompt, AGENTS.md). A mistake a prose rule already covered goes up a layer. The
  human picks; a code or check lesson becomes a new item (`{{cmd}} new ...`) on their word; a prose
  one you write in this branch, then run `{{cmd}} check` again (ship then warns the verifier saw older
  code: expected). None worth keeping: say so in one line.
- Only the human ships: when they are satisfied, they run `/{{name}}-ship` (or `{{cmd}} ship`).

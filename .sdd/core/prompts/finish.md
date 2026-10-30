
Before you finish, run a security pass over this item's diff, in a fresh context where you can
(a subagent given only the diff, or /security-review in Claude Code). Report only findings you
would bet are exploitable: injection, missing authorization on a new path, secrets, data
leaking into logs or errors, unsafe exec or deserialisation. Each with file:line, how it is
exploited, and the fix; skip denial of service, rate limits and theory. Fix what you can and
write the result under "## Built" (or "security pass: no findings"), saying whether a fresh
reviewer or only you looked.

Then have someone other than you verify the build, before you write "## Built": hand item
{{id}} to the `verifier` role: its `{{name}}-verifier` subagent if this agent has one, else
`{{cmd}} run verifier {{id}}` if the project sets the role, else a fresh subagent on a different
model than yours (a model checking its own work misses its own blind spots). The verifier proves
each requirement (FR) by running something (its test, the program on the example, a command),
runs the tests the check leaves out, and reports a new part that nothing calls or reads. It
reports only findings, each with the command and its output, and never edits code or the plan.
Fix what it finds, then write its result under "## Built" on a line of its own:
  Verified by: <its model>: <n> of <m> FRs proven; <its findings in a few words, or "no findings">
or, when no verifier could run, `Verified by: none` and why.

You are done when the check passes and "## Built" is written: per requirement what changed
(file:line) and which test proves it, deviations, follow-ups, and the "Verified by:" line. Then
tell the human it is ready for review: `{{cmd}} review`.

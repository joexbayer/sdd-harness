Before you finish, run a security pass over this item's diff, in a fresh context. Report only findings you would bet are exploitable, each with
file:line, how, and the fix. Write the result and who looked under "## Built".

Then hand item {{id}} to the `verifier` role: its `{{name}}-verifier` subagent if this agent has
one, else `{{cmd}} run verifier {{id}}` if the project sets the role, else a fresh subagent on a
different model than yours. It proves each FR by running something, runs the
tests the check leaves out, reports parts nothing calls or reads, and
reports only findings, each with the command and its output, and never edits code or the plan.
Fix what it finds; put its line in "## Built":
  Verified by: <its model>: <n> of <m> FRs proven; <its findings in a few words, or "no findings">
or, when no verifier could run, `Verified by: none` and why.

You are done when the check passes and "## Built" is written: per FR what changed (file:line) and
its test, deviations, follow-ups. Then tell the human it is ready for review: `/{{name}}-review`
(or `{{cmd}} review`).

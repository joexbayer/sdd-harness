
Before you finish, run a security pass over this item's diff, in a fresh context where you can
(a subagent given only the diff, or /security-review in Claude Code). Report only findings you
would bet are exploitable: injection, missing authorization on a new path, secrets, data
leaking into logs or errors, unsafe exec or deserialisation. Each with file:line, how it is
exploited, and the fix; skip denial of service, rate limits and theory. Fix what you can and
write the result under "## Built" (or "security pass: no findings"), saying whether a fresh
reviewer or only you looked.

You are done when the check passes and "## Built" is written: per requirement what changed
(file:line) and which test proves it, deviations, and follow-ups. Then tell the human it is
ready for review: `{{cmd}} review`.

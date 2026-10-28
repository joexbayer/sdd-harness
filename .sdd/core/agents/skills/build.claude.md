In Claude Code: the builder subagent is `.claude/agents/{{name}}-builder.md` (written by
`{{cmd}} sync claude` when the builder role's tier runs on Claude). Spawn it with the Agent tool,
subagent type `{{name}}-builder`, one call per batch, and wait for it before the next batch.

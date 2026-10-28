In Claude Code: the role subagents are in `.claude/agents/{{name}}-<role>.md` (written by
`{{cmd}} sync claude` for roles whose tier runs on Claude). Spawn one with the Agent tool and
that subagent type; a role without such a file runs through `{{cmd}} run`.

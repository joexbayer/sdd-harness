---
type: research
status: active
review_by: 2027-01-27
sources:
  - https://code.claude.com/docs/en/sub-agents.md (Claude Code docs; retrieved 2026-10-27)
  - https://code.claude.com/docs/en/hooks.md (retrieved 2026-10-27)
  - https://code.claude.com/docs/en/headless.md (retrieved 2026-10-27)
  - https://code.claude.com/docs/en/agent-sdk/cost-tracking.md (retrieved 2026-10-27)
  - narrow docs/design/json-events.md (the finish event; read 2026-10-27)
trust: untrusted
---
# Running roles as Claude Code subagents, and reading their usage

- **Subagent files** `.claude/agents/<name>.md`: frontmatter `name`, `description` (required),
  `model` (opus, sonnet, haiku, fable, a full ID, or inherit), `tools`, `permissionMode`, …;
  unknown fields are ignored. The main agent delegates by matching `description`, or when asked
  by name. Subagents can run Bash. Only Claude models: a non-Claude builder needs a CLI.
- **Hooks** `SubagentStart` (agent_id, agent_type) and `SubagentStop` (agent_id, agent_type,
  agent_transcript_path, last_assistant_message). Matchers are agent type names. Hooks may live
  in `.claude/settings.local.json`.
- **Tokens are in no hook payload.** Sum `message.usage` (input_tokens, output_tokens,
  cache_creation_input_tokens, cache_read_input_tokens) over the subagent's transcript
  (`<session>/subagents/agent-<id>.jsonl`), deduplicated by message id. The transcript layout is
  internal and may change between versions: pin and re-check. PostToolUse on the Agent tool
  reports only the final request's usage.
- **`claude -p --output-format json`**: a result object with `total_cost_usd`, `usage`,
  `modelUsage`, `duration_ms`, `num_turns`, `is_error`, `result` (verify with one run).
  `--bare` skips hooks and `.claude/agents`.
- **Narrow `--json`**: the last event is `finish` with `exit`, `verdict`, `tokens {in, out}`,
  `cost` (only when the model is priced).

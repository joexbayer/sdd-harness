---
type: research
status: active
review_by: 2027-01-26
sources:
  - https://agents.md/ (retrieved 2026-10-26)
  - https://code.claude.com/docs/en/memory#agents-md (retrieved 2026-10-26)
  - https://code.claude.com/docs/en/hooks (retrieved 2026-10-26)
  - https://code.claude.com/docs/en/headless (retrieved 2026-10-26)
  - https://learn.chatgpt.com/docs/hooks (retrieved 2026-10-26)
  - https://learn.chatgpt.com/docs/non-interactive-mode (retrieved 2026-10-26)
  - https://geminicli.com/docs/hooks/ (retrieved 2026-10-26)
  - https://developers.googleblog.com/an-important-update-transitioning-gemini-cli-to-antigravity-cli/ (2026-05-19)
  - https://cursor.com/docs/hooks (retrieved 2026-10-26)
  - https://cursor.com/docs/cli/reference/parameters (retrieved 2026-10-26)
  - https://docs.github.com/en/copilot/reference/hooks-configuration (retrieved 2026-10-26)
  - https://opencode.ai/docs/plugins/ (retrieved 2026-10-26)
  - https://kiro.dev/docs/hooks/ (retrieved 2026-10-26)
  - https://github.com/intellectronica/ruler (retrieved 2026-10-26)
  - https://github.com/dyoshikawa/rulesync (retrieved 2026-10-26)
trust: untrusted
---
# Working with any coding agent

The agent landscape moves fast. Gemini CLI became Antigravity CLI (`agy`) for individuals in
June 2026, and Codex replaced custom prompts with skills. Re-check this note by its
`review_by` date.

## Instruction files
- **AGENTS.md is the common floor.** Read natively by Codex, Cursor, Copilot, opencode, Aider,
  Amp, Zed, Warp, Devin/Windsurf, Kiro, goose, Junie, and Gemini (via `context.fileName`). The
  nearest file wins.
- **Claude Code** reads AGENTS.md only when there is no CLAUDE.md. The supported pattern is a
  CLAUDE.md that says `@AGENTS.md`.
- **Copilot** merges AGENTS.md, CLAUDE.md, GEMINI.md and copilot-instructions.md with no
  precedence.
- **Sync tools** (Ruler, Rulesync) generate per-agent files. They are Node-based; Ruler is beta.

## Hooks (all can deny a tool call before it runs)
| agent | config | events we use | stop reply |
|---|---|---|---|
| Claude Code | `.claude/settings[.local].json` | SessionStart, Stop (+ PreToolUse …) | `{"decision":"block","reason":…}` or `{"systemMessage":…}`; stdin has `stop_hook_active` |
| Codex | `.codex/hooks.json` (same nesting as Claude) | SessionStart, Stop | same as Claude; Stop stdout must be JSON; project hooks need trust via `/hooks` |
| Gemini / agy | `.gemini/settings.json` | SessionStart, AfterAgent | exit 2 or `{"decision":"deny"}` (agy unverified) |
| Cursor | `.cursor/hooks.json` | sessionStart, stop | stop cannot block, but can send a follow-up |
| Copilot | `.github/hooks/*.json` | sessionStart, agentStop | agentStop can force another turn |
| opencode | JS/TS plugin | `session.idle`, `tool.execute.before` | throw to block |
| Kiro | `.kiro/hooks/` | PreToolUse, Stop | PreToolUse can gate |

SessionStart plain stdout becomes context in both Claude Code and Codex.

## Headless runs (for model routing)
| agent | command | model flag | unattended | JSON |
|---|---|---|---|---|
| Claude Code | `claude -p` | `--model` | `--permission-mode`, `--allowedTools` | `--output-format json` |
| Codex | `codex exec` | `-m` (unverified) | `--sandbox read-only\|workspace-write` | `--json`, `--output-schema` |
| Gemini | `gemini -p` | `-m` | `--approval-mode`, `-s` | `-o json` |
| Cursor | `cursor-agent -p` | `--model` | `--sandbox`, `--force` | `--output-format json` |
| Copilot | `copilot -p` | `--model` | `--allow-tool` | unconfirmed |
| opencode | `opencode run` | `-m provider/model` | `--auto` | `--format json` |
| Kiro | `kiro-cli chat --no-interactive` | `--model` | `--trust-tools` | `--output-format stream-json` |

## Skills and MCP
- **Skills** (agentskills.io) are loaded by Claude Code, Cursor (`.agents/skills`,
  `.claude/skills`), Codex, Copilot and Kiro. They are the closest thing to a universal slash
  command.
- **Skill folders (checked 2026-10-26):** Claude Code reads `.claude/skills/<name>/SKILL.md`.
  Codex reads `.agents/skills/` in the project first, then `~/.agents/skills/` and
  `/etc/codex/skills/`; the official page confirms CLI support but its excerpt shows no path,
  so the path comes from community guides (one older page says `.codex/skills/`). opencode
  reads `.opencode/skills/`, `.claude/skills/` and `.agents/skills/`, walking up to the git
  worktree, needs `name` to match the folder name, and warns about duplicate IDs. Sources:
  https://developers.openai.com/codex/skills ,
  https://codex.danielvaughan.com/2026/05/05/agent-skills-open-standard-portable-skills-codex-cli-cross-agent/ ,
  https://opencode.ai/docs/skills (all retrieved 2026-10-26).
- **MCP:** tools work over stdio and HTTP almost everywhere. Support for prompts and resources
  varies, so don't rely on them.

## Gaps
Not yet verified:

- Antigravity's context file, hook file and skill paths
- Amp CLI flags
- Copilot CLI JSON output
- Codex skill paths and the `-m` flag
- MCP prompt support per agent

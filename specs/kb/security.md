---
type: research
status: active
review_by: 2027-04-26
sources:
  - https://simonwillison.net/2025/Jun/16/the-lethal-trifecta/ (2025-06-16)
  - https://ai.meta.com/blog/practical-ai-agent-security/ (Agents Rule of Two, 2025-10-31)
  - https://code.claude.com/docs/en/security (retrieved 2026-10-26)
  - https://code.claude.com/docs/en/sandboxing (retrieved 2026-10-26)
  - https://learn.chatgpt.com/docs/agent-approvals-security.md (retrieved 2026-10-26)
  - https://modelcontextprotocol.io/specification/2025-06-18/basic/security_best_practices (2025-06-18)
  - https://research.checkpoint.com/2026/rce-and-api-token-exfiltration-through-claude-code-project-files-cve-2025-59536/ (2026-02-25)
  - https://wiz.io/blog/s1ngularity-supply-chain-attack (Nx, 2025-08)
  - https://posthog.com/handbook/company/post-mortems/2025-11-26-shai-hulud-attack.md (2025-11-26)
  - https://invariantlabs.ai/blog/mcp-github-vulnerability (2025-05-26)
  - https://www.giskard.ai/knowledge/owasp-top-10-for-agentic-application-2026 (2nd-hand)
  - https://direnv.net/man/direnv.1.html, https://mise.jdx.dev/cli/trust.html (retrieved 2026-10-26)
  - https://github.com/gitleaks/gitleaks (retrieved 2026-10-26)
trust: untrusted
---
# Security model: proportionate, not paranoid

## Frames
- **Lethal trifecta (Willison):** private data + untrusted content + external communication.
  The only reliable defence is never combining all three.
- **Rule of Two (Meta):** per session, at most two of: untrusted input, sensitive data/systems,
  and changing state or communicating externally. Needing all three requires a human or a fresh
  session.
- **Prompt injection is unsolved.** It is reported at ~1% for top models in browser use, and
  rises sharply with repeated attempts (second-hand). Controls limit the blast radius; they do
  not prevent a hijack.

## Threats for sdd (likelihood × impact) and the cheapest control
1. **Untrusted text (web, issues, PR comments) steers an agent that holds tokens and can push.**
   Per-role capability profiles: the researcher has web access but no secrets or write; the
   builder has write but no web; publishing is done by sdd's ship, not an agent. Enforced with
   agent sandbox flags.
2. **Poisoned research persists in the kb (OWASP ASI06).** Provenance and `trust: untrusted`;
   strip invisible Unicode and HTML comments; fence untrusted notes in prompts; merge only
   through review.
3. **Repo-executable config runs without a trust gate.** Headless `claude -p` skips the trust
   dialog. CVE-2025-59536 ran project code before trust was given. Control: `sdd trust` hashes
   `.sdd/` per user (like `direnv allow` / `mise trust`).
4. **Credential exposure.** Nx s1ngularity used local AI CLIs to harvest tokens. Controls:
   - give spawned agents an env allowlist;
   - deny reads of `~/.ssh`, `~/.aws` and `.env*`;
   - run gitleaks in pre-commit and CI, including over `specs/`.
5. **Supply chain** (agent-run installs, the vendored tool itself). Lockfiles, `ignore-scripts`,
   a pinned version with checksums, upgrades through a reviewed commit.
6. **Destructive mistakes** (no injection needed). Branch protection, work on branches, never
   default to skip-permission flags.
7. **MCP.** Our server is read-only and uses bearer tokens with fixed-schema tools: no shell tool
   and no third-party servers by default. Local MCP is stdio only.

## Not worth it for a small private team
- injection classifiers, or prompt hardening as a control;
- signing, SLSA or SBOMs for the tool;
- a VM per run by default;
- MCP OAuth;
- approving every tool call ("always allow" fatigue is the real failure);
- our own secret scanner or egress proxy.

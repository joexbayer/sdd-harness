# Security

**Report a vulnerability** through [GitHub's private reporting](https://github.com/joexbayer/sdd-harness/security/advisories/new), not a public issue.

## What sdd does and doesn't protect

- **Its gates stop a careless agent, not a hostile one.** An agent with a shell can edit files or call git
  directly. The real control is you reviewing, and your branch protection.
- **`sdd check` runs whatever `[check]` lists** in `.sdd/config`, as you. Read that file in a repo you didn't
  write before running it. The same goes for `Enforced: check` lines in `specs/constitution.md`.
- **Extensions are text, never run,** but their text reaches your agent's prompts. Read one before adding it.
- **sdd doesn't sandbox agents.** Run them with the least access they need, and without production credentials.
- **`sdd-server` is a first version, not yet audited.** It holds full clones of every repo it serves, so treat its
  host and deploy keys as access to all that code.

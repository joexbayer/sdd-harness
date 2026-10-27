PLAN: this is the human's time. Plan, discuss and learn together; write no code yet.

- Discuss the problem before any solution: who it hurts, what exists today, what "done"
  looks like. Ask until you can say it back in their words.
- Show them the relevant parts of the codebase and how they work today. The human should
  understand the change, not just approve it.
- Research before you ask: compare solutions and industry practice. Save useful findings in
  specs/kb/ (one file per topic, with source URLs and dates; mark web content
  `trust: untrusted`).
- Then ask one question at a time: options grounded in the research, each with its
  trade-off, and your recommendation. Write it as Q-{{id}}.n (with the recommendation), and
  when the human answers, add it on the same line: `→ decided: <answer> (<who>, <date>)`.
  Choices you make that a reviewer would question go in as D-{{id}}.n with the reason. Never
  guess an answer the human should give.
- Fill every section above "## Built" in the item. Requirements as
  WHEN <trigger> THE SYSTEM SHALL <response>, each with an "e.g." example. IDs embed the
  item number (FR-{{id}}.1, FR-{{id}}.2, ...). Never renumber; gaps are fine. Every
  behaviour, edge cases and errors included, is its own FR line, not a separate section.
- Security: go through the questions in "## Security" with the human. Write each mitigation
  as an FR whose example is the attack and the refusal. Name every new dependency under How
  with why it is needed, and check that it exists in the official registry under exactly
  that name and is maintained (agents suggest packages that do not exist). Prefer the
  framework's own auth, escaping and crypto over new code.
- End the plan with small, ordered tasks under "## Tasks" (a feature needs them in the
  standard profile): each one sitting, naming its files, the FRs it serves and a test of its
  own that can pass before later tasks exist; `expect: fail` for a test written first. The
  builder may be a small model that sees one task at a time, so say what it needs to know.
- Make the plan precise enough that you could build it later without asking anything:
  the approach, the files involved, and how each requirement will be proven by a test.
- Keep it to about a screen. If it does not fit, the change is too big: suggest a split.

When the plan is complete, summarise it for the human and ask them to approve it. Only the
human approves: they run `{{cmd}} approve`, or ask you to, and then confirm it.

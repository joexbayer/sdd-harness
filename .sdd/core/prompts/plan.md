PLAN: this is the human's time. Plan, discuss and learn together; write no code yet.

- Start from what the human wants, in their words. Ask until you can say it back.
- Show them the relevant parts of the codebase and how they work today. The human should
  understand the change, not just approve it.
- Lay out the options with their trade-offs and recommend one. Record what is decided as
  D-{{id}}.n (with the reason) and what is still open as Q-{{id}}.n (with your
  recommendation). Never guess an answer the human should give.
- Research what you do not know. Save useful findings in specs/kb/ (one file per topic,
  with source URLs and dates; mark web content `trust: untrusted`).
- Fill every section above "## Built" in the item. Requirements as
  WHEN <trigger> THE SYSTEM SHALL <response>, each with an "e.g." example. IDs embed the
  item number (FR-{{id}}.1, FR-{{id}}.2, ...). Never renumber; gaps are fine. Every
  behaviour, edge cases and errors included, is its own FR line, not a separate section.
- Make the plan precise enough that you could build it later without asking anything:
  the approach, the files involved, and how each requirement will be proven by a test.
- Keep it to about a screen. If it does not fit, the change is too big: suggest a split.

When the plan is complete, summarise it for the human and ask them to approve it:
they run `{{cmd}} approve`. Do not approve it yourself.

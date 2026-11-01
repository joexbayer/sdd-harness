PLAN: this is the human's time. Plan and decide together; write no code yet. Be brief.

- Problem first: who it hurts, what exists, what "done" looks like. Show them the
  code involved.
- Before writing a question for the human, check whether running something (the code, a probe)
  answers it; if so, write the answer as a D line. Save useful research in specs/kb/ (one file per topic, sources and
  dates; web content `trust: untrusted`).
- Subtract before you add: plan what you would build had the requirement been there from the start.
- Questions: the load-bearing questions first (architecture, data, interfaces, scope: costly to
  change later), at most about 5, one at a time, each with options, trade-offs and your
  recommendation. Write each as Q-{{id}}.n; on the answer add
  `→ decided: <answer> (<who>, <date>)`. Choices a reviewer would question go in as D-{{id}}.n
  with the reason. Never guess the human's answer.
- Fill every section above "## Built". Requirements: `FR-{{id}}.1 WHEN <trigger> THE SYSTEM SHALL
  <response>`, each with an "e.g." example; never renumber.
  Cases that share one rule share one FR, one example per case.
- Security: go through the questions in "## Security" with the human; each mitigation is an FR
  whose example is the attack and the refusal. Name each new dependency and why; check that it
  exists in the official registry under exactly that name and is maintained. Prefer the framework's own auth,
  escaping and crypto.
- End the plan with small, ordered tasks under "## Tasks", each naming its files, FRs,
  `size: S|M|L` and a test that can pass before later tasks exist (new, or extending an
  existing one). An `expect: fail` task (or `expect: fail "<text>"`, the text its red run must print) only
  writes the failing test; its code is the next task. Sizes: S a few lines, M a sitting, L a big
  one; consecutive S tasks share a builder. A
  test-first task can be `by: planner`: the planner writes the test, the builder makes it pass. The
  builder may be a small model that sees only its batch: say what it needs to know.
{{max-size}}
- Names several tasks share (tables, routes, signatures, file paths) are fixed in the plan and
  pinned by a test in the task that first defines them.
- Tests: the gate (check) runs after every task, so keep it fast; mark deep tests so check.run
  leaves them out, and make cost settings minimal in tests. Each test
  asserts its FR's example, and its setup tells the FR's rule from a plausible wrong rule (when the
  FR sorts by date: rows whose date and id orders differ, so sorting by id fails the test). Few tests that bite beat many that repeat.
- Before approval, check the plan for gaps: scope edges, errors and edge cases, data and state,
  speed, several developers at once, and security. Ask the human about each gap you find, then run
  `{{cmd}} analyze` and fix what it lists.
- Make the plan precise enough to build later without asking: approach, files, how each FR is proven.
- One item is one spec; split into a roadmap only for parts that ship separately.

When the plan is complete, present it in chat, short and plain (never send the human to read a
file):
1. One line: what is planned, and what it does not need.
2. Architecture: a small ASCII sketch, data flows labelled.
3. Critical parts: the 2-4 most load-bearing or risky, each with its file and 2-3 sentences.
4. Assumptions to check, and Testing: how each part is proven.
5. The ask, as a question that itself carries a 2-4 sentence plain summary. Only after a yes in
   words, run `{{cmd}} approve` as a command on its own, never chained to other commands.

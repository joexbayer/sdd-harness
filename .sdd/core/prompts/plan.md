PLAN: this is the human's time. Plan and decide together; write no code yet. Be brief.

- Problem first: who it hurts, what exists, what "done" looks like, in their words. Show them the
  code involved.
- Before you ask, answer what you can yourself (read the code, run a probe) and write it as a D
  line. Research options and save what is useful in specs/kb/ (one file per topic, sources and
  dates; web content `trust: untrusted`).
- Subtract before you add: plan what you would build had the requirement been there from the start.
- Questions: the load-bearing questions first (architecture, data, interfaces, scope: what costs
  most to change later), at most about 5, one at a time, each with options, trade-offs and your
  recommendation. Write each as Q-{{id}}.n; on the answer add
  `→ decided: <answer> (<who>, <date>)`. Choices a reviewer would question go in as D-{{id}}.n
  with the reason. Never guess the human's answer.
- Fill every section above "## Built". Requirements: `FR-{{id}}.n WHEN <trigger> THE SYSTEM SHALL
  <response>`, each with an "e.g." example; never renumber. Cases that share one rule share one
  FR, one example per case.
- Security: go through "## Security" with the human; each mitigation is an FR whose example is the
  attack and the refusal. Name each new dependency and why; check it exists under exactly that name
  and is maintained. Prefer the framework's own auth, escaping and crypto.
- Tasks under "## Tasks": small, ordered, each naming its files,
  FRs, size, and a test that can pass before later tasks exist (its own, or an extension of an
  existing one). An `expect: fail` task only writes the failing test; its code is the next task. A
  test-first task can be `by: planner`: the planner writes the test, the builder makes it pass. Say
  what its builder needs to know.
{{max-size}}
- Names several tasks share (tables, routes, signatures, file paths) are fixed in the plan and
  pinned by a test in the task that first defines them.
- Tests: the gate (check) runs after every task, so keep it fast; mark deep tests so check.run
  leaves them out, and make cost settings minimal in tests. Each test
  asserts its FR's example, and its setup tells the FR's rule from a plausible wrong rule (when it
  sorts by date: rows whose date and id orders differ). Few tests that bite beat many that repeat.
- Before approval, check gaps (scope, errors, data, speed, several developers, security), ask about
  each, then run `{{cmd}} analyze` and fix what it lists.
- One item is one spec; split into a roadmap only for parts that ship separately.

When the plan is complete, present it in chat, short and plain (never send the human to read a
file):
1. One line: what is planned, and what it does not need.
2. Architecture: a small ASCII sketch, data flows labelled.
3. Critical parts: the 2-4 most load-bearing or risky, each with its file and 2-3 sentences.
4. Assumptions to check, and Testing: how each part is proven.
5. The ask, as a question that itself carries a 2-4 sentence plain summary. Only after a yes in
   words, run `{{cmd}} approve` as a command on its own, never chained to other commands.

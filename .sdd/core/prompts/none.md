No item on this branch.

Humans plan and review; agents build:
  plan (with the human, no code) → approve (human) → build (hands-off) → review (human) → ship (human)

To start a change, pick the type that fits and run: {{cmd}} new <type> "short title"

  hotfix    production is broken: fix first, write it up after (no approval step)
  fix       behaviour is wrong: plan the fix, reproduce it with a failing test first
  chore     dependencies, config, CI: no behaviour change (no approval step)
  refactor  structure only: behaviour and existing tests stay the same
  spike     answer a question: only the findings are kept, never the code
  feature   new behaviour: a brief a teammate can read before any code exists
  roadmap   a system in several items: plan their order once, then open each with
            {{cmd}} new --from R-<id>.<n> (only the plan lands)

Changes under ~20 lines with no behaviour change need no item: commit them as `chore: ...`.
Open items on other branches: {{cmd}} status

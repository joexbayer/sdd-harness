---
type: research
status: active
review_by: 2027-04-29
trust: untrusted
sources:
  - https://mitchellh.com/writing/my-ai-adoption-journey (2026-02-05; retrieved 2026-10-29)
  - https://raw.githubusercontent.com/ghostty-org/ghostty/main/AGENTS.md (retrieved 2026-10-29)
  - https://newsletter.kentbeck.com/p/augmented-coding-beyond-the-vibes (2025-06-25; retrieved 2026-10-29)
  - https://newsletter.pragmaticengineer.com/p/tdd-ai-agents-and-coding-with-kent (retrieved 2026-10-29)
  - https://simonwillison.net/guides/agentic-engineering-patterns/red-green-tdd/ (retrieved 2026-10-29)
  - https://simonwillison.net/guides/agentic-engineering-patterns/first-run-the-tests/ (retrieved 2026-10-29)
  - https://code.claude.com/docs/en/best-practices (retrieved 2026-10-29)
  - https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/claude-prompting-best-practices (retrieved 2026-10-29)
  - https://cursor.com/blog/agent-best-practices (2026-01-09; retrieved 2026-10-29)
  - https://raw.githubusercontent.com/unclebob/ub-mode/master/SKILL.md (retrieved 2026-10-29)
  - https://github.com/cursor/plugins/tree/main/harness/pstack/claude-code/skills (tdd, principle-test-behavior-not-implementation; retrieved 2026-10-29)
  - https://docs.djangoproject.com/en/5.2/topics/testing/overview/ (retrieved 2026-10-29)
  - https://collectiveidea.com/blog/archives/2012/11/12/tests-oddly-slow-might-be-bcrypt (retrieved 2026-10-29)
  - https://docs.pytest.org/en/6.2.x/mark.html (retrieved 2026-10-29)
  - https://pypi.org/project/pytest-testmon/ (retrieved 2026-10-29)
  - https://flaviocopes.com/fast-tests-for-agents/ (2026-10-19; retrieved 2026-10-29)
  - https://visdom-maturity-matrix.virtuslab.com/guides/infrastructure/sub-2min-feedback-on-any-change (retrieved 2026-10-29)
  - https://arxiv.org/abs/2506.02954 (MutGen, TSE; v8 2026-04-15)
  - https://arxiv.org/abs/2410.21136 (LLM oracles: actual vs expected, 2024-10)
  - https://arxiv.org/abs/2607.12068 (Beyond Test Presence, 2026-07-13)
  - https://arxiv.org/abs/2607.18057 (Test coverage of agentic PRs, ICSME '26, 2026-07-20)
  - https://arxiv.org/abs/2510.09907 (Agentic property-based testing, NeurIPS 2025)
  - https://research.google/pubs/practical-mutation-testing-at-scale-a-view-from-google/ (2021)
  - https://github.com/boxed/mutmut (retrieved 2026-10-29)
  - https://stryker-mutator.io/docs/stryker-js/incremental/ (retrieved 2026-10-29)
  - https://docs.gitlab.com/development/database/query_recorder/ (retrieved 2026-10-29)
  - https://pytest-django.readthedocs.io/en/latest/helpers.html (retrieved 2026-10-29)
  - https://github.com/charkost/prosopite (retrieved 2026-10-29)
  - https://coderabbit.ai/blog/state-of-ai-vs-human-code-generation-report (2025-12-17; retrieved 2026-10-29)
---
# Tests written by and for coding agents

Complements [harness-engineering.md](harness-engineering.md) (verification ladder, protected
tests, EvilGenie, Meta ACH, "skip style" reviewers) and [pstack.md](pstack.md) (red test fails
for the intended reason → item 22). Not repeated here. [1st] = the author's own words or data;
[2nd] = someone summarising someone else.

## 1. Rules practitioners give agents about tests
- **Hashimoto** [1st, blog 2026-02-05]: "give the agent fast, high quality tools to
  automatically tell it when it is wrong", including scripts to "run filtered tests". "Each line
  in [AGENTS.md] is based on a bad agent behavior." Ghostty's AGENTS.md [1st]: "Prefer to run
  targeted tests with `-Dtest-filter` because the full test suite is slow to run."
  Tests as "the mechanism by which agents know they're done" is a podcast summary [2nd].
- **Kent Beck**, system prompt in "Augmented coding: beyond the vibes" [1st, 2025-06-25]:
  "Write just enough code to make the test pass - no more"; "Always run all the tests (except
  long-running tests) each time"; "Use the simplest solution that could possibly work";
  "Never mix structural and behavioral changes in the same commit". His stop signals: loops,
  "Functionality I hadn't asked for (even if it was a reasonable next step)", and "the genie
  was cheating, for example by disabling or deleting tests". He says on Pragmatic Engineer he
  struggles to stop agents deleting tests to make them pass [2nd, podcast summary].
- **Simon Willison** [1st]: "Use red/green TDD" is enough prompt for capable models; skipping the
  fail step risks "a test that passes already". Start every session with "First run the tests"
  (`uv run pytest`): the agent then keeps running them and learns the suite's size.
- **Anthropic** [1st]: Claude Code best practices: put "how to run a single test file" in
  CLAUDE.md; ask for evidence ("the command it ran and its output"). Prompting guide sample:
  "Implement a solution that works correctly for all valid inputs, not just the test cases. Do
  not hard-code values … Tests are there to verify correctness, not to define the solution …
  if any of the tests are incorrect, please inform me rather than working around them." For
  long runs: "It is unacceptable to remove or edit tests".
- **Cursor** (Lee Robinson, 2026-01-09) [1st]: "Be explicit that you're doing TDD so it avoids
  creating mock implementations for functionality that doesn't exist yet"; write tests from
  input/output pairs, confirm they fail, then implement "instructing it not to modify the tests".
- **ub-mode** SKILL.md [1st]: "See it fail for the reason you expect"; "If an honest test is
  impractical, do not write a bad one"; "The test calls the code the way its user does and
  checks the result that user would see"; **"If the test would still pass when every function
  returned nothing, throw it out."** Plus `crapper` (CRAP < 10 per function) and `mutator`
  ("Cover the uncovered. Kill the survivors. Delete dead code."). No rules on mocks or speed.
- **pstack** `tdd` + `principle-test-behavior-not-implementation` [1st]: "Prefer no new test
  over a bad test. A bad test is one that mostly tests mocks, encodes current implementation
  details, depends on timing or unrelated global state, needs expensive infrastructure for a
  small fix"; "Do not weaken existing assertions unless the expected behavior has genuinely
  changed". Two checks per test: break the behaviour (test must fail) and restructure the
  internals (test must still pass). Hollow-test causes it lists: assertions looser than the
  contract, **expected values computed by the code under test**, restated constants, asserting
  on data the test built itself. Mocks: asserting an external service got (or did not get) a
  call is behaviour; calls to internal helpers are not. Derive expected values from the
  requirement, never from running the code.

Consensus: test first, see it fail for the right reason, assert user-visible results from the
spec, mock only external boundaries, never edit or weaken tests to go green.

## 2. Fast vs slow tests (the 78 s PBKDF2 suite)
The cause is a known one: password KDFs are slow by design (OWASP's PBKDF2-HMAC-SHA256 figure
is 600,000 iterations [2nd, via mirrors]) and every test that creates a user pays it.
- **Lower the cost in test config, not in prod.** Django docs [1st]: "The default password
  hasher is rather slow by design … set PASSWORD_HASHERS to a faster hashing algorithm":
  `PASSWORD_HASHERS = ["django.contrib.auth.hashers.MD5PasswordHasher"]`. Rails/Devise:
  `config.stretches = Rails.env.test? ? 1 : 12`; or lower `BCrypt::Engine::DEFAULT_COST` in
  `test_helper.rb` (Collective Idea: a suite dropped from ~18 min [1st]). Generic form: the
  iteration count is a setting read from config/env, with tests setting it to 1. Keep one test
  that runs the real parameters.
- **Tiers.** pytest [1st]: register `slow` in `markers` ("deselect with '-m \"not slow\"'"),
  default `addopts = -m "not slow"`, full run in CI/nightly. Google sizes tests by resources
  (small/medium/large, roughly a 70/20/10 pyramid) [2nd].
- **Affected-only.** `pytest --testmon` records which tests touch which code in `.testmondata`
  and reruns only affected ones [1st]; `pytest --lf` reruns last failures; Ghostty's filter
  above. Beck runs all tests every time "except long-running tests" [1st].
- **Budgets.** VirtusLab targets "compiles and the relevant tests pass" within 120 s, and reports
  agents with fast feedback make smaller changes [2nd-ish practitioner guide]. flaviocopes
  (2026-10-19) [1st]: document "how to run one relevant file, how to check a larger area, and
  which checks are required before finishing"; "'Tests passed' is ambiguous when it means one
  file from a much larger suite"; measure cold vs warm runs.
- **What harnesses do:** none of the sources found has the harness itself time the suite. They
  push it into AGENTS.md (filtered command) and CI (full suite). Linear reportedly moved
  e2e-scale tests to nightly as agent output grew [2nd, drweb.de].

## 3. Catching hollow tests
- **Evidence that it matters.** LLM oracles "mainly capture the actual program behavior making
  bug detection difficult"; accuracy drops when the code under test is buggy (Konstantinou et
  al., 2024 [1st]). That is exactly a test written after (or from) the implementation.
  MutGen [1st]: suites with "100% coverage but only 4% mutation score"; mutation feedback in the
  prompt lifts LLM tests to ~89% mutation score on HumanEval-Java/LeetCode-Java [2nd, search
  summary of the paper]. AIDev studies [1st]: agents changed tests in only 49.6% of PRs that
  touch tested code; 64.8% of agent PRs had no changed line executed by any test; error
  handling was 81-86% untested (2607.18057). Agent tests have slightly weaker assertions
  (85.4% vs 88.1% "strong") but more edge cases, and more flakiness from file I/O and
  non-determinism (2607.12068).
- **Mutation testing, scoped to the diff.** Google mutates only changed lines during review
  and gets far fewer mutants [1st abstract]. StrykerJS: `npx stryker run --incremental` reuses
  results for unchanged code/tests [1st]. mutmut 3: `mutmut run "pkg.module.func*"` to scope,
  `mutate_only_covered_lines = true`, `mutmut export-cicd-stats`; no built-in score threshold
  and no diff mode [1st]. ub-mode runs a mutator on every change; Meta ACH (see
  harness-engineering.md) uses it to generate tests. Treat it as a spot check on the task's
  changed functions, not a whole-suite gate: cost is O(mutants × test time), which a 78 s
  suite makes prohibitive.
- **Property-based tests.** Agentic PBT on 100 Python packages (Opus 4.1 + Hypothesis): 56% of
  reports were valid bugs, 86% among the top 21, ~$5.56 per report [1st/2nd]. Good for parsers,
  serialisers, invariants; not a general hollow-test detector.
- **Reviewer model.** Claude Code's reviewer prompt checks "every requirement is implemented and
  the listed edge cases have tests" [1st]. An LLM judge of requirement coverage worked for
  Gherkin tests on one platform (arXiv 2512.01232, AAAI '26) [2nd]. Konstantinou also found
  LLMs are worse at *judging* oracles than writing them, so a reviewer is a filter, not proof.
- **Cheap static checks** (no study found, folk practice): test with zero asserts; assert on a
  value the test itself constructed; `assert x == f(x)`-style expected values; tests that
  catch all exceptions; skipped/xfail added in the same diff.
- **Spec example as the oracle.** Cursor (input/output pairs), pstack (derive expected values
  from the requirement) and Willison converge: the plan should give the concrete example and
  the test should assert it literally.

## 4. N+1 queries and similar performance smells
- CodeRabbit (470 PRs, Dec 2025) [1st, gated report]: AI-co-authored PRs had ~1.7× more issues,
  performance among the categories. The "8× excessive I/O" figure circulating could not be
  verified.
- **Query-count assertions** are the standard fix. GitLab [1st]: "As a rule, merge requests
  should not increase query counts"; take a control count, add records, assert
  `issue_same_number_of_queries_as(control)` (bidirectional, preferred over
  `exceed_query_limit`). pytest-django [1st]: `django_assert_num_queries(3)`,
  `django_assert_max_num_queries(2)`; Django `assertNumQueries`.
- **Detectors that fail tests:** Prosopite (`Prosopite.raise = true` in test env, `scan`/`finish`
  around each test; matches repeated SQL fingerprints from one call stack; README claims zero
  false positives) [1st]; Bullet (association-based, also flags unused eager loads); Rails
  `strict_loading` (raises on every lazy load, a stricter trade-off); `nplusone` for Django and
  SQLAlchemy [2nd]. No agent-specific practice found beyond "put it in the test suite".
  The pattern generalises: a smell becomes a test the agent can see fail (query count, call
  count, wall-clock budget on a hot path).

## 5. Keeping agent code small
- Anthropic's sample prompt [1st] ("Opus 4.5 and 4.6 have a tendency to overengineer"): "Only
  make changes that are directly requested or clearly necessary … Don't add error handling,
  fallbacks, or validation for scenarios that can't happen … Don't create helpers, utilities,
  or abstractions for one-time operations. Don't design for hypothetical future requirements."
- Beck: "just enough code to make the test pass"; unrequested features are a stop signal.
  ub-mode: "Ship the smallest edit that solves the problem"; "Take complexity out before you
  add anything." Willison: test-first guards against "code that is unnecessary and never gets
  used". Hashimoto: don't "draw the owl" in one session; small, clear tasks.
- Reviewers create bloat when unconstrained ("tests for cases that can't happen", Claude Code
  docs), already noted in harness-engineering.md.

## Implications for sdd (ranked by value / cost)
1. **Time the check and warn when slow** (cheap, high). `sdd check` records duration; above a
   budget (say 30 s, configurable) print the slowest tests (`pytest --durations=10`) and the
   usual causes: password-KDF cost, sleeps, network, per-test DB rebuilds. Would have caught the
   78 s suite on the first batch.
2. **Plan prompt: "tests must be fast" as a rule with the fix named** (cheap, high). Slow-by-
   design parameters (KDF iterations, bcrypt cost, retries/backoff) come from config; tests set
   them minimal; one test covers real parameters. Planner writes this into the item when the app
   has auth.
3. **Each task's test asserts the spec example** (cheap, high). Planner gives every task a
   concrete input → expected output from the requirement; builder prompt quotes ub-mode's
   "would still pass if every function returned nothing" and pstack's "expected values never
   computed by the code under test". Matters most for the small builder model, which per
   Konstantinou mirrors the implementation.
4. **Two tiers: task check vs ship check** (medium). Optional `check_fast` (e.g. `-m "not slow"`
   or the task's test files) after each task; full `check` before Built and ship, as Beck and
   Ghostty do. Keep the full run authoritative so zero-test and masking guards
   (narrow-lessons.md) still apply.
5. **Reviewer/verifier prompt judges tests against FRs** (cheap, medium): each FR has a test
   that would fail if the FR were dropped; skip style. Advisory, since LLMs judge oracles worse
   than they write them.
6. **Static hollow-test warnings in `sdd review`** (medium cost, medium): new tests with no
   assertion, skip/xfail added in the diff, existing assertions removed or loosened.
7. **Plan prompt: query-count test for list endpoints** (cheap, medium for web apps):
   `django_assert_max_num_queries` / Prosopite-style, using GitLab's control-count pattern.
8. **Builder prompt: Anthropic's over-engineering snippet + "just enough code"** (cheap, medium).
9. **Mutation spot check on changed functions at review** (higher cost, uncertain value):
   `mutmut run "<changed funcs>*"` / `stryker --incremental`, advisory only, and only once the
   suite is fast. Not a gate.

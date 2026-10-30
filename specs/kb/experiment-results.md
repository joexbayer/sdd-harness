---
type: research
status: active
review_by: 2027-04-30
sources:
  - ~/experiments/A-20261030-092234, B-20261030-101149, C-20261030-095144 (results.md, driver.log, repo/; read 2026-10-30)
  - ~/experiments/A-20261029-211940 (pilot 2, arm A)
trust: first-hand
---
# The "plan big, build small" experiment: results of 2026-10-30

One run per arm of experiment/run.sh, after items 39 (tasks sized for the builder) and 40
(progress-aware stops). Same brief, Opus planner and scripted Sonnet human in every arm. One run
per arm is a pilot, but 0 against 45 of 45 is not noise.

| | A: qwen builds | C: qwen builds, Opus writes some tests | B: Opus builds |
|---|---|---|---|
| hidden acceptance tests | 0 / 45 | 0 / 45 | 45 / 45 |
| tasks ticked | 6 of 32 | 3 of 36 | 16 of 16 |
| cost (sdd usage) | $2.48 | $1.97 | $9.32 |
| wall-clock | 18m | 17m | 47m |
| stopped | 2 failed builder runs | 2 failed builder runs | no, shipped |

## What a human review found

- **A: green but wrong.** The shape check ignores the plan's field kinds and accepts a null
  title, a list for a string and a string for a list. A comment calls it "a heuristic based on
  the test case", and the test "None is not treated as a string" asserts that None is accepted.
  All 46 unit tests passed. The password check uses `==`, where the plan says
  `hmac.compare_digest`. Then qwen added `requests` against "standard library only", the tests
  could not load, and the arm stopped. Six stray scripts (debug_test.py, final_test.py and
  others) were committed at the root.
- **C: honest but stuck.** The first three tasks follow the plan: the schema test pins every
  column, and the password check uses `compare_digest`. On T-1.4 qwen wrote a WSGI function where
  the plan says `ThreadingHTTPServer` ("handler() takes 2 positional arguments but 3 were
  given"). One sentence from a person would likely have unblocked it. The planner marked only 4
  of 36 tasks `by: planner`, so C hardly tested its own idea.
- **B: shippable.** No stray files, standard library only, `compare_digest`, parameterised SQL,
  and a shape check that rejects what its plan rejects. 945 lines of code, 2,289 of tests. The
  permission rules refused 24 calls (`;` chains, `sed -i`, heredocs), which cost time only.

## What it means

- Opus as builder is the default. It costs about four times as much and still ships a feature
  for under $10.
- qwen as builder is supported, with more human review. Measure an arm by the quality of the
  result and how much supervision it needed, not by whether it ran unattended.
- The cost of supervision depends on who writes the tests. When qwen writes its own tests, they
  can agree with wrong code and the gates cannot see it (arm A). Tests that a stronger model
  writes first are the lever (arm C), but only if the planner writes most of them.
- Task size helped a little (pilot 2's arm A ticked 4 of 20, this one 6 of 32) without fixing
  the failure.
- The driver commits whatever a builder leaves behind. A human would not, so stray files are a
  sign that nobody reviewed.

Not worth more driver work: these stops are where a person would step in.

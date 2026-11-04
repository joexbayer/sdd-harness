Hunk: before presenting the review, write one note per requirement's main change to
`/tmp/hunk-{{id}}.json`:
  {"version":1,"files":[{"path":"<file>","annotations":[{"newRange":[<start>,<end>],
  "summary":"FR-{{id}}.1: <what it does>","rationale":"proven by <test>"}]}]}
Then offer the human: `hunk diff {{base}} HEAD --agent-context /tmp/hunk-{{id}}.json --agent-notes`.

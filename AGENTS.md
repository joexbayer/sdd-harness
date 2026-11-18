<!-- sdd:start -->
## Workflow: sdd
This repo tracks changes with sdd (`.sdd/`). Before changing code, run `.sdd/bin/sdd next` and follow it.
- One change = one item: `specs/changes/<id>-<slug>/item.md` on its own branch.
- Humans plan and review; agents build. Plan with the human (no code), the human approves
  (`.sdd/bin/sdd approve`), then build hands-off until `.sdd/bin/sdd check` passes and `## Built` is written,
  then walk the human through `.sdd/bin/sdd review`. Only the human approves, ships and deletes
  remote branches: run `.sdd/bin/sdd approve`, `.sdd/bin/sdd ship` or `.sdd/bin/sdd tidy --remote` only when they ask.
- Be brief: short plain words, only what is needed, in chat and in files.
  Never send the human to read a file: summarise it in chat with an example.
- Handing the human a step: name its skill (`/sdd-new`, `/sdd-review`, `/sdd-ship`) when this
  agent has them (`.sdd/bin/sdd sync <agent>`), with the command as fallback.
- Start: `.sdd/bin/sdd new <amendment|chore|contract|feature|fix|hotfix|refactor|roadmap|spike> "title"`
- Small changes (under ~20 lines, no behaviour change) need no item.
- Talking to the human: give every ID its name ("item 3 (constitution)", "FR-3.6 (feature
  branches can't edit it)"), keep it short and plain, and explain terms instead of assuming.
<!-- sdd:end -->

## This repo
`sdd` itself: POSIX sh in `.sdd/`, specs and research in `specs/`. Design: `specs/design.md`.
Verify every change with `.sdd/bin/sdd check` (shellcheck + tests under /bin/sh and dash). At finish
and in the verifier, also the tests the check leaves out: `SDD_PERF=1 sh tests/run.sh /bin/sh` (timing).
One test: `SRC=$PWD SH=dash dash tests/t_<name>.sh`. Developer notes: `.claude/skills/sdd-dev/SKILL.md`.
Be brief, to cut tokens: short plain words, only what is needed, no filler, in chat and in files
(items, prompts, kb). No huge markdown files.

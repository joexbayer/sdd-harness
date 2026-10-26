<!-- sdd:start -->
## Workflow: sdd
This repo tracks changes with sdd (`.sdd/`). Before changing code, run `.sdd/bin/sdd next` and follow it.
- One change = one item: `specs/changes/<id>-<slug>/item.md` on its own branch.
- Humans plan and review; agents build. Plan with the human (no code), the human approves
  (`.sdd/bin/sdd approve`), then build hands-off until `.sdd/bin/sdd check` passes and `## Built` is written,
  then walk the human through `.sdd/bin/sdd review`. Only the human approves and ships: run
  `.sdd/bin/sdd approve` or `.sdd/bin/sdd ship` only when they ask you to.
- Start: `.sdd/bin/sdd new <amendment|chore|feature|fix|hotfix|refactor|spike> "title"`
- Small changes (under ~20 lines, no behaviour change) need no item.
- Talking to the human: give every ID its name ("item 3 (constitution)", "FR-3.6 (feature
  branches can't edit it)"), keep it short and plain, and explain terms instead of assuming.
<!-- sdd:end -->

## This repo
`sdd` itself: POSIX sh in `.sdd/`, specs and research in `specs/`. Design: `specs/design.md`.
Verify every change with `.sdd/bin/sdd check` (shellcheck + tests under /bin/sh and dash).
Developer notes: `.claude/skills/sdd-dev/SKILL.md`.

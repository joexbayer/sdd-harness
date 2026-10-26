<!-- sdd:start -->
## Workflow: sdd
This repo tracks changes with sdd (`.sdd/`). Before changing code, run `.sdd/bin/sdd next` and follow it.
- One change = one item: `specs/changes/<id>-<slug>/item.md` on its own branch.
- Start: `.sdd/bin/sdd new <chore|feature|fix|hotfix|refactor|spike> "title"`
- Check: `.sdd/bin/sdd check` (must pass before shipping; exit 3 means no tests ran)
- Ship: `.sdd/bin/sdd ship` (ask the human first)
- Small changes (under ~20 lines, no behaviour change) need no item.
<!-- sdd:end -->

## This repo
`sdd` itself: POSIX sh in `.sdd/`, specs and research in `specs/`. Design: `specs/design.md`.
Verify every change with `.sdd/bin/sdd check` (shellcheck + tests under /bin/sh and dash).
Developer notes: `.claude/skills/sdd-dev/SKILL.md`.

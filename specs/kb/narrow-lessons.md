---
type: research
status: active
review_by: 2027-04-26
sources:
  - ~/narrow (lisp/guards.lisp, lisp/compile.lisp, lisp/commands.lisp, ROADMAP.md, docs/loop/backlog.md; read 2026-10-26)
trust: untrusted
---
# Ideas taken from narrow (our Emacs-shaped agent harness)

- **The finish gate decides from recorded facts, never from the model's prose**
  (`lisp/guards.lisp:142-361`).
  - States: unverified, partial, failing, passed.
  - Unverified is refused once, then accepted with "unverified:" in the report.
  - In sdd: a working-tree fingerprint plus the last passing check, enforced through the stop
    hook.
- **Checks that cannot fail** (`lisp/compile.lisp:221-266`).
  - Zero tests ran counts as no pass.
  - `|| true` is refused.
  - A single-test pass doesn't verify the whole change.
  - In sdd: `check` exits 3 on zero tests and refuses masked commands.
- **Distinct exit codes** separate "ran but unverified" from "crashed"
  (`guards.lisp:452-464`). sdd uses 0, 1, 2 and 3.
- **The executor may only tick the plan, never rewrite it** (backlog L14). In an eval, a model
  rewrote tasks.md to match its own wrong code. For sdd step 2, task boxes are ticked by the CLI
  only.
- **Capture must be a fixed step.** Agents used `define_command` in 4 of 1,703 runs; they don't
  volunteer procedures.
- **State is rendered fresh from files every turn**, ordered by how often it changes.
  The sdd equivalent is the session-start hook printing `status`.
- **Layered config:** built-in, then user, then project, with security policy sealed from the
  agent. In sdd: core, then user, then project config, plus `local/` overrides.
- **Verdict:** the value is in the gates and state files, not in owning the loop. A thin layer
  over existing agents wins unless constant-size context or shell-AST permission policies are
  required.

## Co-evaluation with narrow + qwen3-coder-30b (2026-10-26)
narrow ran qwen headless on small greenfield apps through sdd; narrow's Claude session acted
as the human (plan, approve, review, ship). k=1 per app, so these are signals, not numbers.
- **Prose rules were ignored, gates held.** qwen never ran `sdd next` unprompted. It wrote code
  in plan phase, skipped `## Built`, never committed, and rarely named FRs, until a gate or
  a human review note forced it. Planning only held once narrow refused writes outside
  `specs/` during planning. Lesson: anything that must hold is a gate (design §1). Prose is
  for capable agents and humans.
- **Plan big, build small.** Opus in the plan phase ran `sdd next` first, unprompted, and
  produced a brief that was approved as written in one round. qwen needed a gate, two rounds
  and a hand fix. The describe phase is where a strong model (or the human) pays off.
- **Integration shape that worked:** narrow's finish gate calls `sdd hook stop </dev/null`
  (exit 2 means refuse, with the reason), and its compile step runs `sdd check`. The core
  decides, the adapter translates.
- **Bugs the runs found in sdd** (fixed): init chose a `pytest` that wasn't on PATH; exit 127
  looked like a test failure; a check that writes files contradicted itself; review missed FR
  names in untracked tests, which misled the human; human review notes under `## Built`
  satisfied the agent's Built gate (now a separate `## Review (optional)` section); `## `
  headings qwen wrote inside Built split it into unknown sections (now part of Built).
- **Machine verdicts were honest; prose was not.** qwen's summaries and Built claimed code that
  never existed. Trust `sdd review` and the check record, not the agent's write-up.

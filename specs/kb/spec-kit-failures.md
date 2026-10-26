---
type: research
status: active
review_by: 2027-04-26
sources:
  - ~/work/private-project (audit of .specify/, .claude/, specs/, bin/, git log; 2026-10-26)
  - https://github.com/github/spec-kit/issues/4128 (retrieved 2026-10-26)
  - https://github.com/github/spec-kit/issues/4270 (retrieved 2026-10-26)
  - https://github.com/github/spec-kit/issues/4065 (retrieved 2026-10-26)
  - https://github.com/github/spec-kit/issues/3849 (retrieved 2026-10-26)
  - https://github.com/github/spec-kit/issues/5058 (retrieved 2026-10-26)
  - https://github.com/github/spec-kit/issues/4884 (retrieved 2026-10-26)
  - https://github.com/github/spec-kit/issues/4940 (retrieved 2026-10-26)
  - https://github.com/github/spec-kit/issues/1476 (retrieved 2026-10-26)
  - https://wavect.io/blog/github-spec-kit-production-guide.md (retrieved 2026-10-26)
trust: untrusted
---
# Why Spec Kit did not work for us, especially as a team

Two sources: an audit of our own private-project repo (about 90 specs, Sep–Oct 2026), and
upstream spec-kit issues. Each failure is listed with the rule we adopted in its place
([[design]]).

## Observed in private-project
- **Stale pointer.** The gitignored `.specify/feature.json` pointed at an unmerged, superseded
  spec (063). Three worktrees pointed at the wrong spec, so work landed in the wrong directory.
- **Volume.** About 25k tokens of markdown per feature. Median sizes for specs 094–108, in lines:
  spec 308, tasks 243, preview 209, research 190. In total 168k lines under `specs/`. One decision
  (mail in spec 108) was restated in 8 places.
- **Rubber stamps.**
  - 127 of 135 approvals were self-approvals.
  - Checklists had 1,140 of 1,141 boxes ticked. One checklist recorded a decision that was later
    reversed.
  - Plan templates still carried stock Python/iOS placeholders.
- **IDs not traceable.** FR numbering restarts at 001 in every spec, so 2,708 `FR-` references in
  code are ambiguous. Tasks link to stories, not requirements.
- **tasks.md is not the record.** 62 of 89 spec dirs have open boxes (426 in total).
- **Optional gates get skipped.** Every extension hook is `optional: true`. Only 9 of 89 specs
  have retrospectives, and verify is the step most often dropped.
- **Constitution enforced by prose.** 748 lines (59 KB) are loaded by 11 skills, and 52 rules
  are review-only. 11 promotions have been stuck at "pending article" since September.
- **Skill sprawl.**
  - 185 skills, with about 22k tokens of descriptions. 44 were never used, and one has no
    frontmatter, so it can never trigger.
  - The skills that are used are short and runnable (console-dev-boot, read-a-prod-day).
- **Routing on paper.** 166 `@haiku` tags led to 7 Haiku calls. `[ctx:]` markers appeared on 7%
  of dispatches.
- **Copies drift.** Extension commands and `.claude/skills` copies differ by 8–38 lines, and
  upgrades overwrite customisations.
- **Branch debris.** 18 unmerged spec branches, 7 of them "Approved" with 0 tasks done, and 19
  gaps in the numbering.
- **Worth keeping:**
  - script gates (`bin/spec`, `bin/land`);
  - adversarial verify with refuters (spec 108's 4 MAJOR findings were real);
  - prior art checked at `file:line`;
  - preview sketches and diagrams;
  - rule states `[ci]` / `[review]` / `[parked]`;
  - follow-ups with owner and trigger;
  - path-scoped rules;
  - as-built "decisions a reader would re-open".
- **Lesson.** Only failures that became `bin/ci` checks stopped recurring.

## Upstream (spec-kit issues)
| issue | failure | root cause | our rule |
|---|---|---|---|
| #4128 | the shared `feature.json` is a race between agents | identity stored as mutable state | derive the item from the branch name |
| #1476 | worktrees left to an extension | branch-per-feature assumed | worktree-safe core |
| #4270 (open since Aug) | scan-and-increment numbering collides | no allocator | atomic counter (solo), remote ref claim (team) |
| #4065 | inserting or deleting renumbers IDs and breaks references | dense sequential IDs | permanent IDs with gaps, item-scoped (`FR-57.2`) |
| #3849, #5058 | upgrade `--force` drops customisations | generated output and user edits in the same files | `core/` vs `local/` layers; refuse when core is edited |
| #4563, #4888 | per-agent integrations rewrite config and drift | committed per-agent copies | per-developer glue, kept out of git |
| #4884 | bash, PowerShell and Python triplicated | multiple implementations | one implementation (POSIX sh) |
| #4940 (declined), #4943 | no flow-back when code runs ahead of the spec | no lifecycle | archive at ship; living specs later |
| #916 | no brownfield story | greenfield templates | fix/refactor types describe current, expected and unchanged behaviour |

Wavect (production guide): ceremony pays off only on consequential, multi-person or regulated
work, so scale it to the change. Maintainer responses mostly add surface (extensions, presets,
bundles) without fixing the root causes above.

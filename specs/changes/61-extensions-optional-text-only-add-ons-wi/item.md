---
id: 61
type: feature
title: Extensions: optional text-only add-ons, with Hunk and Plannotator
status: open
created: 2026-11-04
---
# 61 Extensions: optional text-only add-ons, with Hunk and Plannotator

## Why
The user wants optional tools like Hunk (terminal diff with notes beside the code) and Plannotator
(comment on plans and diffs in a local UI) as add-ons, "like spec kit extension" (2026-11-04). Spec Kit's
have a manifest, scripts and hooks that can auto-run; sdd takes the folder, manifest and stages, text only.

## What changes
FR-61.1 WHEN the human runs `sdd extension add <name> [--me]` THE SYSTEM SHALL add `extension = <name>` under
`[sdd]` in `.sdd/config` (team), or the user config with `--me`, and say what to do next; `remove` undoes
it; an unknown name is refused; nothing is committed.
  e.g. `sdd extension add hunk --me` → `~/.config/sdd/config` has it; `add nope` → `sdd: unknown extension: nope (see: sdd extension list)`, exit 1
FR-61.2 WHEN the human runs `sdd extension list` THE SYSTEM SHALL print each available extension, on for the
team, on for you, or off, its description, and `needs <tool>, not installed` when so.
  e.g. `hunk  on (you)  See each requirement beside its code in the terminal`
FR-61.3 WHEN an extension is on (team and user configs add up) and has `<step>.md` for plan, build or review
THE SYSTEM SHALL print that text after the step's own, in `sdd next`, and for review also in `sdd review`.
  e.g. hunk on, review phase → `sdd next` and `sdd review` include the Hunk lines; plan phase does not
FR-61.4 WHEN an extension's `needs` tool is not on PATH THE SYSTEM SHALL skip its text, and `add` SHALL warn
with the tool's url.
  e.g. no `hunk` on PATH → no Hunk lines; `sdd: warning: hunk is not installed: https://www.hunk.dev`
FR-61.5 WHEN no extension is on THE SYSTEM SHALL print exactly what it prints today.
  e.g. the prompt word ceilings in `tests/t_prompts_tests.sh` still hold
FR-61.6 WHEN a folder exists at `.sdd/local/extensions/<name>/` THE SYSTEM SHALL treat it as an extension too,
over a bundled one of that name, and SHALL only read its `extension` and `plan|build|review.md` files:
nothing in an extension folder is ever run.
  e.g. `.sdd/local/extensions/mine/{extension,review.md}` → listed; a `run.sh` in it is ignored
FR-61.7 WHEN sdd is installed THE SYSTEM SHALL bundle `hunk` and `plannotator`, off by default.
  e.g. `sdd extension list` shows both as off

## Not in scope (optional)
- Installing from a git URL; add it when a real third-party extension appears (the user's choice).
- Installing the tools themselves; scripts or hooks in extensions; new gates (`sdd approve` and `sdd ship`
  stay the only gates).

## How
```
.sdd/core/extensions/hunk/extension     [extension] description, url, needs (git-config format)
                          review.md     text added to the review step
.sdd/core/extensions/plannotator/       extension, plan.md, review.md
.sdd/local/extensions/<name>/           yours; same shape; wins over a bundled one

sdd next ──▶ prompt <step> ──▶ core text ▶ local append ▶ each on + installed extension's <step>.md
sdd review ─────────────────────────────────────────────▶ each on + installed extension's review.md
```
- `.sdd/core/lib/common.sh`: `extensions_on` (`cfg_every sdd.extension`, deduped); `ext_dir <name>` (via
  `sdd_path`); `ext_prompt <step> <id> <title> <type>` renders the text; `needs` uses `command -v`
  (no fork, so `next` keeps its git-call budget). Called in `prompt()` for exactly plan, build,
  review, and at the end of `review.sh`.
- `.sdd/core/cmd/extension.sh`: add, remove, list; `help.sh` gets one line; README a short section.
- Hunk text: write notes to `/tmp/hunk-{{id}}.json` as `{"version":1,"files":[{"path":…,"annotations":[
  {"newRange":[a,b],"summary":"FR-{{id}}.1: …","rationale":"proven by …"}]}]}`, one per requirement's
  main change; tell the human to run `hunk diff {{base}} HEAD --agent-context /tmp/hunk-{{id}}.json --agent-notes`.
- Plannotator text: plan: after the chat summary, offer `/plannotator-annotate <item file>` and apply the
  comments; review: offer `/plannotator-review` and write feedback under "## Review". Approval and ship
  stay the human's yes.
Fixed names: config key `sdd.extension`; manifest keys `extension.description|url|needs`; steps plan, build,
review; functions above.

D-61.1 Text only, unlike Spec Kit's scripts and auto-run hooks: nothing to execute, nothing to trust beyond
reading it. D-61.2 A small command, not a config line alone (the user's choice). D-61.3 Bundled plus local only
(the user's choice). D-61.4 Team and user lists add up, so one developer can use a tool without forcing it on
others; a missing tool is skipped, so a team-wide one doesn't bother those without it.
D-61.5 Neither tool is installed on this machine and their docs were read 2026-11-04: `hunk diff <from> <to>`
is documented, the two-dot range and the text are to be tried by hand at review.

## Security
An extension's text reaches agents' prompts, so a bad local one can steer an agent → local extensions
are committed files the human reviews like any prompt override; bundled ones ship with sdd; none is ever
run (FR-61.6). `add` validates the name (lowercase word) before it reaches a path or git config. No new
dependency in the core.

## Questions (optional)
<!-- Q-61.1 <question> → recommend: <answer>. Resolve before building. -->

## Done when
`tests/t_extension.sh` passes under sh and dash, and `sdd check` passes. Tried by hand at review, with the
tools installed: one Hunk review and one Plannotator annotate.

## Tasks (optional)
- [ ] T-61.1 Extension text in the steps, FR-61.3, FR-61.4, FR-61.5, FR-61.6 (files: .sdd/core/lib/common.sh, .sdd/core/cmd/next.sh, .sdd/core/cmd/review.sh, tests/t_extension.sh; test: SRC=$PWD SH=dash dash tests/t_extension.sh; size: M)
- [ ] T-61.2 `sdd extension add|remove|list`, FR-61.1, FR-61.2 (files: .sdd/core/cmd/extension.sh, .sdd/core/cmd/help.sh, tests/t_extension.sh; test: SRC=$PWD SH=dash dash tests/t_extension.sh; size: S)
- [ ] T-61.3 Bundled hunk and plannotator, README, FR-61.7 (files: .sdd/core/extensions/hunk/extension, .sdd/core/extensions/hunk/review.md, .sdd/core/extensions/plannotator/extension, .sdd/core/extensions/plannotator/plan.md, .sdd/core/extensions/plannotator/review.md, README.md, tests/t_extension.sh; test: SRC=$PWD SH=dash dash tests/t_extension.sh; size: S)

## Built
<!-- Written by the agent at the end of the build, for the review: per requirement what
changed (file:line) and which test proves it; deviations from the plan and why; follow-ups. -->

## Review (optional)
<!-- The human's review notes: what to change, one per line. The agent works through them
and says under "## Built" what it changed for each. -->

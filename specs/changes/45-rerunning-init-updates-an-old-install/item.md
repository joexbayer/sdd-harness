---
id: 45
type: fix
title: Rerunning init updates an old install
status: open
created: 2026-10-31
approved: 6d414cc74b4653d40cacc33f755d77ffe168ec99 2026-10-31 joexbayer
---
# 45 Rerunning init updates an old install

## Current behaviour
An adopted repo cannot pick up sdd fixes. `sdd init` on an existing install prints
`sdd already installed in .sdd/ (0.1.0); left as is` (`.sdd/core/cmd/init.sh:8-9`), and there is
no other way in. narrow (the pilot) still runs sdd from before items 43 and 44. The only
route is a hand-copied `rm -rf .sdd/bin .sdd/core && cp -R …`, which on 2026-10-31 ran in the
wrong folder and deleted this repo's own `.sdd/bin` and `.sdd/core` (restored from git).
`specs/design.md` §14 already plans an upgrade that "replaces `core/` only, and refuses if
`core/` was hand-edited".

## Expected behaviour
FR-45.1 WHEN `sdd init` runs from another sdd copy and the repo's `.sdd/bin` or `.sdd/core` differ
from that copy's THE SYSTEM SHALL replace `.sdd/bin`, `.sdd/core` and `.sdd/VERSION` with that
copy's (files only the old install had are gone) and print
`updated sdd in .sdd/ from <source .sdd folder>: commit .sdd/bin and .sdd/core (and run sdd sync <agent> again if you use it)`
  e.g. a committed install with an edited `core/cmd/help.sh` and an extra `core/old.sh` →
  `help.sh` matches the source again, `old.sh` is gone, that line is printed
FR-45.2 WHEN they already match THE SYSTEM SHALL change nothing and print
`sdd already installed in .sdd/ and up to date`.
  e.g. init run twice in a row → the second run prints that line, not "updated"
FR-45.3 WHEN they differ and `.sdd/bin` or `.sdd/core` have uncommitted changes (edits or new
files) THE SYSTEM SHALL refuse with exit 1, change nothing, and print
`sdd: .sdd/bin or .sdd/core has uncommitted changes: commit or discard them first (overrides belong in .sdd/local/)`
  e.g. an uncommitted edit in `.sdd/core/cmd/help.sh` → exit 1, the edit is still there
FR-45.4 WHEN a user reads the README's Customise section THE SYSTEM SHALL tell them how to
upgrade: run the newer sdd's init in the repo; config and `.sdd/local/` are kept.
  e.g. an "Upgrades." bullet with `<newer sdd>/.sdd/bin/sdd init`

How (`.sdd/core/cmd/init.sh:7-15`): keep the existing skip when the running sdd is the repo's own
install (`$target` is `$SDD_HOME`). When `$target/core` exists: if `diff -r` finds `bin` and
`core` equal to `$SDD_HOME`'s → FR-45.2 line. Else if
`git status --porcelain -- "$DIRNAME/bin" "$DIRNAME/core"` prints anything → `die` with
the FR-45.3 line. Else `rm -rf` the two folders, `cp -R` the three from `$SDD_HOME` (die "copy
failed" as today) → FR-45.1 line. Fix the header comment ("never overwrites config or core").
README: one "Upgrades." bullet under Customise. `specs/design.md` §14: the upgrade bullet says
it is rerunning `init` (checksums stay with step 5's supply-chain work).

D-45.1 Through `init`, not a new `upgrade` verb: rerunning init is what a user tries first, and
no new command is needed (user preference: adapt through existing commands).
D-45.2 "Hand-edited" means uncommitted changes, checked with git, not checksums: committed
edits that the update overwrites show up in `git diff` before the user commits it, so nothing
is lost; uncommitted ones would be, so init refuses. Real edits belong in `.sdd/local/`.
D-45.3 The comparison runs before the dirty check, so a fresh uncommitted install rerun from the
same sdd stays "up to date" instead of refusing.
D-45.4 `diff -r` without `-q` (POSIX, C-1), output discarded.
D-45.5 VERSION stays 0.1.0 for now; the message names the source folder instead.

## Must not change
- First install, config, AGENTS.md handling and the FR-43/FR-44 warnings work as today.
- Running the repo's own `.sdd/bin/sdd init` (this repo) never touches `bin/` or `core/`.
- `.sdd/config` and `.sdd/local/` are never touched by an update.
- init still creates no commits (C-4).

## Security
init now deletes and replaces `.sdd/bin` and `.sdd/core` → it only does so from a sdd copy the
human runs by path, refuses on uncommitted changes there (FR-45.3), and the result is an
uncommitted diff the human reviews before committing (design: "upgrade only through a reviewed
commit"). No new dependency.

## Test
`tests/t_init.sh`, a new section on the go repo after its install is committed:
- edit `.sdd/core/cmd/help.sh` and add `.sdd/core/old.sh`, commit; rerun init → output has the
  FR-45.1 line, `diff -r .sdd/core "$SRC/.sdd/core"` is clean, `old.sh` is gone, `.sdd/config` is
  unchanged (FR-45.1).
- rerun init → `and up to date`, no `updated sdd` (FR-45.2).
- commit an edit, then add an uncommitted edit to `help.sh`; rerun → exit 1, the FR-45.3 line,
  the edit still there (FR-45.3).
Fails now: init prints "left as is" and changes nothing.

## Built
- FR-45.1: `.sdd/core/cmd/init.sh:17-20`, the update branch: `rm -rf` the two folders (guarded
  with `${target:?}`, which shellcheck SC2115 asked for), copy from `$SDD_HOME`, print the line.
  Proven by `tests/t_init.sh:79-91` (stale edit and extra file gone, core equals the source,
  config unchanged).
- FR-45.2: `.sdd/core/cmd/init.sh:13-14`, `diff -r` on bin and core first. Proven by
  `tests/t_init.sh:93-96` ("and up to date", no "updated sdd").
- FR-45.3: `.sdd/core/cmd/init.sh:15-16`, `git status --porcelain` on the two folders, then
  `die`. Proven by `tests/t_init.sh:98-104` (exit 1, the line, the uncommitted edit kept).
- FR-45.4: `README.md:245` "Upgrades." bullet; `specs/design.md` §14 upgrade bullet now says
  rerun `init` (no test, docs).
- The header comment at `.sdd/core/cmd/init.sh:2-3` no longer says "never overwrites core".
- Check: `sdd check` passed (132 s).
- Security pass (fresh Sonnet reviewer, given only the diff): no findings. I checked the part it
  skipped: `ROOT` is the git top level (`need_repo` dies outside one) and `DIRNAME` the running
  sdd's folder name, so the delete only reaches `<repo>/.sdd/bin` and `<repo>/.sdd/core`.
Verified by: claude-sonnet-5-5: 4 of 4 FRs proven; no findings

## Review (optional)
<!-- The human's review notes: what to change, one per line. The agent works through them
and says under "## Built" what it changed for each. -->

---
id: 59
type: feature
title: One-line installer: curl | sh puts sdd on your PATH
status: open
created: 2026-11-02
approved: 59b708d0cfa650097cbe390ea7c8540e0c19eeb2 2026-11-02 joexbayer
---
# 59 One-line installer: curl | sh puts sdd on your PATH

## Why
Installing means cloning sdd and running `~/sdd-harness/.sdd/bin/sdd init`; the user wants it
like Spec Kit's `specify`: install a command once, then `sdd init` (2026-11-02).

## What changes
FR-59.1 WHEN `install.sh` runs (e.g. `curl -fsSL …/main/install.sh | sh`) THE SYSTEM SHALL download the
release tarball (default: the version in the script; `sh -s -- v0.2.0` picks another) with curl, or
wget if curl is missing, keep only its `.sdd/` in `${XDG_DATA_HOME:-~/.local/share}/sdd/<version>/`,
link `${SDD_BIN:-~/.local/bin}/sdd` to it, and print the next steps.
  e.g. → `installed sdd v0.1.0 in ~/.local/share/sdd/v0.1.0` and `next: cd your-repo && sdd init && sdd sync claude`
FR-59.2 WHEN the bin folder is not on PATH THE SYSTEM SHALL say how to add it.
  e.g. → `add ~/.local/bin to your PATH: export PATH="$HOME/.local/bin:$PATH"`
FR-59.3 WHEN it runs again, for the same or another version THE SYSTEM SHALL replace that version's
folder and repoint the link; other versions' folders stay.
  e.g. v0.1.0 then v0.2.0 → the link points at v0.2.0
FR-59.4 WHEN the download fails, or neither curl nor wget exists THE SYSTEM SHALL exit 1 with the
reason and leave the link and any installed version untouched.
  e.g. a missing tag → `sdd install: could not download v9.9.9 from <url>` and exit 1
FR-59.5 WHEN a user reads README and MIGRATE THE SYSTEM SHALL show the two-line install, the upgrade
(rerun install, then `sdd init` per repo) and uninstall (remove the link and the folder).
  e.g. README Quick start starts with the curl line

## Not in scope (optional)
- npm (`npx`), Homebrew, Windows. Checksums: the tarball comes from a fixed tag over HTTPS.

## How
`install.sh` at the repo root (POSIX sh, outside the core: C-1 is about `.sdd/`). Tarball:
`${SDD_INSTALL_URL:-https://github.com/joexbayer/sdd-harness/archive/refs/tags}/<version>.tar.gz`
(the override is for tests: a `file://` URL). Extract into a temp dir, move `*/.sdd` into place,
then swap the link (`ln -sfn`). The launcher already follows symlinks and hands off to a repo's own
`.sdd/` (`.sdd/bin/sdd:22-28`), so a global `sdd` runs each repo's pinned copy.
D-59.1 A symlink to a versioned folder, not a copy in bin: upgrades are one repoint, and `sdd init`
copies from the real folder.
D-59.2 The default version is written in the script and bumped at each release (the release
checklist in README says so): no network call to find "latest".

## Security
`curl | sh` runs our script → it is short and readable, fetches a fixed tag over HTTPS, writes only
under the data and bin folders, and never uses sudo. No new dependency (curl/wget and tar).

## Questions (optional)
<!-- Q-59.1 <question> → recommend: <answer>. Resolve before building. -->

## Done when
`tests/t_install.sh` passes under sh and dash; `sdd check` passes.

## Tasks (optional)
- [ ] T-59.1 install.sh, FR-59.1, FR-59.2, FR-59.3, FR-59.4 (files: install.sh, tests/t_install.sh; test: SRC=$PWD SH=dash dash tests/t_install.sh; size: M)
- [ ] T-59.2 README and MIGRATE install, upgrade, uninstall, FR-59.5 (files: README.md, MIGRATE.md; size: S)

## Built
<!-- Written by the agent at the end of the build, for the review: per requirement what
changed (file:line) and which test proves it; deviations from the plan and why; follow-ups. -->

## Review (optional)
<!-- The human's review notes: what to change, one per line. The agent works through them
and says under "## Built" what it changed for each. -->

---
id: 72
type: fix
title: Item ids that cannot collide
status: open
created: 2026-11-11
depends: 71
approved: 9eefca2ca82155e1b16fa6ced875524362a1a939 2026-11-11 joexbayer
---
# 72 Item ids that cannot collide

## Current behaviour
Reproduced in the review of 2026-11-11 (scratch `mine/ids.sh`): two clones of one origin, `sdd new` in each before either pushes: both get id 1. Both ship. The archive holds `1-ident-a` and `1-ident-b`; `sdd ls` and `sdd show 1` show only the first, with "id also on main". `next_id` reads only what the clone has seen and never asks the remote. `init` writes `mode = solo`, which nothing reads.

## Expected behaviour
FR-72.1 WHEN `new` runs and the remote (`sdd.remote`, default origin) answers THE SYSTEM SHALL take the id from the ref `refs/sdd/next-id` there: one more than the larger of its number and the highest id the clone has seen, written back so that only one of two writers wins; the loser reads again and retries, up to 5 times.
  e.g. Alice and Bob run `new` with no push between → ids 1 and 2; the remote says 5 and the clone has seen 3 → 6, and the remote then says 6
FR-72.2 WHEN the remote cannot be reached or refuses the write (offline, read-only access, a password prompt) THE SYSTEM SHALL take the clone's own next id, warn that it is not reserved, and never wait for input. No remote configured: as today, no warning.
  e.g. `sdd: warning: id 3 is not reserved on origin (could not reach it): another developer may take the same id`
FR-72.3 WHEN the ref's content does not start with a number THE SYSTEM SHALL ignore it and write a good one.
  e.g. content `x; rm -rf` → treated as 0, nothing run
FR-72.4 WHEN two items share an id anyway THE SYSTEM SHALL show both in `ls`, show each in `show <id>`, and warn at ship.
  e.g. `ls` lists `1 … Ident A` and `1 … Ident B`; `show 1` prints both, one after the other; ship: `warning: id 1 is also 1-ident-a on main`
FR-72.5 WHEN `init` writes a config THE SYSTEM SHALL not write `mode`, and the defaults SHALL not have it.
  e.g. a new `.sdd/config` has profile, base and the checks; an old `mode = solo` line is ignored as before

How:
- `common.sh` `next_id`, inside its lock: `git fetch -q <remote> +refs/sdd/next-id:refs/sdd/next-id` (absent ref: fine), read the first field, compute, write a blob `<n> <nonce>` (the nonce: user, time, pid), `git push -q --force-with-lease=refs/sdd/next-id:<old or empty> <remote> <blob>:refs/sdd/next-id   # C-4: new (id)`. `GIT_TERMINAL_PROMPT=0` on both.
- `tests/constitution/c4-commits.sh`: that one push line is allowed.
- `ls.sh`, `show.sh`: no de-duplication by id. `ship.sh`: the warning. `init.sh`, `core/config`: no `mode`.
D-72.1 One counter ref, not one marker ref per id: no growth, nothing to clean up. A deleted ref heals itself: the next `new` recomputes from the ids it has seen.
D-72.2 The nonce is needed: git treats a push of the same blob as "up to date", so two claims of the same number would both succeed (tested in scratch `mine/cas.sh`).
D-72.3 A shared id only warns at ship: it now needs two people offline at once, and renumbering a built item is worse than the duplicate.
D-72.4 Not tried against GitHub yet (pushing is the owner's call): the first `sdd new` after this ships does. If GitHub refuses the ref, FR-72.2's warning shows it and ids work as today.

## Must not change
- No remote, or a `--worktree`: ids as today, unique across the worktrees of a clone (the lock stays).
- `new` creates no other ref on the remote and pushes no branch. `next`, `status`, `ls` make no network call.
- Ids never go down and are never reused; gaps are fine (C-3).

## Security
- The ref's content comes from the remote: only its leading digits are used (FR-72.3), compared and added as numbers, never evaluated.
- What leaves the machine: a number and a nonce (user name, time, pid) in one ref. No code, no item text. Allowed by C-4 as amended in item 71.
- An agent runs `new`: a credential prompt must not hang it (FR-72.2, `GIT_TERMINAL_PROMPT=0`).
- A teammate with push rights can set a huge number: ids jump, nothing breaks; accepted.

## Test
Written first, seen to fail: `tests/t_new.sh` (two clones of a bare origin: ids 1 and 2; remote ahead; unreachable remote warns; bad content; a lost race, by moving the ref between the read and the write), `tests/t_query.sh` or `t_ship.sh` (FR-72.4), `tests/t_init.sh` (FR-72.5), `tests/constitution/c4-commits.sh` still passes.

## Tasks
- [x] T-72.1 The remote test fails first, FR-72.1 (files: tests/t_new.sh; test: SRC=$PWD SH=dash dash tests/t_new.sh; expect: fail; size: S)
- [x] T-72.2 Reserve the id on the remote; fall back with a warning; ignore bad content, FR-72.1 FR-72.2 FR-72.3 (files: .sdd/core/lib/common.sh, tests/constitution/c4-commits.sh, tests/t_new.sh; test: for t in new open roadmap; do SRC=$PWD SH=dash dash tests/t_$t.sh || exit 1; done && sh tests/constitution/c4-commits.sh; size: M)
- [x] T-72.3 Shared ids are shown, not hidden; no mode key, FR-72.4 FR-72.5 (files: .sdd/core/cmd/ls.sh, .sdd/core/cmd/show.sh, .sdd/core/cmd/ship.sh, .sdd/core/cmd/init.sh, .sdd/core/config, tests/t_query.sh, tests/t_init.sh; test: for t in query init ship serve_clone; do SRC=$PWD SH=dash dash tests/t_$t.sh || exit 1; done; size: M)

## Built
- FR-72.1: `common.sh` `reserve_id` (called by `next_id` inside its lock): `ls-remote`, fetch, then a push of blob `<n> <nonce>` with `--force-with-lease`, 5 tries. Test: `t_new.sh` (two clones → 1, 2; remote ahead; clone ahead; a lost race via a git wrapper). The verifier ran 10 rounds of simultaneous `new` in two clones: ids 1..20, no repeats.
- FR-72.2: no answer or a refused write → the clone's own id and a warning naming the reason; `GIT_TERMINAL_PROMPT=0`, and ssh gets `-o BatchMode=yes -o ConnectTimeout=10` (on top of `GIT_SSH_COMMAND` or `core.sshCommand`). Test: `t_new.sh` (unreachable, refused by a pre-receive hook, ssh options, no remote).
- FR-72.3: only leading digits of the ref's first line count. Test: `t_new.sh` (`x; rm -rf` → replaced, no shell error printed).
- FR-72.4: `item_sources` keeps one source per folder, so `ls` lists both twins and `show <id>` prints each; `ship.sh` warns when the base has another folder with the id. Test: `t_query.sh`, `t_ship.sh`.
- FR-72.5: `init.sh` and core `config` write no `mode`. Test: `t_init.sh`.
- `tests/constitution/c4-commits.sh` allows the one `# C-4: new (id)` line.
- Deviations: `collides_with` removed from `ls --json`, `show --json` and sdd-server's item line (its only reader); `show --json` prints one object per line for a shared id; the TSV keeps an always-empty `collides` column so field numbers stay; stale texts fixed in `tidy.sh` and the sdd-dev skill; `t_ship.sh` compares `ls-remote --heads`.
- Known limits: with a shared id, `depends: <id>` and sdd-server's `show` take the first (archived) twin (D-72.3: a shared id now needs two people offline). A ref holding a number of 19+ digits overflows shell arithmetic: the id falls back or wraps negative once, and the next `new` recovers; only a teammate with push rights can write it.
- Security pass (the verifier, on the diff): ref content is never evaluated (`x; rm -rf`, `$(touch …)` ran nothing); only a number and a nonce leave the machine.

Verified by: claude-opus-5-5: 5 of 5 FRs proven, real race clean; sdd-server test broke on the removed collides_with, ssh could prompt or stall 76 s, refused write untested: all fixed with tests; overflow and twin lookups left as known limits

## Review (optional)

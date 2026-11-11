---
id: 70
type: fix
title: Server survives a stalled host and has safe defaults
status: open
created: 2026-11-11
approved: 763054552ba78033d099a2310d2000004c2ada2c 2026-11-11 joexbayer
---
# 70 Server survives a stalled host and has safe defaults

## Current behaviour
From the whole-project review (2026-11-11); reproduction tests are in the session scratch folder (`rev-server/server/test/review*.test.ts`). No way in was found; these are operational.
1. A git host that accepts the connection and never answers: ssh has no timeout options, repos are polled in turn, so a healthy repo refreshed every 61 s with a 1 s interval; each round left an ssh process running (the timeout kills only git, not its ssh child). In Docker, node is PID 1 and never reaps them.
2. The index (`sdd ls --json`) shares a fixed 60 s limit with `show`: 150 open item branches on 20k commits timed out on the first run.
3. `listen` defaults to `:8080`: every interface, plain HTTP, bearer tokens readable to whoever reaches the port. The systemd path says Caddy proxies to 127.0.0.1:8080.
4. `Authorization: bearer <token>` (lowercase scheme) gets 401; the scheme is case-insensitive (RFC 9110).
5. Docker quick start: the container runs as uid 1000 and cannot read root-owned 0600 deploy keys; the error shown is ssh's "Permission denied (publickey)".
6. systemd unit: nothing creates `/var/lib/sdd-server`, so `ProtectSystem=strict` with `ReadWritePaths` fails the unit; `ExecStart=/usr/bin/sdd-server` is wrong where npm installs to `/usr/local/bin`.
7. README installs `sdd-server@0.1.0` from npm, which is not published; step 4 needs Node though "a host with Docker" is all it asks for; server releases are tagged `v<version>`, the namespace sdd's own tags use (v0.1.1 is taken).

## Expected behaviour
FR-70.1 WHEN the server fetches or clones over ssh THE SYSTEM SHALL give ssh a connect timeout of 20 s and keepalives (15 s, 3 missed).
  e.g. `GIT_SSH_COMMAND` holds `-o ConnectTimeout=20 -o ServerAliveInterval=15 -o ServerAliveCountMax=3`
FR-70.2 WHEN a subprocess passes its time limit THE SYSTEM SHALL kill it and every process it started.
  e.g. `sh -c 'sleep 300 & wait'` with a 1 s limit → returns "timed out after 1 s" and no `sleep 300` is left
FR-70.3 WHEN the server indexes a repo THE SYSTEM SHALL allow `ls` 10 minutes; `show` keeps 60 s.
  e.g. a fake sdd that takes 61 s to list: the index succeeds
FR-70.4 WHEN the config has no `listen` THE SYSTEM SHALL listen on `127.0.0.1:8080`; the Docker example config sets `listen = :8080` and says why.
  e.g. no `listen` key → the socket's address is 127.0.0.1
FR-70.5 WHEN the `Authorization` scheme is `bearer` in any case THE SYSTEM SHALL accept the token.
  e.g. `authorization: bearer <valid>` → 200; `Basic …` → 401
FR-70.6 WHEN an operator follows the Docker steps THE SYSTEM SHALL have the keys readable by the container and orphaned processes reaped.
  e.g. README step 2 ends `chown -R 1000:1000 keys` (the container's user); compose has `init: true`
FR-70.7 WHEN the systemd unit starts THE SYSTEM SHALL own its data folder, and the notes SHALL say how to find the binary.
  e.g. `StateDirectory=sdd-server`, no `ReadWritePaths`; "set ExecStart to the path `command -v sdd-server` prints"
FR-70.8 WHEN someone reads the server README THE SYSTEM SHALL say the package is not on npm yet and how to try it from a checkout, name Node 22+ for the token step, and tag server releases `server-v<version>`.
  e.g. top note: "Not on npm yet: until then, from a checkout: cd server && npm ci && node src/cli.ts serve --config …"

How:
- `run.ts`: start the child as a process-group leader and kill the group on timeout (own timer; `execFile`'s timeout kills one pid). `mirror.ts` `sshEnv`: the three options. `sdd.ts`: `sddJson` takes the limit; `repo-index.ts` passes 600 s for `ls`.
- `config.ts`: default listen. `http.ts`: `/^Bearer (\S+)$/i`.
- `deploy/compose.yaml`, `deploy/sdd-server.service`, `deploy/sdd-server.conf.example`, `README.md`.
D-70.1 Repos stay polled in turn (D-53.20): with the timeouts a dead host costs a round about 20 s, and parallel indexing would start one `sdd ls` per repo at once on a small box.
D-70.2 Left out, reported: the refusal log shows the proxy's address behind Caddy (Caddy's own log has the client); a base branch whose own `.sdd/config` names another base (rare, no exploit); a bad JSON line failing a whole repo (item 68 fixes the cause in sdd).
D-70.3 Publishing to npm stays the owner's step; this item only makes the README honest.

## Must not change
- The five state fixes of item 63 (stale locks, origin/HEAD, missing base, deleted refs in search, unindexed repo message).
- Strict schemas, argv-only subprocesses, the fixed environment, token hashing and constant-time compare, the Host allowlist.
- An explicit `listen = :8080` still binds every interface (Docker needs it).

## Security
- FR-70.4 closes cleartext tokens on every interface for systemd and laptop runs. Attacker: anyone who can reach port 8080; control: loopback by default, TLS at Caddy.
- FR-70.2: killing a process group must only ever signal the group the server created for that child (negative pid of the child it spawned), never its own group.
- FR-70.5 only relaxes the scheme's case; the token compare is unchanged.
- FR-70.6: `chown` to uid 1000 keeps keys 0600; no wider mode.

## Test
Written first, seen to fail: `server/test/run.test.ts` (new; FR-70.2), `mirror.test.ts` (FR-70.1), `index.test.ts` (FR-70.3), `config.test.ts` and `http.test.ts` (FR-70.4, 70.5), `scripts/docs-check.sh` or a test over the deploy files and README (FR-70.6 to 70.8).

## Tasks
- [ ] T-70.1 Timeouts that end: process group kill, ssh options, a longer limit for the index, FR-70.1 FR-70.2 FR-70.3 (files: server/src/run.ts, server/src/mirror.ts, server/src/sdd.ts, server/src/repo-index.ts, server/test/mirror.test.ts, server/test/index.test.ts; test: sh -c 'cd server && npm test'; size: M)
- [ ] T-70.2 Loopback by default, any-case bearer, FR-70.4 FR-70.5 (files: server/src/config.ts, server/src/http.ts, server/deploy/sdd-server.conf.example, server/test/config.test.ts, server/test/http.test.ts; test: sh -c 'cd server && npm test'; size: S)
- [ ] T-70.3 Deploy files and README that work as written, FR-70.6 FR-70.7 FR-70.8 (files: server/deploy/compose.yaml, server/deploy/sdd-server.service, server/README.md; test: sh -c 'cd server && npm test && sh scripts/docs-check.sh'; size: S)

## Built

## Review (optional)

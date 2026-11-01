# sdd-server

A small server your team runs on its own domain. Agents ask it what everyone is working on,
across all your repos and unmerged branches, over MCP. Nobody has to fetch anything or read a
markdown file. It is read-only: git stays the only way anything changes.

```
 your agent ──HTTPS + your token──▶ Caddy ──▶ sdd-server ──git fetch every 60 s──▶ GitHub / GitLab
                                              runs its bundled sdd `ls --json` on each clone
```

Three tools, all read-only:

| tool | what it returns |
|---|---|
| `items` | the open items of every repo: who opened it, phase, tasks, open questions, idle days, `depends`, id collisions, and each branch's sdd version against its base. Filters: `repo`, `status` (open, shipped, dropped, all), `owner`, `idle_days` |
| `item` | one item's plan from its branch (`sdd show --json`: stories, requirements with examples, tasks with their files, decisions, questions, done-when). `raw: true` adds the item file |
| `search` | a fixed text, case-insensitive, in `specs/` on each repo's base branch and every open item's branch: repo, ref, item, path, line |

Each answer carries ready-made lines for the agent to show as they are, and the same facts as
JSON. Solo use needs none of this: `sdd ls` keeps working without a server.

## Operator (once, about 15 minutes)

You need a host with Docker, a DNS name for it, and a read-only deploy key per repo.

```sh
# 1. DNS: an A (and AAAA) record sdd.example.com → the host; ports 80 and 443 open for Caddy.
mkdir -p /opt/sdd-server/keys && cd /opt/sdd-server
curl -fsSLO https://raw.githubusercontent.com/joexbayer/sdd-harness/v0.1.0/server/deploy/{Dockerfile,compose.yaml,Caddyfile,sdd-server.conf.example}

# 2. A read-only deploy key per repo (GitHub refuses one key on two repos)
ssh-keygen -t ed25519 -N '' -C sdd-server@api -f keys/api
gh repo deploy-key add keys/api.pub --repo acme/api --title sdd-server   # read-only unless --allow-write
#    (GitLab: Settings → Repository → Deploy keys, without "Grant write permissions")

# 3. The git host's published ssh keys, not a trust-on-first-use scan
curl -fsS https://api.github.com/meta | jq -r '.ssh_keys[] | "github.com " + .' > known_hosts

# 4. A token per person: prints the token once, and the lines to paste into the config
npx sdd-server@0.1.0 token kari
npx sdd-server@0.1.0 token ola

# 5. The config, and your domain in the Caddyfile
cp sdd-server.conf.example sdd-server.conf && $EDITOR sdd-server.conf Caddyfile

# 6. Prove it before starting: clones, fetches and indexes every repo once
docker compose build && docker compose run --rm sdd-server check
#   api ok 14 items
#   web ok 6 items

# 7. Start it and look
docker compose up -d
curl -fsS https://sdd.example.com/healthz          # {"ok":true}
docker compose logs -f sdd-server                  # one JSON line per call
```

Hand each person their token through the team's password manager, never chat. Add only repos the
whole team may read: every token sees every repo.

The config (`git config` format; `sdd-server check --offline --config <file>` checks it without
touching the network):

```ini
[server]
	listen = :8080
	public-host = sdd.example.com
	data = /data
	known-hosts = /etc/sdd-server/known_hosts
	fetch-interval = 60
[repo "api"]
	url = git@github.com:acme/api.git
	key = /etc/sdd-server/keys/api
[repo "web"]
	url = git@github.com:acme/web.git
	key = /etc/sdd-server/keys/web
[token "kari"]
	sha256 = 9f2c4b1e0d6a8c3f5e7b9a1d2c4e6f8a0b1c3d5e7f9a2b4c6d8e0f1a3b5c7d9e
[token "ola"]
	sha256 = 51d07a93e2b4c6d8f0a1b3c5d7e9f2a4b6c8d0e1f3a5b7c9d2e4f6a8b0c1d3e5
```

| key | meaning |
|---|---|
| `server.listen` | address and port to listen on, default `:8080` |
| `server.public-host` | the name clients use (the `Host` the server accepts, besides loopback names). Required |
| `server.data` | where the clones live, default `/data`. A cache of git: delete it and the next start re-clones |
| `server.known-hosts` | the ssh `known_hosts` file; an unknown host key fails the clone |
| `server.fetch-interval` | seconds between fetches, default 60 |
| `repo.<name>.url`, `.key` | the ssh URL and its deploy key. Names: `[a-z0-9][a-z0-9-]{0,62}` |
| `token.<name>.sha256` | the SHA-256 of a person's token, as `token <name>` prints it |

An unknown key, a missing `public-host`, url or key, a bad hash, a hash used twice, or no token
at all stops the server at start (exit 2), naming the key.

Trying it on a laptop first needs no Docker: `npx sdd-server@0.1.0 serve --config ./sdd-server.conf`
with `public-host = localhost` (Node 22 or newer, git, ssh and a POSIX sh with awk).

| task | how |
|---|---|
| add a repo | a deploy key as in step 2, a `[repo]` block, then `docker compose restart sdd-server` |
| add or remove a person | `npx sdd-server@0.1.0 token <name>` and paste, or delete their `[token]` block; then restart |
| upgrade | set `SDD_SERVER_VERSION` in compose.yaml, then `docker compose up -d --build`. Roll back the same way |
| back up | only `sdd-server.conf` and `keys/`, into the team's secret store. The `sdd-data` volume is a cache of git |
| logs and health | `docker compose logs sdd-server` (JSON lines: who called which tool, never the token or the results); `/healthz` (no token, no repo names) for an uptime monitor |
| without Docker | `npm install -g sdd-server@0.1.0`, a `sdd-server` system user, `deploy/sdd-server.service` (set `data = /var/lib/sdd-server`), and Caddy on the host proxying to `127.0.0.1:8080` |

`sdd-server` subcommands: `serve`, `check [--offline]`, `token <name>`, `health` (the container's
healthcheck) and `version`. The config defaults to `/etc/sdd-server/config`.

## Team member (once, two minutes)

```sh
# the token from the operator, in your shell profile or password manager
export SDD_SERVER_TOKEN=sdd_…

# Claude Code: one server for all repos, so user scope
claude mcp add --scope user --transport http sdd https://sdd.example.com/mcp \
  --header "Authorization: Bearer $SDD_SERVER_TOKEN"

# Codex
codex mcp add sdd --url https://sdd.example.com/mcp --bearer-token-env-var SDD_SERVER_TOKEN

# any other client: Streamable HTTP, URL https://sdd.example.com/mcp, header Authorization: Bearer …
```

(The Claude command writes the expanded token into `~/.claude.json`, which stays in your home
folder. Codex reads the variable at start.)

Then ask in plain words: "what is the team working on?", "is anyone on tenants already?",
"show me item 22's requirements".

## What it trusts, and what it does not

- The clones hold each repo's full code and history. The deploy keys are read-only and the
  server holds no write credential, user password or database.
- Nothing from a repo runs on the server: the clones have no checkout, and the server runs the
  sdd bundled in its own package, reading each repo's `.sdd/config` only as data. A repo on another
  sdd version is read with the bundled one; `items` shows each branch's own version.
- Tool input is checked against strict schemas and reaches git only as arguments (`git grep -F
  -e <query>`), never through a shell.
- Results are your teammates' text. The tool descriptions tell agents it is data, not
  instructions.

## Developing (this repo)

```sh
cd server && npm ci        # Node 22.18 or newer runs the .ts sources directly
npm test                   # node:test; fixtures are git repos in temp folders (and a throwaway sshd)
npx tsc -p . --noEmit      # type-check
sh scripts/smoke.sh        # pack, install the tarball, run it on a fixture repo, call the tools with curl
sh scripts/linux-check.sh  # the sdd suite, these tests and smoke in node:26-trixie-slim (Docker)
```

`sdd check` in this repo runs `npm test` (so `npm ci` once first). The smoke test and the Linux
check take longer than the check's budget and run as release steps.

## Release (a human, from a clean main)

1. `git switch main && git pull`, and `.sdd/` without changes: `prepack` refuses anything else.
2. `cd server && npm ci && npm test && npm audit --omit=dev`.
3. `sh scripts/linux-check.sh`. A failure stops the release.
4. `npm publish --provenance`. `prepack` builds `dist/` and bundles `.sdd/bin`, `.sdd/core` and a
   `VERSION` stamped `<version> (<12-char commit>)` into `sdd/`.
5. Tag the commit `v<version>` and check `npx sdd-server@<version> version`.

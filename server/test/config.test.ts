import { test } from "node:test";
import assert from "node:assert/strict";
import { mkdtemp, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { loadConfig } from "../src/config.ts";

const KARI = "9f2c4b1e" + "0".repeat(56);
const OLA = "51d07a93" + "1".repeat(56);

async function cfgFile(text: string): Promise<string> {
  const dir = await mkdtemp(join(tmpdir(), "sdd-server-config-"));
  const p = join(dir, "config");
  await writeFile(p, text);
  return p;
}

const minimal = `[server]\n\tpublic-host = sdd.example.com\n[token "kari"]\n\tsha256 = ${KARI}\n`;

// FR-53.4: every key name of the plan's config example, read through git config.
test("FR-53.4 reads the plan's config example", async () => {
  const p = await cfgFile(`[server]
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
	sha256 = ${KARI}
[token "ola"]
	sha256 = ${OLA}
`);
  assert.deepEqual(await loadConfig(p), {
    listen: ":8080",
    publicHost: "sdd.example.com",
    data: "/data",
    knownHosts: "/etc/sdd-server/known_hosts",
    fetchInterval: 60,
    repos: [
      { name: "api", url: "git@github.com:acme/api.git", key: "/etc/sdd-server/keys/api" },
      { name: "web", url: "git@github.com:acme/web.git", key: "/etc/sdd-server/keys/web" },
    ],
    tokens: [
      { name: "kari", sha256: KARI },
      { name: "ola", sha256: OLA },
    ],
  });
});

test("FR-53.4 defaults: listen :8080, data /data, fetch-interval 60", async () => {
  const c = await loadConfig(await cfgFile(minimal));
  assert.equal(c.listen, ":8080");
  assert.equal(c.data, "/data");
  assert.equal(c.fetchInterval, 60);
  assert.deepEqual(c.repos, []);
});

test("FR-53.4 a value holding = and a comment is read as git reads it", async () => {
  const c = await loadConfig(await cfgFile(minimal + `[repo "api"]\n\turl = "ssh://git@host/a=b.git" ; a comment\n\tkey = /k\n`));
  assert.equal(c.repos[0].url, "ssh://git@host/a=b.git");
});

async function refused(text: string, message: string) {
  await assert.rejects(loadConfig(await cfgFile(text)), { name: "ConfigError", message });
}

test("FR-53.4 refuses a repo without url or key", async () => {
  await refused(minimal + `[repo "api"]\n\tkey = /etc/sdd-server/keys/api\n`, 'repo "api": missing url');
  await refused(minimal + `[repo "api"]\n\turl = git@github.com:acme/api.git\n`, 'repo "api": missing key');
});

test("FR-53.4 refuses unknown sections and keys, naming the key", async () => {
  await refused(minimal + `\tport = 80\n`, "unknown key token.kari.port");
  await refused(minimal + `[server]\n\tport = 80\n`, "unknown key server.port");
  await refused(minimal + `[repo "api"]\n\turl = u\n\tkey = k\n\tbranch = main\n`, "unknown key repo.api.branch");
  await refused(minimal + `[include]\n\tpath = /etc/passwd\n`, "unknown key include.path");
  await refused(minimal + `[server "x"]\n\tlisten = :1\n`, "unknown key server.x.listen");
});

test("FR-53.4 refuses a config without public-host or without a token", async () => {
  await refused(`[token "kari"]\n\tsha256 = ${KARI}\n`, "missing server.public-host");
  await refused(`[server]\n\tpublic-host = sdd.example.com\n`, "no [token] configured: add one with sdd-server token <name>");
});

test("FR-53.4 refuses a token hash that is not 64 hex characters, or one hash twice", async () => {
  await refused(`[server]\n\tpublic-host = h\n[token "kari"]\n\tsha256 = 9f2c\n`, 'token "kari": sha256 must be 64 hex characters');
  await refused(`[server]\n\tpublic-host = h\n[token "kari"]\n\tsha256 = ${"g".repeat(64)}\n`, 'token "kari": sha256 must be 64 hex characters');
  await refused(minimal + `[token "ola"]\n\tsha256 = ${KARI}\n`, 'token "ola": same sha256 as token "kari"');
});

test("FR-53.4 refuses a fetch-interval that is not a whole number of seconds", async () => {
  await refused(minimal + `[server]\n\tfetch-interval = soon\n`, "server.fetch-interval must be a whole number of seconds, not soon");
});

test("FR-53.4 refuses a file git cannot read", async () => {
  await assert.rejects(loadConfig("/nonexistent/sdd-server.conf"), { name: "ConfigError", message: /^cannot read \/nonexistent\/sdd-server\.conf/ });
});

// FR-53.5: names are the folder and log names; only [a-z0-9][a-z0-9-]{0,62}.
test("FR-53.5 refuses repo and token names outside the grammar", async () => {
  await refused(minimal + `[repo "Shop API"]\n\turl = u\n\tkey = k\n`, 'repo "Shop API": name must match [a-z0-9][a-z0-9-]{0,62}');
  await refused(minimal + `[repo "../etc"]\n\turl = u\n\tkey = k\n`, 'repo "../etc": name must match [a-z0-9][a-z0-9-]{0,62}');
  await refused(minimal + `[repo "${"a".repeat(64)}"]\n\turl = u\n\tkey = k\n`, `repo "${"a".repeat(64)}": name must match [a-z0-9][a-z0-9-]{0,62}`);
  await refused(minimal + `[token "-kari"]\n\tsha256 = ${OLA}\n`, 'token "-kari": name must match [a-z0-9][a-z0-9-]{0,62}');
  const c = await loadConfig(await cfgFile(minimal + `[repo "${"a".repeat(63)}"]\n\turl = u\n\tkey = k\n`));
  assert.equal(c.repos[0].name, "a".repeat(63));
});

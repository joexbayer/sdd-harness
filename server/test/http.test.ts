import { after, before, test } from "node:test";
import assert from "node:assert/strict";
import { spawn, execFile } from "node:child_process";
import { writeFile } from "node:fs/promises";
import http from "node:http";
import { join } from "node:path";
import { newToken } from "../src/auth.ts";
import type { Config } from "../src/config.ts";
import { failingRepos, listen } from "../src/http.ts";
import { RepoIndex } from "../src/repo-index.ts";
import { BUNDLED, freePort, makeRepo, type Fixture } from "./fixtures.ts";
import { rpcResult } from "./mcp.ts";

const CLI = join(import.meta.dirname, "..", "src", "cli.ts");
const kari = newToken();
const ola = newToken();

let f: Fixture;
let cfg: Config;
let ix: RepoIndex;
let server: http.Server;
let base: string;
const lines: Record<string, unknown>[] = [];

before(async () => {
  f = await makeRepo();
  f.work.newItem("feature", "Login", "kari");
  const port = await freePort();
  cfg = { listen: `127.0.0.1:${port}`, publicHost: "sdd.example.com", data: join(f.root, "data"), knownHosts: "",
    fetchInterval: 60, repos: [{ name: "api", url: f.origin, key: "k" }],
    tokens: [{ name: "kari", sha256: kari.sha256 }, { name: "ola", sha256: ola.sha256 }] };
  ix = new RepoIndex({ data: cfg.data, knownHosts: "", bundled: BUNDLED, repos: cfg.repos });
  await ix.rebuild(cfg.repos[0]);
  server = listen(cfg, ix, (l) => lines.push(l));
  await new Promise((r) => server.once("listening", r));
  base = `http://127.0.0.1:${port}`;
});
after(() => server.close());

// post: a JSON-RPC request over a real socket, as an MCP client sends it.
function post(body: unknown, headers: Record<string, string> = {}): Promise<Response> {
  return fetch(`${base}/mcp`, { method: "POST", body: JSON.stringify(body), headers: {
    "content-type": "application/json", accept: "application/json, text/event-stream", ...headers } });
}
const itemsCall = { jsonrpc: "2.0", id: 2, method: "tools/call", params: { name: "items", arguments: {} } };
const auth = (t: string) => ({ authorization: `Bearer ${t}`, "mcp-protocol-version": "2025-06-18" });

// FR-53.12: no token, or a token that matches no hash: 401, WWW-Authenticate: Bearer, no tool.
test("FR-53.12 a request without a valid bearer token gets 401 and runs no tool", async () => {
  const n = lines.length;
  for (const h of [{}, { authorization: "Bearer sdd_not-a-token" }, { authorization: `Basic ${kari.token}` },
    { authorization: `Bearer ${kari.sha256}` }]) {
    const r = await post(itemsCall, h);
    assert.equal(r.status, 401);
    assert.equal(r.headers.get("www-authenticate"), "Bearer");
  }
  assert.equal(lines.slice(n).some((l) => "tool" in l), false);
});

// FR-53.16: each refusal is one log line with the address, never the token.
test("FR-53.16 a refused request is logged with its address and no token", async () => {
  const n = lines.length;
  await post(itemsCall, { authorization: "Bearer sdd_guess-1234" });
  const got = lines.slice(n);
  assert.equal(got.length, 1);
  assert.equal(got[0].auth, "refused");
  assert.equal(got[0].addr, "127.0.0.1");
  assert.match(String(got[0].t), /^\d{4}-\d\d-\d\dT\d\d:\d\d:\d\dZ$/);
  assert.equal(JSON.stringify(got[0]).includes("guess"), false);
});

// FR-53.13: only public-host and loopback names pass, even with a good token.
test("FR-53.13 a Host that is neither public-host nor loopback gets 403", async () => {
  const n = lines.length;
  const r = await new Promise<number>((res, rej) => {
    const q = http.request(`${base}/mcp`, { method: "POST", headers: { host: "evil.example", ...auth(kari.token),
      "content-type": "application/json", accept: "application/json, text/event-stream" } }, (s) => { s.resume(); res(s.statusCode!); });
    q.on("error", rej);
    q.end(JSON.stringify(itemsCall));
  });
  assert.equal(r, 403);
  assert.equal(lines.length, n, "nothing ran, nothing logged");
  const ok = await new Promise<number>((res, rej) => {
    const q = http.request(`${base}/mcp`, { method: "POST", headers: { host: "sdd.example.com", ...auth(kari.token),
      "content-type": "application/json", accept: "application/json, text/event-stream" } }, (s) => { s.resume(); res(s.statusCode!); });
    q.on("error", rej);
    q.end(JSON.stringify(itemsCall));
  });
  assert.equal(ok, 200);
});

// A 2025-era client over a real socket: initialize, list the tools, call one.
test("FR-53.12 a client with a token connects, lists the tools and calls them", async () => {
  const init = await post({ jsonrpc: "2.0", id: 1, method: "initialize", params: { protocolVersion: "2025-06-18",
    capabilities: {}, clientInfo: { name: "test", version: "1" } } }, { authorization: `Bearer ${kari.token}` });
  assert.equal(init.status, 200);
  assert.equal((await rpcResult(init)).result.serverInfo.name, "sdd-server");
  const list = await rpcResult(await post({ jsonrpc: "2.0", id: 2, method: "tools/list", params: {} }, auth(kari.token)));
  assert.deepEqual(list.result.tools.map((t: any) => t.name).sort(), ["item", "items", "search"]);
  const items = await rpcResult(await post(itemsCall, auth(ola.token)));
  assert.deepEqual(items.result.structuredContent.items.map((i: any) => i.title), ["Login"]);
});

// FR-53.15: one JSON line per tool call: who, what, how many, how long; no token, no results.
test("FR-53.15 each tool call writes one audit line without the token or the results", async () => {
  const n = lines.length;
  await rpcResult(await post(itemsCall, auth(kari.token)));
  await rpcResult(await post({ jsonrpc: "2.0", id: 3, method: "tools/call", params: { name: "search", arguments: { query: "login" } } }, auth(ola.token)));
  await rpcResult(await post({ jsonrpc: "2.0", id: 4, method: "tools/call", params: { name: "item", arguments: { repo: "api", id: 99 } } }, auth(kari.token)));
  const got = lines.slice(n);
  assert.equal(got.length, 3);
  const [a, b, c] = got;
  assert.deepEqual({ ...a, t: "", ms: 0 }, { t: "", who: "kari", tool: "items", repo: "", q: "", n: 1, ms: 0 });
  assert.equal(typeof a.ms, "number");
  assert.deepEqual({ ...b, t: "", ms: 0 }, { t: "", who: "ola", tool: "search", repo: "", q: "login", n: (b as any).n, ms: 0 });
  assert.ok((b.n as number) > 0);
  assert.deepEqual({ ...c, t: "", ms: 0 }, { t: "", who: "kari", tool: "item", repo: "api", id: 99, n: 0, ms: 0,
    error: "no item 99 in api (repos: api)" });
  const all = JSON.stringify(got);
  for (const secret of [kari.token, ola.token, kari.sha256]) assert.equal(all.includes(secret), false);
  assert.equal(all.includes("Login"), false, "results are not logged");
});

const run = (args: string[]) => new Promise<{ code: number; out: string; err: string }>((res) => {
  execFile(process.execPath, [CLI, ...args], { encoding: "utf8" }, (e, out, err) =>
    res({ code: e ? (typeof e.code === "number" ? e.code : 1) : 0, out, err }));
});

async function configFile(c: Config): Promise<string> {
  const p = join(f.root, `config-${Math.random().toString(36).slice(2)}`);
  await writeFile(p, [`[server]`, `\tlisten = ${c.listen}`, `\tpublic-host = ${c.publicHost}`, `\tdata = ${c.data}`,
    `\tfetch-interval = ${c.fetchInterval}`, ...c.repos.flatMap((r) => [`[repo "${r.name}"]`, `\turl = ${r.url}`, `\tkey = ${r.key}`]),
    ...c.tokens.flatMap((t) => [`[token "${t.name}"]`, `\tsha256 = ${t.sha256}`]), ""].join("\n"));
  return p;
}

// FR-53.17: 200 when every repo's index is younger than three fetch intervals, else 503 and a
// count; `sdd-server health` makes the GET and exits 0 or 1.
test("FR-53.17 healthz says ok or how many repos fail, naming none; health exits 0 or 1", async () => {
  const r = await fetch(`${base}/healthz`);
  assert.equal(r.status, 200);
  assert.deepEqual(await r.json(), { ok: true });
  assert.equal((await run(["health", "--config", await configFile(cfg)])).code, 0);

  // Two repos, one of which never indexed; a long interval, so a busy machine cannot age the good one.
  const port = await freePort();
  const c2: Config = { ...cfg, listen: `127.0.0.1:${port}`, fetchInterval: 600,
    repos: [...cfg.repos, { name: "web", url: join(f.root, "no-such.git"), key: "k" }] };
  const ix2 = new RepoIndex({ data: join(f.root, "data2"), knownHosts: "", bundled: BUNDLED, repos: c2.repos });
  for (const repo of c2.repos) await ix2.rebuild(repo);
  const s2 = listen(c2, ix2, () => {});
  await new Promise((res) => s2.once("listening", res));
  try {
    const bad = await fetch(`http://127.0.0.1:${port}/healthz`);
    assert.equal(bad.status, 503);
    assert.equal(await bad.text(), '{"ok":false,"failing":1}');
    assert.equal((await run(["health", "--config", await configFile(c2)])).code, 1);
    // An index older than three intervals counts as failing too.
    await new Promise((res) => setTimeout(res, 50));
    assert.equal(failingRepos({ ...c2, fetchInterval: 0.001 }, ix2), 2);
  } finally {
    s2.close();
  }
});

// FR-53.7 and FR-53.19 through the CLI: `serve` fetches every interval, and SIGTERM exits 0.
test("FR-53.7 FR-53.19 serve picks up a push within the interval and exits 0 on SIGTERM", async () => {
  const port = await freePort();
  const c: Config = { ...cfg, listen: `127.0.0.1:${port}`, data: join(f.root, "data-serve"), fetchInterval: 1 };
  const p = spawn(process.execPath, [CLI, "serve", "--config", await configFile(c)], { stdio: ["ignore", "pipe", "pipe"] });
  let out = "";
  p.stdout.on("data", (d) => (out += d));
  p.stderr.on("data", (d) => (out += d));
  const url = `http://127.0.0.1:${port}`;
  const titles = async () => {
    const r = await fetch(`${url}/mcp`, { method: "POST", body: JSON.stringify(itemsCall), headers: {
      "content-type": "application/json", accept: "application/json, text/event-stream", ...auth(kari.token) } });
    return (await rpcResult(r)).result.structuredContent.items.map((i: any) => i.title);
  };
  const until = async (ok: () => Promise<boolean>, ms: number) => {
    const end = Date.now() + ms;
    while (Date.now() < end) {
      if (await ok().catch(() => false)) return true;
      await new Promise((r) => setTimeout(r, 200));
    }
    return false;
  };
  try {
    assert.ok(await until(async () => (await fetch(`${url}/healthz`)).status === 200, 15_000), out);
    f.work.newItem("feature", "Pushed later", "ola");
    assert.ok(await until(async () => (await titles()).includes("Pushed later"), 5_000), out);
    const t0 = Date.now();
    p.kill("SIGTERM");
    const code = await new Promise<number | null>((res) => p.once("exit", (c) => res(c)));
    assert.equal(code, 0, out);
    assert.ok(Date.now() - t0 < 10_000);
    await assert.rejects(fetch(`${url}/healthz`));
  } finally {
    p.kill("SIGKILL");
  }
});

// FR-53.14 through the CLI: the token once, then the lines to paste; FR-53.4: a bad config exits 2.
test("FR-53.14 token prints a new token and its config lines; a bad config exits 2", async () => {
  const t = await run(["token", "kari"]);
  assert.equal(t.code, 0);
  assert.match(t.out, /^token: sdd_[A-Za-z0-9_-]{43}\n\[token "kari"\]\n\tsha256 = [0-9a-f]{64}\n$/);
  const p = join(f.root, "bad-config");
  await writeFile(p, `[server]\n\tpublic-host = h\n[repo "api"]\n\tkey = /etc/sdd-server/keys/api\n[token "kari"]\n\tsha256 = ${kari.sha256}\n`);
  const bad = await run(["serve", "--config", p]);
  assert.equal(bad.code, 2);
  assert.equal(bad.err, 'sdd-server: repo "api": missing url\n');
  const name = await run(["token", "Shop API"]);
  assert.equal(name.code, 2);
  assert.equal(name.err, 'sdd-server: token "Shop API": name must match [a-z0-9][a-z0-9-]{0,62}\n');
});

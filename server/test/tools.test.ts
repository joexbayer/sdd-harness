import { before, test } from "node:test";
import assert from "node:assert/strict";
import { execFileSync } from "node:child_process";
import { readFileSync } from "node:fs";
import { join } from "node:path";
import { RepoIndex, type Row } from "../src/repo-index.ts";
import { BUNDLED, makeRepo, Work, type Fixture } from "./fixtures.ts";
import { caller } from "./mcp.ts";

const OLD = "0.1.0 (77aa01b2c3d4)";
const NEW = "0.1.0 (1a2b3c4d5e6f)";
const IDLE_SINCE = "2026-01-01";
const today = () => new Date().toISOString().slice(0, 10);
const idleSince = () => Math.round((Date.parse(`${today()}T00:00:00Z`) - Date.parse(`${IDLE_SINCE}T00:00:00Z`)) / 86_400_000);

let api: Fixture;
let web: Fixture;
let ix: RepoIndex;
let call: ReturnType<typeof caller>;

// api: 1 fix "Typo" (ola) branched before main upgraded sdd; 2 feature "Login" (kari) with a
// requirement, a task and a question; 3 feature "Old work" (kari) idle since 2026-01-01; 9 dropped.
// web: 1 feature "Page" (ola) whose item file is over 256 KB.
before(async () => {
  api = await makeRepo();
  await api.work.write(".sdd/VERSION", `${OLD}\n`);
  api.work.commit("sdd old");
  api.work.push();
  api.work.newItem("fix", "Typo", "ola");
  await api.work.write(".sdd/VERSION", `${NEW}\n`);
  api.work.commit("upgrade sdd");
  api.work.push();
  const login = api.work.newItem("feature", "Login", "kari");
  api.work.git("switch", "-q", login);
  const f = "specs/changes/2-login/item.md";
  await api.work.write(f, (await api.work.read(f)).replace("## What changes\n", "## What changes\n" +
    "FR-2.1 WHEN asked THE SYSTEM SHALL log in.\n  e.g. `login kari` → session\n\n" +
    "- [ ] T-2.1 the form (files: src/a.go, src/b.go)\n\nQ-2.1 How long? → recommend: 30 days\n\n"));
  api.work.as("kari").commit("plan 2");
  api.work.push();
  api.work.git("switch", "-q", "main");
  const at = `${IDLE_SINCE}T12:00:00Z`;
  new Work(api.work.dir, { ...api.work.env, GIT_AUTHOR_DATE: at, GIT_COMMITTER_DATE: at }).newItem("feature", "Old work", "kari");
  await api.work.write("specs/archive/9-gone/item.md", "---\nid: 9\ntype: chore\ntitle: Gone\nstatus: dropped\n---\n# 9 Gone\n");
  api.work.commit("drop 9");
  api.work.push();

  web = await makeRepo({ root: join(api.root, "web") });
  const page = web.work.newItem("feature", "Page", "ola");
  web.work.git("switch", "-q", page);
  const p = "specs/changes/1-page/item.md";
  await web.work.write(p, (await web.work.read(p)) + "\n" + "long line of notes\n".repeat(20_000));
  web.work.commit("notes");
  web.work.push();
  web.work.git("switch", "-q", "main");

  ix = new RepoIndex({ data: join(api.root, "data"), knownHosts: "", bundled: BUNDLED, repos: [
    { name: "web", url: web.origin, key: "k" }, { name: "api", url: api.origin, key: "k" }] });
  for (const r of ix.repos) await ix.rebuild(r);
  call = caller(ix);
});

const ids = (s: any) => s.items.map((i: any) => `${i.repo} ${i.id}`);

// FR-53.20: every open item of every repo, sorted by repo then id, with the repos and versions.
test("FR-53.20 items lists the open items of every repo with their facts", async () => {
  const r = await call("items", {});
  assert.equal(r.isError, false, r.text);
  const s = r.structured;
  assert.deepEqual(ids(s), ["api 1", "api 2", "api 3", "web 1"]);
  assert.equal(s.server_sdd, readFileSync(join(BUNDLED, "VERSION"), "utf8").split("\n")[0]);
  assert.deepEqual(s.repos.map((x: any) => [x.name, x.ok, x.error, x.sdd]), [
    ["api", true, "", NEW], ["web", true, "", (await web.work.read(".sdd/VERSION")).trim()]]);
  assert.match(s.repos[0].fetched, /^\d{4}-\d\d-\d\dT\d\d:\d\d:\d\dZ$/);
  const login = s.items[1];
  for (const k of ["repo", "id", "type", "title", "status", "phase", "reason", "opened_by", "approved_by", "branch", "active",
    "idle_days", "tasks_done", "tasks_total", "questions_open", "depends", "collides_with", "sdd", "sdd_vs_base"]) {
    assert.ok(k in login, `missing ${k}`);
  }
  assert.deepEqual([login.repo, login.id, login.type, login.title, login.status, login.opened_by, login.branch,
    login.tasks_done, login.tasks_total, login.questions_open, login.sdd, login.sdd_vs_base, login.idle_days],
  ["api", 2, "feature", "Login", "open", "kari", "origin/feature/2-login", 0, 1, 1, NEW, "same", 0]);
  assert.equal(s.truncated, false);
});

// FR-53.21: status, owner (case-insensitive substring of opened_by) and idle_days, all at once.
test("FR-53.21 items filters by status, owner and idle days", async () => {
  assert.deepEqual(ids((await call("items", { status: "all" })).structured), ["api 1", "api 2", "api 3", "api 9", "web 1"]);
  assert.deepEqual(ids((await call("items", { status: "dropped" })).structured), ["api 9"]);
  assert.deepEqual(ids((await call("items", { status: "shipped" })).structured), []);
  assert.deepEqual(ids((await call("items", { owner: "KAR" })).structured), ["api 2", "api 3"]);
  assert.deepEqual(ids((await call("items", { idle_days: 14 })).structured), ["api 3"]);
  assert.equal((await call("items", { idle_days: 14 })).structured.items[0].idle_days, idleSince());
  assert.deepEqual(ids((await call("items", { owner: "ola", idle_days: 14 })).structured), []);
  const w = (await call("items", { repo: "web" })).structured;
  assert.deepEqual(ids(w), ["web 1"]);
  assert.deepEqual(w.repos.map((x: any) => x.name), ["web"]);
});

// FR-53.22 and FR-53.29: the lines an agent relays as they are, ending with the behind branches.
test("FR-53.22 FR-53.29 items' text is a header, one line per item and the behind warning", async () => {
  const r = await call("items", {});
  assert.equal(r.text, [
    "2 repos, 4 open items",
    "api 1 fix plan · Typo · ola · idle 0d",
    "api 2 feature plan · Login · kari · 0/1 tasks · 1 open question · idle 0d",
    `api 3 feature plan · Old work · kari · idle ${idleSince()}d`,
    "web 1 feature plan · Page · ola · idle 0d",
    "sdd behind main: api 1 (merge main into it)",
  ].join("\n"));
  assert.equal(r.structured.items[0].sdd_vs_base, "behind");
  assert.equal(r.structured.items[0].sdd, OLD);
});

// FR-53.23: what sdd show --json gives, plus repo.
test("FR-53.23 item is sdd show --json of the item, plus repo", async () => {
  const r = await call("item", { repo: "api", id: 2 });
  assert.equal(r.isError, false, r.text);
  const full = join(api.root, "full");
  execFileSync("git", ["clone", "-q", api.origin, full], { env: api.env });
  const shown = JSON.parse(execFileSync("/bin/sh", [join(BUNDLED, "bin", "sdd"), "show", "2", "--json"], { cwd: full, env: api.env, encoding: "utf8" }));
  assert.deepEqual(r.structured, { repo: "api", ...shown });
  assert.deepEqual(r.structured.requirements, [{ id: "FR-2.1", text: "WHEN asked THE SYSTEM SHALL log in.", example: "`login kari` → session" }]);
  assert.deepEqual(r.structured.tasks.map((t: any) => [t.id, t.done, t.files]), [["T-2.1", false, ["src/a.go", "src/b.go"]]]);
  assert.equal(r.text, [
    "api 2 feature plan · Login · kari · origin/feature/2-login",
    "FR-2.1 WHEN asked THE SYSTEM SHALL log in.",
    "Q-2.1 How long? → recommend: 30 days",
    "tasks 0/1 done",
  ].join("\n"));
  assert.equal("markdown" in r.structured, false);
});

// FR-53.24: raw adds the item file at the ref it was read from, cut at 256 KB.
test("FR-53.24 item with raw adds the item file, cut at 256 KB", async () => {
  const r = await call("item", { repo: "api", id: 2, raw: true });
  assert.ok(r.structured.markdown.startsWith("---\nid: 2\n"), r.structured.markdown.slice(0, 40));
  assert.match(r.structured.markdown, /FR-2\.1 WHEN asked/);
  assert.equal(r.structured.markdown_truncated, false);
  const big = await call("item", { repo: "web", id: 1, raw: true });
  assert.equal(big.structured.markdown_truncated, true);
  assert.equal(Buffer.byteLength(big.structured.markdown), 256 * 1024);
});

// FR-53.25: a missing repo or id is a tool error that lists the known repos.
test("FR-53.25 item names what is missing and the known repos", async () => {
  const r = await call("item", { repo: "api", id: 99 });
  assert.equal(r.isError, true);
  assert.equal(r.text, "no item 99 in api (repos: api, web)");
  const n = await call("item", { repo: "nope", id: 1 });
  assert.equal(n.isError, true);
  assert.equal(n.text, "no repo nope (repos: api, web)");
});

// A stub index for the cases a fixture repo cannot cheaply make (1,400 items, long titles).
function stub(rows: Partial<Row>[]) {
  let shows = 0;
  const full = rows.map((r, i) => ({ id: i + 1, type: "feature", status: "open", phase: "build", title: "T", branch: "origin/feature/x",
    source: "remote", opened_by: "kari", active: today(), tasks_done: 0, tasks_total: 0, questions_open: 0, depends: "",
    collides_with: "", sdd: "0.1.0 (x)", sdd_vs_base: "same", ...r }));
  const snap = { repo: "api", base: "main", ok: true, error: "", fetched: "2026-11-01T10:00:00Z", gen: 1, sdd: "0.1.0 (x)", rows: full, home: "", clone: "" };
  const ix = { names: () => ["api"], snapshot: (n: string) => (n === "api" ? snap : undefined), serverSdd: "0.1.0 (x)",
    show: async () => { shows++; return { repo: "api", id: 1 }; } } as unknown as RepoIndex;
  return { ix, shows: () => shows };
}

test("FR-53.22 an item line is at most 120 characters", async () => {
  const s = stub([{ title: "A very long title ".repeat(12), depends: "22", collides_with: "origin/fix/1-typo" }]);
  const r = await caller(s.ix)("items", {});
  const line = r.text.split("\n")[1];
  assert.ok(line.length <= 120, `${line.length}: ${line}`);
  assert.ok(line.startsWith("api 1 feature build · A very long title"), line);
  assert.ok(line.endsWith("… · kari · idle 0d · depends 22 · id also on origin/fix/1-typo"), line);
});

// FR-53.26: a bad input is refused by the schema before anything runs.
test("FR-53.26 bad input is refused by the schema and runs nothing", async () => {
  const s = stub([{}]);
  const lines: object[] = [];
  const c = caller(s.ix, (l) => lines.push(l));
  for (const [tool, args] of [
    ["items", { repo: "../etc" }], ["item", { repo: "api", id: "23; rm" }], ["items", { bogus: 1 }],
    ["items", { owner: "x".repeat(201) }], ["item", { repo: "api", id: 0 }], ["item", { repo: "api", id: 1_000_000_000 }],
    ["items", { idle_days: -1 }], ["items", { status: "maybe" }], ["item", { repo: "api", id: 1.5 }], ["item", { id: 1 }],
  ] as const) {
    const r = await c(tool, args);
    assert.equal(r.isError, true, `${tool} ${JSON.stringify(args)} was accepted`);
    assert.match(r.text, /validation/i);
  }
  assert.equal(s.shows(), 0);
  assert.equal(lines.length, 0);
  assert.equal((await c("items", { owner: "x".repeat(200) })).isError, false);
});

// FR-53.27: at most 1,000 items, and truncated says so.
test("FR-53.27 items returns the first 1,000 and truncated", async () => {
  const s = stub(Array.from({ length: 1400 }, () => ({})));
  const r = await caller(s.ix)("items", { status: "all" });
  assert.equal(r.structured.items.length, 1000);
  assert.equal(r.structured.truncated, true);
  assert.equal(r.structured.items[999].id, 1000);
  assert.equal(r.text.split("\n")[0], "1 repo, 1400 items · first 1000 shown");
});

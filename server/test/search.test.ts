import { before, test } from "node:test";
import assert from "node:assert/strict";
import { existsSync } from "node:fs";
import { join } from "node:path";
import { RepoIndex } from "../src/repo-index.ts";
import { search } from "../src/search.ts";
import { BUNDLED, makeRepo, type Fixture } from "./fixtures.ts";
import { caller } from "./mcp.ts";

let api: Fixture;
let web: Fixture;
let ix: RepoIndex;
let tenants: string;

// api main: an archived item 5 with "old tenant decision" and a README with "tenant" (not under
// specs/). Item 6 "Many tenants" branches from it and plans FR-6.3. After that, main gets
// specs/kb/tenancy.md, so only main has it. web main: 60 lines with "the" in a spec.
before(async () => {
  api = await makeRepo();
  await api.work.write("specs/archive/5-old/item.md", "---\nid: 5\ntype: chore\ntitle: Old\nstatus: shipped\n---\n# 5 Old\nold tenant decision\n");
  await api.work.write("README.md", "a tenant in the readme\n");
  api.work.commit("archive 5");
  api.work.push();
  tenants = api.work.newItem("feature", "Many tenants", "kari");
  api.work.git("switch", "-q", tenants);
  const f = "specs/changes/6-many-tenants/item.md";
  await api.work.write(f, (await api.work.read(f)).replace("## What changes\n",
    "## What changes\nFR-6.3 WHEN a key names its Tenant THE SYSTEM SHALL route to it.\n" + "x".repeat(400) + " tenant\n\n"));
  api.work.commit("plan 6");
  api.work.push();
  api.work.git("switch", "-q", "main");
  await api.work.write("specs/kb/tenancy.md", "# Tenancy\n\nEvery tenant owns its keys.\n");
  api.work.commit("kb");
  api.work.push();

  web = await makeRepo({ root: join(api.root, "web") });
  await web.work.write("specs/kb/the.md", Array.from({ length: 60 }, (_, i) => `the line ${i + 1}`).join("\n") + "\n");
  web.work.commit("the");
  web.work.push();

  ix = new RepoIndex({ data: join(api.root, "data"), knownHosts: "", bundled: BUNDLED, repos: [
    { name: "api", url: api.origin, key: "k" }, { name: "web", url: web.origin, key: "k" }] });
  for (const r of ix.repos) await ix.rebuild(r);
});

// FR-53.30: fixed-string, case-insensitive, over specs/ on the base and every open item's branch.
test("FR-53.30 search finds the query in open items' plans and on the base branch", async () => {
  const out = await search(ix, { query: "TENANT", repo: "api" });
  assert.equal(out.truncated, false);
  const plan = out.matches.find((m) => m.text.startsWith("FR-6.3"));
  assert.deepEqual(plan, { repo: "api", ref: `origin/${tenants}`, item: 6, path: "specs/changes/6-many-tenants/item.md",
    line: plan!.line, text: "FR-6.3 WHEN a key names its Tenant THE SYSTEM SHALL route to it." });
  assert.ok(plan!.line > 1);
  assert.deepEqual(out.matches.find((m) => m.path === "specs/kb/tenancy.md"),
    { repo: "api", ref: "main", item: null, path: "specs/kb/tenancy.md", line: 3, text: "Every tenant owns its keys." });
  assert.equal(out.matches.some((m) => m.path === "README.md"), false, "only specs/ is searched");
  const long = out.matches.find((m) => m.text.startsWith("xxx"));
  assert.equal(long!.text.length, 300);
  assert.deepEqual(await search(ix, { query: "t.nant", repo: "api" }), { matches: [], truncated: false });
});

test("FR-53.30 a query is text, never an option", async () => {
  const marker = join(api.root, "pwned");
  const out = await search(ix, { query: `--open-files-in-pager=touch ${marker}` });
  assert.deepEqual(out, { matches: [], truncated: false });
  assert.equal(existsSync(marker), false);
});

// FR-53.31: limit (default 50, at most 200) and the time budget.
test("FR-53.31 search stops at the limit or the time budget and says truncated", async () => {
  const d = await search(ix, { query: "the line", repo: "web" });
  assert.equal(d.matches.length, 50);
  assert.equal(d.truncated, true);
  const all = await search(ix, { query: "the line", repo: "web", limit: 200 });
  assert.equal(all.matches.length, 60);
  assert.equal(all.truncated, false);
  assert.equal((await search(ix, { query: "the line" }, 0)).truncated, true);
});

// FR-53.32: a line on the base and on an item branch is one match, from the base.
test("FR-53.32 a line on the base and an item branch is returned once, from the base", async () => {
  const out = await search(ix, { query: "old tenant decision" });
  assert.deepEqual(out.matches, [{ repo: "api", ref: "main", item: null, path: "specs/archive/5-old/item.md",
    line: 8, text: "old tenant decision" }]);
});

test("FR-53.30 FR-53.31 the search tool: schema, lines, and the cap", async () => {
  const call = caller(ix);
  const r = await call("search", { query: "tenant", repo: "api" });
  assert.equal(r.isError, false, r.text);
  // On item 6's branch: its title line, its heading, FR-6.3, the long line and item 5's archived
  // line; on main only: the kb line.
  assert.equal(r.structured.matches.length, 6);
  const lines = r.text.split("\n");
  assert.equal(lines[0], "6 matches for \"tenant\" in api");
  assert.ok(lines.includes("api 6 FR-6.3 WHEN a key names its Tenant THE SYSTEM SHALL route to it."), r.text);
  assert.ok(lines.includes("api main specs/kb/tenancy.md:3 Every tenant owns its keys."), r.text);
  for (const l of lines) assert.ok(l.length <= 120, l);
  for (const bad of [{ query: "t" }, { query: "x".repeat(201) }, { query: "tenant", limit: 201 }, { query: "tenant", limit: 0 },
    { query: "tenant", repo: "../x" }, { query: "tenant", extra: 1 }]) {
    assert.equal((await call("search", bad)).isError, true, JSON.stringify(bad));
  }
  const unknown = await call("search", { query: "tenant", repo: "nope" });
  assert.equal(unknown.isError, true);
  assert.equal(unknown.text, "no repo nope (repos: api, web)");
});

import { test } from "node:test";
import assert from "node:assert/strict";
import { execFileSync } from "node:child_process";
import { existsSync } from "node:fs";
import { readdir, readFile, rm } from "node:fs/promises";
import { join } from "node:path";
import { RepoIndex } from "../src/repo-index.ts";
import { FIXED_PATH, gitEnv } from "../src/mirror.ts";
import { BUNDLED, makeRepo, type Fixture } from "./fixtures.ts";

async function team(): Promise<Fixture> {
  const f = await makeRepo();
  f.work.newItem("feature", "Login", "kari");
  f.work.newItem("fix", "Typo", "ola");
  await f.work.write("specs/archive/9-gone/item.md", "---\nid: 9\ntype: chore\ntitle: Gone\nstatus: dropped\n---\n# 9 Gone\n");
  f.work.commit("drop 9");
  f.work.push();
  return f;
}

const index = (f: Fixture, repos: { name: string; url: string }[]) =>
  new RepoIndex({ data: join(f.root, "data"), knownHosts: "", bundled: BUNDLED,
    repos: repos.map((r) => ({ ...r, key: join(f.root, "no-key") })) });

// FR-53.8 (and FR-53.3 through the server): the bundled sdd lists what a full clone lists, and no
// file of the repo runs, even when its base commits a hostile .sdd/.
test("FR-53.8 the index is the bundled sdd's ls of the clone, and runs nothing from the repo", async () => {
  const f = await team();
  const full = join(f.root, "full");
  execFileSync("git", ["clone", "-q", f.origin, full], { env: f.env });
  const want = execFileSync("/bin/sh", [join(BUNDLED, "bin", "sdd"), "ls", "--json", "--all"], { cwd: full, env: f.env, encoding: "utf8" })
    .trim().split("\n").map((l) => JSON.parse(l));

  const ix = index(f, [{ name: "api", url: f.origin }]);
  await ix.rebuild(ix.repos[0]);
  const s = ix.snapshot("api")!;
  assert.equal(s.ok, true, s.error);
  // The rows are ls --json's, plus the server's sdd and sdd_vs_base (FR-53.28).
  assert.deepEqual(s.rows.map(({ sdd: _v, sdd_vs_base: _vs, ...r }) => r), want);
  assert.deepEqual(s.rows.map((r) => r.id), [1, 2, 9]);
  // The home holds the bundled sdd and the base's config, and nothing else of the repo.
  const home = join(f.root, "data", "homes", "api", ".sdd");
  assert.deepEqual((await readdir(home)).sort(), ["VERSION", "bin", "config", "core"]);
  assert.equal(await readFile(join(home, "config"), "utf8"), await f.work.read(".sdd/config"));

  const marker = join(f.root, "pwned");
  await f.work.write(".sdd/bin/sdd", `#!/bin/sh\n: >"${marker}"\n`);
  await f.work.write(".sdd/local/cmd/ls.sh", `: >"${marker}"\n`);
  f.work.commit("a hostile sdd");
  f.work.push();
  await ix.rebuild(ix.repos[0]);
  assert.equal(ix.snapshot("api")!.ok, true, ix.snapshot("api")!.error);
  assert.deepEqual(ix.snapshot("api")!.rows.map((r) => r.id), [1, 2, 9]);
  assert.equal(existsSync(marker), false, "a file of the repo ran");
  assert.equal(existsSync(join(home, "local")), false);
  // The fixture is armed: the repo's own copy, run in a checkout, writes the marker.
  execFileSync("git", ["pull", "-q"], { cwd: full, env: f.env });
  execFileSync("/bin/sh", [join(BUNDLED, "bin", "sdd"), "ls"], { cwd: full, env: f.env });
  assert.equal(existsSync(marker), true);
});

test("FR-53.8 sdd runs with a fixed PATH, no home, no system git config and UTC", () => {
  const e = gitEnv();
  assert.equal(e.PATH, FIXED_PATH);
  assert.equal(e.HOME, "/nonexistent");
  assert.equal(e.TZ, "UTC");
  assert.equal(e.GIT_CONFIG_NOSYSTEM, "1");
  assert.equal(e.GIT_CONFIG_GLOBAL, "/dev/null");
  assert.equal(Object.keys(e).some((k) => k.startsWith("SDD_") || k === "XDG_CONFIG_HOME"), false);
});

// FR-53.9: a fetch that moved a ref rebuilds the index; readers see the old or the new one, whole.
test("FR-53.9 a rebuild swaps the index whole, and readers meanwhile get the previous one", async () => {
  const f = await team();
  const ix = index(f, [{ name: "api", url: f.origin }]);
  await ix.rebuild(ix.repos[0]);
  const old = ix.snapshot("api")!;
  await ix.rebuild(ix.repos[0]);
  assert.equal(ix.snapshot("api")!.gen, old.gen, "nothing moved: the same index");
  assert.equal(ix.snapshot("api")!.rows, old.rows);
  const before = ix.snapshot("api")!;

  f.work.newItem("feature", "Search", "kari");
  const p = ix.rebuild(ix.repos[0]);
  const seen = [];
  for (let i = 0; i < 50; i++) {
    seen.push(ix.snapshot("api")!);
    await new Promise((r) => setTimeout(r, 5));
  }
  await p;
  const next = ix.snapshot("api")!;
  assert.equal(next.gen, old.gen + 1);
  // sdd gives the new item the id after the highest it sees (9, in the archive).
  assert.deepEqual(next.rows.map((r) => r.id), [1, 2, 9, 10]);
  assert.equal(seen.length, 50);
  for (const s of seen) assert.ok(s === before || s === next, "a reader saw a half-built index");
  assert.ok(seen.includes(before), "no call answered while the rebuild ran");
});

// FR-53.10: a failing repo keeps its last good index and says why; the others carry on.
test("FR-53.10 a failing fetch keeps the last good index and the other repos", async () => {
  const f = await team();
  const g = await makeRepo({ root: join(f.root, "web") });
  g.work.newItem("feature", "Page", "ola");
  const ix = index(f, [{ name: "api", url: f.origin }, { name: "web", url: g.origin }]);
  for (const r of ix.repos) await ix.rebuild(r);
  const good = ix.snapshot("api")!;
  assert.equal(good.ok, true);
  assert.match(good.fetched, /^\d{4}-\d\d-\d\dT\d\d:\d\d:\d\dZ$/);

  await rm(f.origin, { recursive: true });
  for (const r of ix.repos) await ix.rebuild(r);
  const bad = ix.snapshot("api")!;
  assert.equal(bad.ok, false);
  assert.match(bad.error, /does not appear to be a git repository/);
  assert.equal(bad.error.includes("\n"), false);
  assert.equal(bad.fetched, good.fetched, "fetched is the last good fetch");
  assert.deepEqual(bad.rows, good.rows);
  assert.equal(ix.snapshot("web")!.ok, true);
  assert.deepEqual(ix.snapshot("web")!.rows.map((r) => r.id), [1]);
});

test("FR-53.10 a repo that never cloned is reported with no rows", async () => {
  const f = await makeRepo();
  const ix = index(f, [{ name: "gone", url: join(f.root, "no-such.git") }]);
  await ix.rebuild(ix.repos[0]);
  const s = ix.snapshot("gone")!;
  assert.equal(s.ok, false);
  assert.equal(s.fetched, "");
  assert.deepEqual(s.rows, []);
  assert.match(s.error, /does not exist|does not appear to be a git repository/);
});

// FR-53.11 through the index: the error, and the other repos unaffected.
test("FR-53.11 a repo without .sdd/ on its base is reported, the others indexed", async () => {
  const f = await team();
  const plain = await makeRepo({ sdd: false, root: join(f.root, "plain") });
  const ix = index(f, [{ name: "api", url: f.origin }, { name: "plain", url: plain.origin }]);
  for (const r of ix.repos) await ix.rebuild(r);
  assert.equal(ix.snapshot("plain")!.ok, false);
  assert.equal(ix.snapshot("plain")!.error, "not an sdd repo: no .sdd/ on main");
  assert.equal(ix.snapshot("api")!.ok, true);
});

// FR-63.3: a configured repo with no index yet is not "no repo".
test("FR-63.3 show says a configured repo is not indexed yet, with the error", async () => {
  const f = await makeRepo();
  const ix = index(f, [{ name: "gone", url: join(f.root, "no-such.git") }, { name: "web", url: f.origin }]);
  await ix.rebuild(ix.repos[0]);
  await assert.rejects(ix.show("gone", 1, false), { message: /^repo gone is not indexed yet: .*(does not exist|does not appear to be a git repository)/ });
  await assert.rejects(ix.show("web", 1, false), { message: "repo web is not indexed yet: waiting for the first fetch" });
  await assert.rejects(ix.show("nope", 1, false), { message: "no repo nope (repos: gone, web)" });
});

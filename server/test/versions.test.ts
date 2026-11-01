import { test } from "node:test";
import assert from "node:assert/strict";
import { join } from "node:path";
import { branchVersions } from "../src/versions.ts";
import { ensureClone, fetchRepo } from "../src/mirror.ts";
import { RepoIndex } from "../src/repo-index.ts";
import { BUNDLED, makeRepo, type Fixture } from "./fixtures.ts";

const OLD = "0.1.0 (77aa01b2c3d4)";
const NEW = "0.1.0 (1a2b3c4d5e6f)";
const UP = "0.2.0 (abcdefabcdef)";

// main stamped OLD; item 1 branches; main upgrades to NEW; item 2 branches after; item 3 upgrades
// sdd itself on its branch.
async function drift(): Promise<{ f: Fixture; old: string; same: string; up: string }> {
  const f = await makeRepo();
  await f.work.write(".sdd/VERSION", `${OLD}\n`);
  f.work.commit("sdd at the old version");
  f.work.push();
  const old = f.work.newItem("feature", "Old branch", "kari");
  await f.work.write(".sdd/VERSION", `${NEW}\n`);
  f.work.commit("upgrade sdd");
  f.work.push();
  const same = f.work.newItem("feature", "New branch", "ola");
  const up = f.work.newItem("feature", "Upgrade", "kari");
  f.work.git("switch", "-q", up);
  await f.work.write(".sdd/VERSION", `${UP}\n`);
  f.work.commit("sdd 0.2.0");
  f.work.push();
  f.work.git("switch", "-q", "main");
  return { f, old, same, up };
}

// FR-53.28: .sdd/VERSION as text on the base and each branch; FR-53.29: same, behind or ahead.
test("FR-53.28 FR-53.29 branchVersions reads each branch's sdd and compares it with the base's", async () => {
  const { f, old, same, up } = await drift();
  const dir = join(f.root, "clone");
  const repo = { name: "api", url: f.origin, key: "k" };
  await ensureClone(repo, dir, "");
  const v = await branchVersions(dir, "main", [`origin/${old}`, `origin/${same}`, `origin/${up}`]);
  assert.deepEqual(v, {
    base: NEW,
    branches: {
      [`origin/${old}`]: { sdd: OLD, vs: "behind" },
      [`origin/${same}`]: { sdd: NEW, vs: "same" },
      [`origin/${up}`]: { sdd: UP, vs: "ahead" },
    },
  });

  // Merging main into the old branch brings it level.
  f.work.git("switch", "-q", old);
  f.work.git("merge", "-q", "--no-edit", "main");
  f.work.push();
  f.work.git("switch", "-q", "main");
  await fetchRepo(repo, dir, "");
  const w = await branchVersions(dir, "main", [`origin/${old}`]);
  assert.deepEqual(w.branches[`origin/${old}`], { sdd: NEW, vs: "same" });
});

test("FR-53.28 FR-53.29 the index puts sdd and sdd_vs_base on every row, the base's on the archive", async () => {
  const { f, old, same, up } = await drift();
  await f.work.write("specs/archive/9-gone/item.md", "---\nid: 9\ntype: chore\ntitle: Gone\nstatus: dropped\n---\n# 9 Gone\n");
  f.work.commit("drop 9");
  f.work.push();
  const ix = new RepoIndex({ data: join(f.root, "data"), knownHosts: "", bundled: BUNDLED,
    repos: [{ name: "api", url: f.origin, key: "k" }] });
  await ix.rebuild(ix.repos[0]);
  const s = ix.snapshot("api")!;
  assert.equal(s.ok, true, s.error);
  assert.equal(s.sdd, NEW);
  const by = Object.fromEntries(s.rows.map((r) => [r.id, [r.branch, r.sdd, r.sdd_vs_base]]));
  assert.deepEqual(by, {
    1: [`origin/${old}`, OLD, "behind"],
    2: [`origin/${same}`, NEW, "same"],
    3: [`origin/${up}`, UP, "ahead"],
    9: ["", NEW, "same"],
  });
});

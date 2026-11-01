import { test } from "node:test";
import assert from "node:assert/strict";
import { existsSync } from "node:fs";
import { readdir, rm, writeFile } from "node:fs/promises";
import { execFileSync } from "node:child_process";
import { join } from "node:path";
import { baseBranch, ensureClone, fetchRepo, projectConfig } from "../src/mirror.ts";
import { makeRepo, sshd } from "./fixtures.ts";

const refs = (dir: string, pattern: string) =>
  execFileSync("git", ["for-each-ref", "--format=%(refname) %(objectname)", pattern], { cwd: dir, encoding: "utf8" });
const rev = (dir: string, ref: string) =>
  execFileSync("git", ["rev-parse", ref], { cwd: dir, encoding: "utf8" }).trim();

// FR-53.6: a clone with no checkout, so no file of the repo is ever in a work tree.
test("FR-53.6 ensureClone makes a no-checkout clone holding the remote's branches", async () => {
  const f = await makeRepo();
  const branch = f.work.newItem("feature", "Login");
  const dir = join(f.root, "data", "repos", "api");
  await ensureClone({ name: "api", url: f.origin, key: join(f.root, "no-key") }, dir, "");
  assert.deepEqual(await readdir(dir), [".git"]);
  assert.match(refs(dir, "refs/remotes"), new RegExp(`refs/remotes/origin/${branch} `));
  assert.equal(rev(dir, "refs/heads/main"), rev(f.work.dir, "main"));
  await ensureClone({ name: "api", url: f.origin, key: join(f.root, "no-key") }, dir, "");
  assert.deepEqual(await readdir(dir), [".git"]);
});

test("FR-53.6 an ssh clone checks the host key against known-hosts, strictly", async () => {
  const f = await makeRepo({ sdd: false });
  const ssh = await sshd(f.root);
  try {
    const key = join(f.root, "deploy-key");
    execFileSync("ssh-keygen", ["-q", "-t", "ed25519", "-N", "", "-f", key]);
    const repo = { name: "x", url: `ssh://git@127.0.0.1:${ssh.port}/x.git`, key };
    const empty = join(f.root, "known_hosts.empty");
    await writeFile(empty, "");
    const dir = join(f.root, "data", "repos", "x");
    await assert.rejects(ensureClone(repo, dir, empty), { message: "Host key verification failed." });
    assert.equal(existsSync(dir), false);
    // With the host's key known, the clone gets as far as the key (which nobody authorised).
    const known = join(f.root, "known_hosts");
    await writeFile(known, `[127.0.0.1]:${ssh.port} ${ssh.hostKey}\n`);
    await assert.rejects(ensureClone(repo, dir, known), { message: /^Permission denied \(publickey/ });
  } finally {
    ssh.stop();
  }
});

// FR-53.7: fetch --prune, then the local base follows origin's.
test("FR-53.7 fetchRepo brings new and removed branches and moves the local base", async () => {
  const f = await makeRepo();
  const repo = { name: "api", url: f.origin, key: join(f.root, "no-key") };
  const dir = join(f.root, "data", "repos", "api");
  await ensureClone(repo, dir, "");
  assert.deepEqual(await fetchRepo(repo, dir, ""), { changed: false });

  const branch = f.work.newItem("feature", "Search");
  await f.work.write("NOTES.md", "more\n");
  f.work.commit("notes");
  f.work.push();
  assert.deepEqual(await fetchRepo(repo, dir, ""), { changed: true });
  assert.match(refs(dir, "refs/remotes"), new RegExp(`refs/remotes/origin/${branch} `));
  assert.equal(rev(dir, "refs/heads/main"), rev(f.work.dir, "main"));
  assert.deepEqual(await fetchRepo(repo, dir, ""), { changed: false });

  f.work.git("push", "-q", "origin", "--delete", branch);
  assert.deepEqual(await fetchRepo(repo, dir, ""), { changed: true });
  assert.doesNotMatch(refs(dir, "refs/remotes"), new RegExp(`refs/remotes/origin/${branch} `));
});

test("FR-53.7 the base is sdd.base in origin/HEAD's .sdd/config, else main", async () => {
  const f = await makeRepo();
  const repo = { name: "api", url: f.origin, key: join(f.root, "no-key") };
  f.work.git("branch", "trunk");
  f.work.git("push", "-q", "origin", "trunk");
  f.work.git("config", "-f", ".sdd/config", "sdd.base", "trunk");
  f.work.commit("base is trunk");
  f.work.push();
  const dir = join(f.root, "data", "repos", "api");
  await ensureClone(repo, dir, "");
  assert.equal(await baseBranch(dir), "trunk");
  await f.work.write("NOTES.md", "on trunk\n");
  f.work.git("switch", "-q", "trunk");
  f.work.commit("trunk moves");
  f.work.push();
  await fetchRepo(repo, dir, "");
  assert.equal(rev(dir, "refs/heads/trunk"), rev(f.work.dir, "trunk"));

  const plain = await makeRepo({ sdd: false });
  const pdir = join(plain.root, "data", "repos", "plain");
  await ensureClone({ name: "plain", url: plain.origin, key: "k" }, pdir, "");
  assert.equal(await baseBranch(pdir), "main");
});

test("FR-53.7 a sdd.base that is not a branch name is refused", async () => {
  const f = await makeRepo();
  f.work.git("config", "-f", ".sdd/config", "sdd.base", "--upload-pack=touch x");
  f.work.commit("bad base");
  f.work.push();
  const dir = join(f.root, "data", "repos", "api");
  await ensureClone({ name: "api", url: f.origin, key: "k" }, dir, "");
  await assert.rejects(baseBranch(dir), { message: "sdd.base on origin/HEAD is not a branch name: --upload-pack=touch x" });
});

// FR-53.11: no .sdd/ on the base branch.
test("FR-53.11 a base without .sdd/ is not an sdd repo", async () => {
  const plain = await makeRepo({ sdd: false });
  const dir = join(plain.root, "data", "repos", "plain");
  await ensureClone({ name: "plain", url: plain.origin, key: "k" }, dir, "");
  await assert.rejects(projectConfig(dir, "main"), { message: "not an sdd repo: no .sdd/ on main" });

  const f = await makeRepo();
  const sdir = join(f.root, "data", "repos", "api");
  await ensureClone({ name: "api", url: f.origin, key: "k" }, sdir, "");
  assert.match(await projectConfig(sdir, "main"), /base = main/);
});

test("a fetch that fails says why in one line", async () => {
  const f = await makeRepo();
  const repo = { name: "api", url: f.origin, key: "k" };
  const dir = join(f.root, "data", "repos", "api");
  await ensureClone(repo, dir, "");
  await rm(f.origin, { recursive: true });
  await assert.rejects(fetchRepo(repo, dir, ""), { message: /does not appear to be a git repository/ });
});

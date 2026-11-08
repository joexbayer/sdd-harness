import { test } from "node:test";
import assert from "node:assert/strict";
import { existsSync } from "node:fs";
import { mkdir, readdir, rm, symlink, utimes, writeFile } from "node:fs/promises";
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

const key = (f: { root: string }) => join(f.root, "no-key");

// FR-63.4: the configured url wins over the clone's stored origin.
test("FR-63.4 fetchRepo fetches from the configured url when it changed", async () => {
  const a = await makeRepo();
  const b = await makeRepo({ root: join(a.root, "b") });
  await b.work.write("ONLY-B.md", "b\n");
  b.work.commit("only b");
  b.work.push();
  const dir = join(a.root, "data", "repos", "api");
  await ensureClone({ name: "api", url: a.origin, key: key(a) }, dir, "");
  await fetchRepo({ name: "api", url: b.origin, key: key(a) }, dir, "");
  assert.equal(rev(dir, "refs/heads/main"), rev(b.work.dir, "main"));
});

// FR-63.5: origin/HEAD is refreshed when a rename left it dangling; a base missing on origin fails.
test("FR-63.5 fetchRepo refreshes a dangling origin/HEAD after the default branch is renamed", async () => {
  const f = await makeRepo();
  const repo = { name: "api", url: f.origin, key: key(f) };
  const dir = join(f.root, "data", "repos", "api");
  await ensureClone(repo, dir, "");
  // Git 2.48+ may refresh origin/HEAD on fetch by itself; keep the test deterministic.
  execFileSync("git", ["config", "remote.origin.followRemoteHEAD", "never"], { cwd: dir });
  f.work.git("config", "-f", ".sdd/config", "sdd.base", "trunk");
  f.work.commit("base is trunk");
  f.work.git("push", "-q", "origin", "main:trunk");
  execFileSync("git", ["symbolic-ref", "HEAD", "refs/heads/trunk"], { cwd: f.origin });
  execFileSync("git", ["branch", "-D", "main"], { cwd: f.origin });
  await fetchRepo(repo, dir, "");
  assert.equal(await baseBranch(dir), "trunk");
  assert.equal(rev(dir, "refs/heads/trunk"), rev(f.work.dir, "HEAD"));
});

test("FR-63.5 fetchRepo fails with the reason when the base branch is not on origin", async () => {
  const f = await makeRepo();
  f.work.git("config", "-f", ".sdd/config", "sdd.base", "trunk");
  f.work.commit("base is trunk, which origin lacks");
  f.work.push();
  const repo = { name: "api", url: f.origin, key: key(f) };
  const dir = join(f.root, "data", "repos", "api");
  await ensureClone(repo, dir, "");
  await assert.rejects(fetchRepo(repo, dir, ""), { message: "base branch trunk is not on origin" });
});

// FR-63.5: a remote HEAD that can't be resolved is no failure of its own; the base check decides.
test("FR-63.5 fetchRepo keeps working when the remote HEAD names a branch nobody pushed", async () => {
  const f = await makeRepo();
  const repo = { name: "api", url: f.origin, key: key(f) };
  const dir = join(f.root, "data", "repos", "api");
  await ensureClone(repo, dir, "");
  execFileSync("git", ["symbolic-ref", "HEAD", "refs/heads/nobody"], { cwd: f.origin });
  execFileSync("git", ["symbolic-ref", "--delete", "refs/remotes/origin/HEAD"], { cwd: dir });
  await fetchRepo(repo, dir, "");
  assert.equal(rev(dir, "refs/heads/main"), rev(f.work.dir, "HEAD"));
});

// Must not change (FR-53.11): a repo without sdd is still called that, whatever its default branch.
test("FR-63.5 a repo with no .sdd/ and no main is not an sdd repo", async () => {
  const f = await makeRepo();
  const bare = join(f.root, "plain.git");
  const src = join(f.root, "plain");
  const g = (cwd: string, ...a: string[]) => execFileSync("git", a, { cwd, stdio: "pipe" });
  g(f.root, "init", "-q", "--bare", "-b", "master", bare);
  g(f.root, "init", "-q", "-b", "master", src);
  await writeFile(join(src, "a"), "x");
  g(src, "add", "a");
  g(src, "-c", "user.name=t", "-c", "user.email=t@t", "commit", "-qm", "a");
  g(src, "push", "-q", bare, "master");
  const repo = { name: "plain", url: bare, key: key(f) };
  const dir = join(f.root, "data", "repos", "plain");
  await ensureClone(repo, dir, "");
  await assert.rejects(fetchRepo(repo, dir, ""), { message: "not an sdd repo: no .sdd/ on main" });
});

// FR-63.6: a lock left by a killed fetch stops every later fetch until it is old enough to be dead.
test("FR-63.6 fetchRepo removes a ref lock older than the fetch timeout and keeps a fresh one", async () => {
  const f = await makeRepo();
  const repo = { name: "api", url: f.origin, key: key(f) };
  const dir = join(f.root, "data", "repos", "api");
  await ensureClone(repo, dir, "");
  f.work.git("push", "-q", "origin", "HEAD:locked");
  const lock = join(dir, ".git", "refs", "remotes", "origin", "locked.lock");
  await writeFile(lock, "");
  await assert.rejects(fetchRepo(repo, dir, ""), { message: /\.lock/ });
  assert.equal(existsSync(lock), true);
  const old = new Date(Date.now() - 120_000);
  await utimes(lock, old, old);
  await fetchRepo(repo, dir, "");
  assert.equal(existsSync(lock), false);
  assert.match(refs(dir, "refs/remotes"), new RegExp(`refs/remotes/origin/locked `));
});

test("FR-63.6 lock removal does not follow a symlink out of the clone", async () => {
  const f = await makeRepo();
  const repo = { name: "api", url: f.origin, key: key(f) };
  const dir = join(f.root, "data", "repos", "api");
  await ensureClone(repo, dir, "");
  const outside = join(f.root, "outside");
  await mkdir(outside);
  const lock = join(outside, "x.lock");
  await writeFile(lock, "");
  const old = new Date(Date.now() - 120_000);
  await utimes(lock, old, old);
  await symlink(outside, join(dir, ".git", "refs", "remotes", "evil"));
  await fetchRepo(repo, dir, "");
  assert.equal(existsSync(lock), true);
});

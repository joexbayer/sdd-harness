// The server's clones: `git clone --no-checkout` under <data>/repos/<name> (D-53.9), fetched over
// ssh with the repo's deploy key and the server's known_hosts, strictly (FR-53.6, FR-53.7).
import { existsSync } from "node:fs";
import { lstat, mkdir, readdir, rename, rm } from "node:fs/promises";
import { dirname, join } from "node:path";
import { errorLine, run, type RunResult } from "./run.ts";
import type { Repo } from "./config.ts";

const CLONE_MS = 600_000;
const FETCH_MS = 60_000;
const CAP = 32 << 20;
export const FIXED_PATH = "/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin";

// gitEnv: every subprocess runs with this and nothing from the server's own environment: a fixed
// PATH, no home (so no user git, ssh or sdd config), no system git config, UTC.
export function gitEnv(extra: Record<string, string> = {}): Record<string, string> {
  return { PATH: FIXED_PATH, HOME: "/nonexistent", GIT_CONFIG_NOSYSTEM: "1", GIT_CONFIG_GLOBAL: "/dev/null",
    GIT_TERMINAL_PROMPT: "0", TZ: "UTC", ...extra };
}

export function git(dir: string, args: string[], timeoutMs = FETCH_MS): Promise<RunResult> {
  return run("git", args, { cwd: dir, env: gitEnv(), timeoutMs, maxBytes: CAP });
}

const q = (s: string) => `'${s.replace(/'/g, `'\\''`)}'`;

function sshEnv(repo: Repo, knownHosts: string): Record<string, string> {
  return gitEnv({ GIT_SSH_COMMAND: ["ssh", "-F", "/dev/null", "-i", q(repo.key), "-o", "IdentitiesOnly=yes",
    "-o", "BatchMode=yes", "-o", "StrictHostKeyChecking=yes", "-o", `UserKnownHostsFile=${q(knownHosts || "/dev/null")}`,
    "-o", "GlobalKnownHostsFile=/dev/null"].join(" ") });
}

// HEAD of a clone names no branch, so sdd never mistakes the empty work tree for the base branch
// (sdd reads the base from the work tree when HEAD is on it).
const NO_BRANCH = "refs/heads/sdd-server-no-checkout";

export async function ensureClone(repo: Repo, dir: string, knownHosts: string): Promise<void> {
  if (existsSync(join(dir, ".git"))) return;
  const tmp = `${dir}.tmp`;
  await rm(tmp, { recursive: true, force: true });
  await mkdir(dirname(dir), { recursive: true });
  const r = await run("git", ["clone", "-q", "--no-checkout", "--", repo.url, tmp],
    { env: sshEnv(repo, knownHosts), timeoutMs: CLONE_MS, maxBytes: CAP });
  if (r.code !== 0) {
    await rm(tmp, { recursive: true, force: true });
    throw new Error(errorLine(r));
  }
  const h = await git(tmp, ["symbolic-ref", "HEAD", NO_BRANCH]);
  if (h.code !== 0) throw new Error(errorLine(h));
  await rename(tmp, dir);
}

const refList = async (dir: string) =>
  (await git(dir, ["for-each-ref", "--format=%(objectname) %(refname)", "refs/heads", "refs/remotes"])).stdout;

// A fetch killed mid-update leaves a *.lock that fails every later fetch; one older than the fetch
// timeout is dead (the server is the only fetcher), a younger one may be a gc's.
async function removeStaleLocks(dir: string): Promise<void> {
  const gd = join(dir, ".git");
  const locks = [join(gd, "packed-refs.lock")];
  const walk = async (d: string): Promise<void> => {
    for (const e of await readdir(d, { withFileTypes: true })) {
      if (e.isDirectory()) await walk(join(d, e.name)); // isDirectory is false for a symlink: never followed
      else if (e.name.endsWith(".lock")) locks.push(join(d, e.name));
    }
  };
  await walk(join(gd, "refs"));
  for (const l of locks) {
    const st = await lstat(l).catch(() => null);
    if (st?.isFile() && Date.now() - st.mtimeMs > FETCH_MS) await rm(l, { force: true });
  }
}

export async function fetchRepo(repo: Repo, dir: string, knownHosts: string): Promise<{ changed: boolean }> {
  const before = await refList(dir);
  await removeStaleLocks(dir);
  // The configured url wins over the clone's stored origin.
  const set = await git(dir, ["remote", "set-url", "origin", repo.url]);
  if (set.code !== 0) throw new Error(errorLine(set));
  const env = sshEnv(repo, knownHosts);
  const r = await run("git", ["fetch", "-q", "--prune", "origin"], { cwd: dir, env, timeoutMs: FETCH_MS, maxBytes: CAP });
  if (r.code !== 0) throw new Error(errorLine(r));
  // origin/HEAD is set only at clone time (older git), so a renamed default branch leaves it dangling.
  // A remote HEAD that can't be resolved is no failure of its own: the base check below decides.
  if ((await git(dir, ["rev-parse", "-q", "--verify", "refs/remotes/origin/HEAD"])).code !== 0) {
    await run("git", ["remote", "set-head", "origin", "--auto"], { cwd: dir, env, timeoutMs: FETCH_MS, maxBytes: CAP });
  }
  const base = await baseBranch(dir);
  if ((await git(dir, ["rev-parse", "-q", "--verify", `refs/remotes/origin/${base}`])).code !== 0) {
    const sdd = await git(dir, ["cat-file", "-t", "refs/remotes/origin/HEAD:.sdd"]);
    throw new Error(sdd.code === 0 ? `base branch ${base} is not on origin` : `not an sdd repo: no .sdd/ on ${base}`);
  }
  const u = await git(dir, ["update-ref", `refs/heads/${base}`, `refs/remotes/origin/${base}`]);
  if (u.code !== 0) throw new Error(errorLine(u));
  return { changed: (await refList(dir)) !== before };
}

// baseBranch: sdd.base in the .sdd/config of origin/HEAD, read as data (no includes), else main.
export async function baseBranch(dir: string): Promise<string> {
  const r = await git(dir, ["config", "--blob", "refs/remotes/origin/HEAD:.sdd/config", "--get", "sdd.base"]);
  const b = r.code === 0 ? r.stdout.trim() : "";
  if (b === "") return "main";
  if (!/^[A-Za-z0-9][A-Za-z0-9._/-]*$/.test(b) || b.includes("..") || b.endsWith("/") || b.endsWith(".lock")) {
    throw new Error(`sdd.base on origin/HEAD is not a branch name: ${b}`);
  }
  return b;
}

// projectConfig: the base branch's .sdd/config as text (FR-53.8), or "not an sdd repo" (FR-53.11).
export async function projectConfig(dir: string, base: string): Promise<string> {
  const t = await git(dir, ["cat-file", "-t", `refs/heads/${base}:.sdd`]);
  if (t.code !== 0 || t.stdout.trim() !== "tree") throw new Error(`not an sdd repo: no .sdd/ on ${base}`);
  const c = await git(dir, ["show", `refs/heads/${base}:.sdd/config`]);
  return c.code === 0 ? c.stdout : "";
}

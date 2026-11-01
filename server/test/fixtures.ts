// Fixture repos for the server's tests, made with git (and this repo's own sdd) in temp folders.
import { execFileSync, spawn, type ChildProcess } from "node:child_process";
import { mkdtemp, mkdir, readFile, realpath, writeFile } from "node:fs/promises";
import { createServer } from "node:net";
import { tmpdir } from "node:os";
import { dirname, join, resolve } from "node:path";

export const REPO_ROOT = resolve(import.meta.dirname, "..", "..");
// The sdd the server bundles when packed (FR-53.33); in this repo, the working copy.
export const BUNDLED = join(REPO_ROOT, ".sdd");

export async function tmp(prefix = "sdd-server-test-"): Promise<string> {
  return realpath(await mkdtemp(join(tmpdir(), prefix)));
}

export class Work {
  dir: string;
  env: Record<string, string>;
  constructor(dir: string, env: Record<string, string>) {
    this.dir = dir;
    this.env = env;
  }
  // as: the same clone, with commits authored by <name>.
  as(name: string): Work {
    return new Work(this.dir, { ...this.env, GIT_AUTHOR_NAME: name, GIT_COMMITTER_NAME: name });
  }
  git(...args: string[]): string {
    return execFileSync("git", args, { cwd: this.dir, env: this.env, encoding: "utf8", stdio: ["ignore", "pipe", "pipe"] });
  }
  sdd(...args: string[]): string {
    return execFileSync("/bin/sh", [join(BUNDLED, "bin", "sdd"), ...args],
      { cwd: this.dir, env: this.env, encoding: "utf8", stdio: ["ignore", "pipe", "pipe"] });
  }
  async write(path: string, text: string): Promise<void> {
    await mkdir(dirname(join(this.dir, path)), { recursive: true });
    await writeFile(join(this.dir, path), text);
  }
  async read(path: string): Promise<string> {
    return readFile(join(this.dir, path), "utf8");
  }
  commit(message: string): void {
    this.git("add", "-A");
    this.git("commit", "-qm", message);
  }
  push(): void {
    this.git("push", "-q", "origin", "HEAD");
  }
  branch(): string {
    return this.git("symbolic-ref", "--short", "HEAD").trim();
  }
  // newItem: `sdd new <type> <title>` by <who>, pushed; back on <base> after. Returns the branch.
  newItem(type: string, title: string, who = "kari", base = "main"): string {
    const w = this.as(who);
    w.git("switch", "-q", base);
    w.sdd("new", type, title);
    const b = w.branch();
    w.push();
    w.git("switch", "-q", base);
    return b;
  }
}

export interface Fixture { root: string; origin: string; work: Work; env: Record<string, string> }

// makeRepo: a bare origin and a clone of it with one commit on <base> and (unless sdd: false) sdd
// installed and pushed.
export async function makeRepo(o: { sdd?: boolean; base?: string; root?: string } = {}): Promise<Fixture> {
  const base = o.base ?? "main";
  const root = o.root ?? await tmp();
  const home = join(root, "home");
  await mkdir(home, { recursive: true });
  const gitconfig = join(root, "gitconfig");
  await writeFile(gitconfig, "[user]\n\tname = test\n\temail = test@example.com\n[init]\n\tdefaultBranch = main\n");
  const env = { PATH: process.env.PATH ?? "/usr/bin:/bin", HOME: home, GIT_CONFIG_GLOBAL: gitconfig,
    GIT_CONFIG_NOSYSTEM: "1", TZ: "UTC" };
  const origin = join(root, "origin.git");
  execFileSync("git", ["init", "-q", "--bare", "-b", base, origin], { env });
  const dir = join(root, "work");
  execFileSync("git", ["init", "-q", "-b", base, dir], { env });
  const work = new Work(dir, env);
  await work.write("README.md", "hello\n");
  work.commit("init");
  if (o.sdd !== false) {
    work.sdd("init");
    work.commit("install sdd");
  }
  work.git("remote", "add", "origin", origin);
  work.git("push", "-q", "-u", "origin", base);
  return { root, origin, work, env };
}

// freePort: a TCP port nothing listens on right now.
export function freePort(): Promise<number> {
  return new Promise((res, rej) => {
    const s = createServer();
    s.once("error", rej);
    s.listen(0, "127.0.0.1", () => {
      const a = s.address();
      s.close(() => res(typeof a === "object" && a ? a.port : 0));
    });
  });
}

// sshd: a throwaway OpenSSH server on 127.0.0.1 with its own host key, for host-key tests. It
// authorises nobody, so a client gets as far as authentication.
export async function sshd(root: string): Promise<{ port: number; hostKey: string; stop: () => void }> {
  const bin = "/usr/sbin/sshd";
  const dir = join(root, "sshd");
  await mkdir(dir, { recursive: true });
  execFileSync("ssh-keygen", ["-q", "-t", "ed25519", "-N", "", "-f", join(dir, "host")]);
  const port = await freePort();
  await writeFile(join(dir, "config"), [`Port ${port}`, "ListenAddress 127.0.0.1", `HostKey ${join(dir, "host")}`,
    `PidFile ${join(dir, "pid")}`, "UsePAM no", "StrictModes no", `AuthorizedKeysFile ${join(dir, "none")}`, ""].join("\n"));
  const p: ChildProcess = spawn(bin, ["-D", "-e", "-f", join(dir, "config")], { stdio: ["ignore", "ignore", "pipe"] });
  await new Promise<void>((res, rej) => {
    let log = "";
    const t = setTimeout(() => rej(new Error(`${bin} did not start: ${log}`)), 5000);
    p.once("error", (e) => { clearTimeout(t); rej(new Error(`${bin} is needed for this test: ${e.message}`)); });
    p.stderr!.on("data", (d) => {
      log += d;
      if (log.includes("Server listening")) { clearTimeout(t); res(); }
    });
  });
  const hostKey = (await readFile(join(dir, "host.pub"), "utf8")).trim();
  return { port, hostKey, stop: () => p.kill() };
}

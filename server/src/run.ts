// run: one subprocess with an argv (child_process.spawn, never a shell), a timeout and an
// output cap. It never rejects: a failure is a non-zero code with the reason in stderr.
import { spawn } from "node:child_process";

export interface RunResult { code: number; stdout: string; stderr: string }

// FR-70.2: the child leads its own process group (detached), so a timeout kills it and everything
// it started; the group is only ever the one of the child this call spawned.
export function run(cmd: string, args: string[], o: { cwd?: string; env: Record<string, string>;
  timeoutMs: number; maxBytes: number; input?: string }): Promise<RunResult> {
  return new Promise((resolve) => {
    const child = spawn(cmd, args, { cwd: o.cwd, env: o.env, detached: true, stdio: ["pipe", "pipe", "pipe"] });
    const out: Buffer[] = [];
    const err: Buffer[] = [];
    let outN = 0, errN = 0;
    let why = "";
    let failed: NodeJS.ErrnoException | undefined;
    const killGroup = (reason: string) => {
      if (why === "") why = reason;
      const pid = child.pid;
      if (pid !== undefined && pid > 0) {
        try { process.kill(-pid, "SIGKILL"); } catch { /* group already gone */ }
      }
    };
    const timer = setTimeout(() => killGroup(`${cmd}: timed out after ${o.timeoutMs / 1000} s`), o.timeoutMs);
    const collect = (chunks: Buffer[], n: number, d: Buffer): number => {
      if (n >= o.maxBytes) return n;
      chunks.push(d.subarray(0, o.maxBytes - n));
      if (n + d.length > o.maxBytes) killGroup(`${cmd}: output over ${o.maxBytes} bytes`);
      return n + d.length;
    };
    child.stdout.on("data", (d: Buffer) => { outN = collect(out, outN, d); });
    child.stderr.on("data", (d: Buffer) => { errN = collect(err, errN, d); });
    child.stdin.on("error", () => {}); // a child that exits without reading its input
    child.on("error", (e: NodeJS.ErrnoException) => { failed = e; });
    child.on("close", (status) => {
      clearTimeout(timer);
      const stdout = Buffer.concat(out).toString("utf8");
      const stderr = Buffer.concat(err).toString("utf8");
      if (failed?.code === "ENOENT") return resolve({ code: 127, stdout, stderr: `${cmd}: not found\n${stderr}` });
      if (failed && why === "") why = `${cmd}: ${failed.message}`;
      let code = status ?? 1;
      if (why !== "" && code === 0) code = 1;
      resolve({ code, stdout, stderr: why === "" ? stderr : `${why}\n${stderr}` });
    });
    if (o.input !== undefined) child.stdin.end(o.input);
    else child.stdin.end();
  });
}

// errorLine: the line of a failed run that names the cause, for `error` fields and `check`:
// the line before git's first "fatal:" (ssh's own words, e.g. "Host key verification failed."),
// else the first line; ssh's "git@host: " prefix is dropped.
export function errorLine(r: RunResult): string {
  const lines = r.stderr.split("\n").map((l) => l.trim()).filter((l) => l !== "");
  const f = lines.findIndex((l) => /^(fatal|error):/.test(l));
  const line = f > 0 ? lines[f - 1] : (lines[0] ?? `exit ${r.code}`);
  return line.replace(/^[^\s:@]+@[^\s:]+: /, "");
}

// run: one subprocess with an argv (child_process.execFile, never a shell), a timeout and an
// output cap. It never rejects: a failure is a non-zero code with the reason in stderr.
import { execFile, type ExecFileException } from "node:child_process";

export interface RunResult { code: number; stdout: string; stderr: string }

export function run(cmd: string, args: string[], o: { cwd?: string; env: Record<string, string>;
  timeoutMs: number; maxBytes: number; input?: string }): Promise<RunResult> {
  return new Promise((resolve) => {
    const child = execFile(cmd, args, { cwd: o.cwd, env: o.env, timeout: o.timeoutMs, maxBuffer: o.maxBytes,
      killSignal: "SIGKILL", encoding: "utf8" }, (err, stdout, stderr) => {
      if (!err) return resolve({ code: 0, stdout, stderr });
      const e = err as ExecFileException & { code?: number | string | null };
      let code = typeof e.code === "number" ? e.code : 1;
      let why = "";
      if (e.code === "ENOENT") {
        code = 127;
        why = `${cmd}: not found`;
      } else if (e.code === "ERR_CHILD_PROCESS_STDIO_MAXBUFFER") {
        why = `${cmd}: output over ${o.maxBytes} bytes`;
      } else if (e.killed) {
        why = `${cmd}: timed out after ${o.timeoutMs / 1000} s`;
      }
      if (code === 0) code = 1;
      resolve({ code, stdout, stderr: why === "" ? stderr : `${why}\n${stderr}` });
    });
    if (o.input !== undefined) child.stdin?.end(o.input);
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

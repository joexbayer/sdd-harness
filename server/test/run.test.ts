import { test } from "node:test";
import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { join } from "node:path";
import { run } from "../src/run.ts";
import { gitEnv } from "../src/mirror.ts";
import { tmp } from "./fixtures.ts";

// alive: does a process with this pid exist (signal 0 asks without signalling)?
const alive = (pid: number) => {
  try {
    process.kill(pid, 0);
    return true;
  } catch {
    return false;
  }
};

// FR-70.2: the timeout kills the child and everything it started. The grandchild writes its own
// pid to a file, so the test needs no pgrep.
test("FR-70.2 a timed-out child's own children are killed too", async () => {
  const pidFile = join(await tmp(), "grandchild.pid");
  const started = Date.now();
  const r = await run("sh", ["-c", `sh -c 'echo $$ >"$0"; exec sleep 301' "${pidFile}" & wait`],
    { env: gitEnv(), timeoutMs: 1000, maxBytes: 1 << 20 });
  assert.equal(r.code, 1);
  assert.match(r.stderr, /^sh: timed out after 1 s\n/);
  assert.ok(Date.now() - started < 10_000);
  const pid = Number((await readFile(pidFile, "utf8")).trim());
  assert.ok(pid > 1, "the grandchild started");
  // SIGKILL is delivered at once; the kernel may take a moment to reap.
  for (let i = 0; i < 20 && alive(pid); i++) await new Promise((res) => setTimeout(res, 100));
  assert.equal(alive(pid), false);
});

test("run keeps its error texts: not found, output cap, exit code", async () => {
  const env = gitEnv();
  const nf = await run("sdd-no-such-cmd", [], { env, timeoutMs: 5000, maxBytes: 1000 });
  assert.equal(nf.code, 127);
  assert.match(nf.stderr, /^sdd-no-such-cmd: not found\n/);
  const big = await run("sh", ["-c", "head -c 5000 /dev/zero"], { env, timeoutMs: 5000, maxBytes: 1000 });
  assert.notEqual(big.code, 0);
  assert.match(big.stderr, /^sh: output over 1000 bytes\n/);
  const bad = await run("sh", ["-c", "echo out; echo err >&2; exit 3"], { env, timeoutMs: 5000, maxBytes: 1000 });
  assert.deepEqual(bad, { code: 3, stdout: "out\n", stderr: "err\n" });
  const ok = await run("cat", [], { env, timeoutMs: 5000, maxBytes: 1000, input: "hi" });
  assert.deepEqual(ok, { code: 0, stdout: "hi", stderr: "" });
});

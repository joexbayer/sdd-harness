import { test } from "node:test";
import assert from "node:assert/strict";
import { execFileSync } from "node:child_process";
import { run } from "../src/run.ts";
import { gitEnv } from "../src/mirror.ts";

const alive = (marker: string) => {
  try {
    return execFileSync("pgrep", ["-f", marker], { encoding: "utf8" }).trim() !== "";
  } catch {
    return false; // pgrep exits 1 when nothing matches
  }
};

// FR-70.2: the timeout kills the child and everything it started (found by a unique argv marker).
test("FR-70.2 a timed-out child's own children are killed too", async () => {
  const marker = `sdd-gc-${process.pid}-${Date.now()}`;
  const started = Date.now();
  const r = await run("sh", ["-c", `sh -c "sleep 301; :" ${marker} & wait`], { env: gitEnv(), timeoutMs: 1000, maxBytes: 1 << 20 });
  assert.equal(r.code, 1);
  assert.match(r.stderr, /^sh: timed out after 1 s\n/);
  assert.ok(Date.now() - started < 10_000);
  assert.equal(alive(marker), false);
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

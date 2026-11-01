import { test } from "node:test";
import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import { mkdtemp } from "node:fs/promises";
import { existsSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { newToken, tokenLines, verifyToken } from "../src/auth.ts";
import { run } from "../src/run.ts";
import type { Config } from "../src/config.ts";

const sha = (s: string) => createHash("sha256").update(s).digest("hex");

function cfgWith(tokens: Record<string, string>): Config {
  return {
    listen: ":8080", publicHost: "h", data: "/data", knownHosts: "", fetchInterval: 60, repos: [],
    tokens: Object.entries(tokens).map(([name, token]) => ({ name, sha256: sha(token) })),
  };
}

// FR-53.14: "sdd_" + 32 random bytes as base64url, and its SHA-256.
test("FR-53.14 newToken gives sdd_ and 32 random bytes, with its hash", () => {
  const a = newToken();
  const b = newToken();
  assert.match(a.token, /^sdd_[A-Za-z0-9_-]{43}$/);
  assert.equal(Buffer.from(a.token.slice(4), "base64url").length, 32);
  assert.equal(a.sha256, sha(a.token));
  assert.notEqual(a.token, b.token);
});

test("FR-53.14 tokenLines prints the token once and the config lines holding its hash", () => {
  const out = tokenLines("kari");
  const m = out.match(/^token: (sdd_[A-Za-z0-9_-]{43})\n\[token "kari"\]\n\tsha256 = ([0-9a-f]{64})\n$/);
  assert.ok(m, out);
  assert.equal(m[2], sha(m[1]));
  assert.throws(() => tokenLines("Kari"), /name must match/);
});

// FR-53.12: a bearer is accepted only when its SHA-256 matches a configured token.
test("FR-53.12 verifyToken names the token whose hash matches, and nothing else", () => {
  const cfg = cfgWith({ kari: "sdd_kari-secret", ola: "sdd_ola-secret" });
  assert.equal(verifyToken(cfg, "sdd_kari-secret"), "kari");
  assert.equal(verifyToken(cfg, "sdd_ola-secret"), "ola");
  assert.equal(verifyToken(cfg, "sdd_kari-secreT"), undefined);
  assert.equal(verifyToken(cfg, ""), undefined);
  assert.equal(verifyToken(cfg, sha("sdd_kari-secret")), undefined, "the hash itself is not a token");
});

// run: execFile with an argv, never a shell; a timeout and an output cap.
test("run passes arguments without a shell", async () => {
  const dir = await mkdtemp(join(tmpdir(), "sdd-server-run-"));
  const r = await run("echo", [`$(touch ${dir}/x)`, "a;b"], { env: { PATH: "/usr/bin:/bin" }, timeoutMs: 5000, maxBytes: 1000 });
  assert.equal(r.code, 0);
  assert.equal(r.stdout, `$(touch ${dir}/x) a;b\n`);
  assert.equal(existsSync(join(dir, "x")), false);
});

test("run reports a timeout, an output cap and a missing program as failures", async () => {
  const env = { PATH: "/usr/bin:/bin" };
  const slow = await run("sleep", ["5"], { env, timeoutMs: 100, maxBytes: 1000 });
  assert.notEqual(slow.code, 0);
  assert.match(slow.stderr, /timed out after 0\.1 s/);
  const big = await run("yes", [], { env, timeoutMs: 5000, maxBytes: 1000 });
  assert.notEqual(big.code, 0);
  assert.match(big.stderr, /output over 1000 bytes/);
  const none = await run("sdd-server-no-such-program", [], { env, timeoutMs: 1000, maxBytes: 1000 });
  assert.equal(none.code, 127);
  const failed = await run("sh", ["-c", "echo oops >&2; exit 3"], { env, timeoutMs: 1000, maxBytes: 1000 });
  assert.deepEqual(failed, { code: 3, stdout: "", stderr: "oops\n" });
});

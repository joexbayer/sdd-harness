#!/usr/bin/env node
// sdd-server: serve | token | check | health | version. The one module that wires the others.
import { existsSync, readFileSync } from "node:fs";
import { mkdir } from "node:fs/promises";
import { dirname, join } from "node:path";
import { tokenLines } from "./auth.ts";
import { ConfigError, loadConfig } from "./config.ts";
import { hostPort, listen } from "./http.ts";
import { now, poll, RepoIndex } from "./repo-index.ts";

const DEFAULT_CONFIG = "/etc/sdd-server/config";
const USAGE = `usage: sdd-server serve [--config <file>]
       sdd-server check [--config <file>] [--offline]
       sdd-server token <name>
       sdd-server health [--config <file>]
       sdd-server version
(the config defaults to ${DEFAULT_CONFIG})`;

function packageRoot(): string {
  let d = import.meta.dirname;
  while (!existsSync(join(d, "package.json"))) {
    if (dirname(d) === d) throw new Error("cannot find the sdd-server package folder");
    d = dirname(d);
  }
  return d;
}

// bundledSdd: the package's sdd/ (FR-53.33); in this repo, where nothing is packed, the repo's .sdd/.
export function bundledSdd(): string {
  const root = packageRoot();
  const own = join(root, "sdd");
  return existsSync(join(own, "bin", "sdd")) ? own : join(root, "..", ".sdd");
}

function die(msg: string, code: number): never {
  process.stderr.write(`sdd-server: ${msg}\n`);
  process.exit(code);
}

function configArg(args: string[]): string {
  if (args.length === 0) return DEFAULT_CONFIG;
  if (args.length === 2 && args[0] === "--config") return args[1];
  die(USAGE, 2);
}

const log = (line: Record<string, unknown>) => process.stdout.write(JSON.stringify(line) + "\n");

async function serve(path: string): Promise<void> {
  const cfg = await loadConfig(path);
  await mkdir(cfg.data, { recursive: true });
  const ix = new RepoIndex({ data: cfg.data, knownHosts: cfg.knownHosts, bundled: bundledSdd(), repos: cfg.repos });
  const server = listen(cfg, ix, log);
  server.on("error", (e) => die(e.message, 1));
  server.on("listening", () => log({ t: now(), listening: cfg.listen, repos: cfg.repos.length }));
  const polling = poll(ix, cfg.fetchInterval, log);
  // FR-53.19: stop taking requests, give those in flight up to 10 s, exit 0.
  const stop = () => {
    polling.stop();
    server.close(() => process.exit(0));
    server.closeIdleConnections();
    setTimeout(() => process.exit(0), 10_000).unref();
  };
  process.once("SIGTERM", stop);
  process.once("SIGINT", stop);
}

// health: GET /healthz on listen; exit 0 when it answers 200 (the container's healthcheck).
async function health(path: string): Promise<void> {
  const cfg = await loadConfig(path);
  let { host, port } = hostPort(cfg.listen);
  if (host === undefined || host === "0.0.0.0") host = "127.0.0.1";
  if (host === "::") host = "::1";
  const r = await fetch(`http://${host.includes(":") ? `[${host}]` : host}:${port}/healthz`, { signal: AbortSignal.timeout(5000) });
  process.stdout.write(`${await r.text()}\n`);
  process.exit(r.status === 200 ? 0 : 1);
}

// check (FR-53.18): the config, then every repo cloned or fetched and indexed once, one line each.
// --offline stops after the config.
async function check(args: string[]): Promise<void> {
  const offline = args.includes("--offline");
  const cfg = await loadConfig(configArg(args.filter((a) => a !== "--offline")));
  const n = (k: number, w: string) => `${k} ${w}${k === 1 ? "" : "s"}`;
  if (offline) {
    process.stdout.write(`config ok: ${n(cfg.repos.length, "repo")}, ${n(cfg.tokens.length, "token")}\n`);
    return;
  }
  await mkdir(cfg.data, { recursive: true });
  const ix = new RepoIndex({ data: cfg.data, knownHosts: cfg.knownHosts, bundled: bundledSdd(), repos: cfg.repos });
  let failed = 0;
  for (const r of cfg.repos) {
    await ix.rebuild(r);
    const s = ix.snapshot(r.name)!;
    if (!s.ok) failed++;
    process.stdout.write(s.ok ? `${r.name} ok ${n(s.rows.length, "item")}\n` : `${r.name} FAILED ${s.error}\n`);
  }
  process.exit(failed === 0 ? 0 : 1);
}

// version (FR-53.34): the server's version and the bundled sdd's.
function version(): string {
  const pkg = JSON.parse(readFileSync(join(packageRoot(), "package.json"), "utf8")) as { version: string };
  const sdd = readFileSync(join(bundledSdd(), "VERSION"), "utf8").split("\n")[0].trim();
  return `sdd-server ${pkg.version} · sdd ${sdd}\n`;
}

async function main(argv: string[]): Promise<void> {
  const [cmd, ...args] = argv;
  switch (cmd) {
    case "serve": return serve(configArg(args));
    case "health": return health(configArg(args));
    case "check": return check(args);
    case "version":
      if (args.length !== 0) die(USAGE, 2);
      process.stdout.write(version());
      return;
    case "token":
      if (args.length !== 1) die(USAGE, 2);
      process.stdout.write(tokenLines(args[0]));
      return;
    default: die(USAGE, 2);
  }
}

main(process.argv.slice(2)).catch((e: Error) => die(e.message, e instanceof ConfigError ? 2 : 1));

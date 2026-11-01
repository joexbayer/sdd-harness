// HTTP: /healthz (no token, no names) and /mcp behind the Host allowlist and a bearer token
// (D-53.12 to D-53.14). Stateless: one McpServer per request.
import http from "node:http";
import { createMcpHandler } from "@modelcontextprotocol/server";
import { hostHeaderValidation, toNodeHandler } from "@modelcontextprotocol/node";
import { verifyToken } from "./auth.ts";
import type { Config } from "./config.ts";
import { now, type RepoIndex } from "./repo-index.ts";
import { buildServer, type Log } from "./tools.ts";

// hostPort: server.listen as node's listen() takes it: ":8080", "127.0.0.1:8080", "[::1]:8080".
export function hostPort(listen: string): { host: string | undefined; port: number } {
  const i = listen.lastIndexOf(":");
  const host = listen.slice(0, i).replace(/^\[(.*)\]$/, "$1");
  return { host: host === "" ? undefined : host, port: Number(listen.slice(i + 1)) };
}

// failingRepos: repos with no index younger than three fetch intervals (FR-53.17).
export function failingRepos(cfg: Config, ix: RepoIndex): number {
  const fresh = Date.now() - 3 * cfg.fetchInterval * 1000;
  return ix.names().filter((n) => {
    const f = ix.snapshot(n)?.fetched ?? "";
    return f === "" || Date.parse(f) < fresh;
  }).length;
}

const bearerOf = (req: http.IncomingMessage) => /^Bearer (\S+)$/.exec(req.headers.authorization ?? "")?.[1] ?? "";

export function listen(cfg: Config, ix: RepoIndex, log: Log): http.Server {
  const mcp = createMcpHandler(() => buildServer(ix, log));
  const node = toNodeHandler(mcp);
  const hostOk = hostHeaderValidation([cfg.publicHost.toLowerCase(), "localhost", "127.0.0.1", "[::1]"]);
  const server = http.createServer((req, res) => {
    const path = (req.url ?? "").split("?")[0];
    if (path === "/healthz") {
      const failing = failingRepos(cfg, ix);
      res.writeHead(failing === 0 ? 200 : 503, { "Content-Type": "application/json" });
      res.end(JSON.stringify(failing === 0 ? { ok: true } : { ok: false, failing }));
      return;
    }
    if (!hostOk(req, res)) return; // 403, written by the SDK (FR-53.13)
    if (path !== "/mcp") {
      res.writeHead(404, { "Content-Type": "text/plain" }).end("not found\n");
      return;
    }
    const who = verifyToken(cfg, bearerOf(req));
    if (!who) {
      log({ t: now(), auth: "refused", addr: req.socket.remoteAddress ?? "" }); // FR-53.16: no token
      res.writeHead(401, { "WWW-Authenticate": "Bearer", "Content-Type": "text/plain" }).end("a valid bearer token is needed\n");
      return;
    }
    // The token itself is never kept: the tools see only its name.
    (req as http.IncomingMessage & { auth?: unknown }).auth = { token: "", clientId: who, scopes: [] };
    void node(req as never, res);
  });
  const { host, port } = hostPort(cfg.listen);
  server.listen(port, host);
  return server;
}

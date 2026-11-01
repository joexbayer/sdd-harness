// mcp: call a tool the way a client does, with JSON-RPC over the SDK's fetch handler (no socket).
import { createMcpHandler } from "@modelcontextprotocol/server";
import { buildServer, type Log } from "../src/tools.ts";
import type { RepoIndex } from "../src/repo-index.ts";

export interface ToolResult { isError: boolean; text: string; structured: any }

// rpcResult: the JSON-RPC message of a response, sent as JSON or as one SSE event.
export async function rpcResult(r: Response): Promise<any> {
  const body = await r.text();
  const data = body.split("\n").find((l) => l.startsWith("data: "));
  return JSON.parse(data ? data.slice(6) : body);
}

export function caller(ix: RepoIndex, log: Log = () => {}) {
  const h = createMcpHandler(() => buildServer(ix, log));
  let id = 0;
  return async (name: string, args: unknown, who = "kari"): Promise<ToolResult> => {
    const r = await h.fetch(new Request("http://localhost/mcp", {
      method: "POST",
      headers: { "content-type": "application/json", accept: "application/json, text/event-stream", "mcp-protocol-version": "2025-06-18" },
      body: JSON.stringify({ jsonrpc: "2.0", id: ++id, method: "tools/call", params: { name, arguments: args } }),
    }), { authInfo: { token: "", clientId: who, scopes: [] } });
    const m = await rpcResult(r);
    if (m.error) return { isError: true, text: m.error.message, structured: undefined };
    return { isError: m.result.isError === true, text: m.result.content.map((c: any) => c.text).join("\n"), structured: m.result.structuredContent };
  };
}

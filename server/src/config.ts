// The server's config file, in git-config format, read with `git config -f <file> --null --list`
// (D-53.6): git's own parser, with no include.path followed. Read once at start (D-53.15).
import { execFile } from "node:child_process";

export interface Repo { name: string; url: string; key: string }
export interface Token { name: string; sha256: string } // 64 lowercase hex
export interface Config {
  listen: string; // server.listen, default ":8080"
  publicHost: string; // server.public-host, required (FR-53.4, FR-53.13)
  data: string; // server.data, default "/data"
  knownHosts: string; // server.known-hosts
  fetchInterval: number; // server.fetch-interval in seconds, default 60
  repos: Repo[];
  tokens: Token[];
}

// FR-53.5: repo and token names become folder names and log fields.
export const NAME = /^[a-z0-9][a-z0-9-]{0,62}$/;
export const NAME_RULE = "[a-z0-9][a-z0-9-]{0,62}";

export class ConfigError extends Error {
  override name = "ConfigError";
}

const SERVER_KEYS = ["listen", "public-host", "data", "known-hosts", "fetch-interval"];

function gitList(path: string): Promise<string> {
  return new Promise((resolve, reject) => {
    execFile("git", ["config", "-f", path, "--null", "--list"],
      { env: { PATH: process.env.PATH ?? "/usr/bin:/bin", GIT_CONFIG_NOSYSTEM: "1" }, maxBuffer: 1 << 20 },
      (err, stdout, stderr) => err
        ? reject(new ConfigError(`cannot read ${path}: ${(stderr || err.message).trim().split("\n")[0]}`))
        : resolve(stdout));
  });
}

export async function loadConfig(path: string): Promise<Config> {
  const server = new Map<string, string>();
  const repos = new Map<string, Map<string, string>>();
  const tokens = new Map<string, Map<string, string>>();
  for (const entry of (await gitList(path)).split("\0")) {
    if (entry === "") continue;
    // "<section>.<subsection>.<key>\n<value>"; git lowercases section and key, not the subsection.
    const nl = entry.indexOf("\n");
    const full = nl < 0 ? entry : entry.slice(0, nl);
    const value = nl < 0 ? "" : entry.slice(nl + 1);
    const first = full.indexOf(".");
    const last = full.lastIndexOf(".");
    const section = full.slice(0, first);
    const key = full.slice(last + 1);
    const sub = first === last ? undefined : full.slice(first + 1, last);
    if (section === "server" && sub === undefined && SERVER_KEYS.includes(key)) {
      server.set(key, value);
    } else if (section === "repo" && sub !== undefined && (key === "url" || key === "key")) {
      if (!repos.has(sub)) repos.set(sub, new Map());
      repos.get(sub)!.set(key, value);
    } else if (section === "token" && sub !== undefined && key === "sha256") {
      if (!tokens.has(sub)) tokens.set(sub, new Map());
      tokens.get(sub)!.set(key, value);
    } else {
      throw new ConfigError(`unknown key ${full}`);
    }
  }

  const publicHost = server.get("public-host") ?? "";
  if (publicHost === "") throw new ConfigError("missing server.public-host");
  const interval = server.get("fetch-interval") ?? "60";
  if (!/^[1-9][0-9]{0,5}$/.test(interval)) {
    throw new ConfigError(`server.fetch-interval must be a whole number of seconds, not ${interval}`);
  }

  const out: Repo[] = [];
  for (const [name, kv] of repos) {
    if (!NAME.test(name)) throw new ConfigError(`repo "${name}": name must match ${NAME_RULE}`);
    for (const k of ["url", "key"]) {
      if (!kv.get(k)) throw new ConfigError(`repo "${name}": missing ${k}`);
    }
    out.push({ name, url: kv.get("url")!, key: kv.get("key")! });
  }

  const toks: Token[] = [];
  for (const [name, kv] of tokens) {
    if (!NAME.test(name)) throw new ConfigError(`token "${name}": name must match ${NAME_RULE}`);
    const sha256 = (kv.get("sha256") ?? "").toLowerCase();
    if (!/^[0-9a-f]{64}$/.test(sha256)) throw new ConfigError(`token "${name}": sha256 must be 64 hex characters`);
    const twin = toks.find((t) => t.sha256 === sha256);
    if (twin) throw new ConfigError(`token "${name}": same sha256 as token "${twin.name}"`);
    toks.push({ name, sha256 });
  }
  if (toks.length === 0) throw new ConfigError("no [token] configured: add one with sdd-server token <name>");

  return {
    listen: server.get("listen") || ":8080",
    publicHost,
    data: server.get("data") || "/data",
    knownHosts: server.get("known-hosts") ?? "",
    fetchInterval: Number(interval),
    repos: out,
    tokens: toks,
  };
}

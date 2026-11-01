// Tokens: "sdd_" + 32 random bytes; the config holds only their SHA-256 (D-53.17).
import { createHash, randomBytes, timingSafeEqual } from "node:crypto";
import { ConfigError, NAME, NAME_RULE, type Config } from "./config.ts";

export function newToken(): { token: string; sha256: string } {
  const token = "sdd_" + randomBytes(32).toString("base64url");
  return { token, sha256: createHash("sha256").update(token).digest("hex") };
}

// verifyToken: the name of the token whose hash matches, compared with timingSafeEqual (FR-53.12).
export function verifyToken(cfg: Config, bearer: string): string | undefined {
  if (bearer === "") return undefined;
  const h = createHash("sha256").update(bearer).digest();
  let who: string | undefined;
  for (const t of cfg.tokens) {
    if (timingSafeEqual(h, Buffer.from(t.sha256, "hex")) && who === undefined) who = t.name;
  }
  return who;
}

// tokenLines: what `sdd-server token <name>` prints, once (FR-53.14). Nothing is written to disk.
export function tokenLines(name: string): string {
  if (!NAME.test(name)) throw new ConfigError(`token "${name}": name must match ${NAME_RULE}`);
  const t = newToken();
  return `token: ${t.token}\n[token "${name}"]\n\tsha256 = ${t.sha256}\n`;
}

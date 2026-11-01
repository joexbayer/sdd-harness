// The bundled sdd (FR-53.8): one home per repo with the package's bin/, core/ and VERSION and the
// repo's .sdd/config as data (D-53.10), run with /bin/sh and an argv, never a file of the repo.
import { cp, mkdir, readFile, rm, writeFile } from "node:fs/promises";
import { join } from "node:path";
import { errorLine, run } from "./run.ts";
import { gitEnv } from "./mirror.ts";

const SDD_MS = 60_000;
const SDD_CAP = 32 << 20;
const fresh = new Set<string>();

// sddHome: <data>/homes/<repo>/.sdd. Named .sdd like a vendored copy, so the commands sdd's reasons
// name read `.sdd/bin/sdd`. The copy is made once per process; the config is rewritten when it changes.
export async function sddHome(data: string, repo: string, bundled: string, projectConfig: string): Promise<string> {
  const home = join(data, "homes", repo, ".sdd");
  if (!fresh.has(home)) {
    await rm(home, { recursive: true, force: true });
    await mkdir(home, { recursive: true });
    await cp(join(bundled, "bin"), join(home, "bin"), { recursive: true });
    await cp(join(bundled, "core"), join(home, "core"), { recursive: true });
    await cp(join(bundled, "VERSION"), join(home, "VERSION"));
    fresh.add(home);
  }
  const cfg = join(home, "config");
  const now = await readFile(cfg, "utf8").catch(() => undefined);
  if (now !== projectConfig) await writeFile(cfg, projectConfig);
  return home;
}

// sddJson: run `sdd <args>` in the clone and parse its JSON lines.
export async function sddJson(home: string, clone: string, args: string[]): Promise<unknown[]> {
  const r = await run("/bin/sh", [join(home, "bin", "sdd"), ...args],
    { cwd: clone, env: gitEnv(), timeoutMs: SDD_MS, maxBytes: SDD_CAP });
  if (r.code !== 0) throw new Error(errorLine(r));
  return r.stdout.split("\n").filter((l) => l.trim() !== "").map((l) => JSON.parse(l) as unknown);
}

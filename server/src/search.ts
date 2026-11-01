// search (FR-53.30 to FR-53.32): one fixed-string `git grep` over specs/ per repo, on its open
// items' branches and its base branch, with a match limit and a time budget.
import { run } from "./run.ts";
import { gitEnv } from "./mirror.ts";
import type { RepoIndex } from "./repo-index.ts";

export interface Match { repo: string; ref: string; item: number | null; path: string; line: number; text: string }
export interface SearchOut { matches: Match[]; truncated: boolean }

const BUDGET_MS = 10_000;
const TEXT = 300;

export async function search(ix: RepoIndex, q: { query: string; repo?: string; limit?: number },
  budgetMs = BUDGET_MS): Promise<SearchOut> {
  const limit = q.limit ?? 50;
  const t0 = Date.now();
  const matches: Match[] = [];
  let truncated = false;
  for (const name of q.repo ? [q.repo] : [...ix.names()].sort()) {
    const s = ix.snapshot(name);
    if (!s || s.gen === 0) continue;
    // Item branches first (by id), then the base: a line on both is reported once, from the item.
    const refs: { git: string; ref: string; item: number | null }[] = s.rows
      .filter((r) => r.status === "open" && r.branch !== "" && (r.source === "remote" || r.source === "local"))
      .sort((a, b) => a.id - b.id)
      .map((r) => ({ git: r.source === "remote" ? `refs/remotes/${r.branch}` : `refs/heads/${r.branch}`, ref: r.branch, item: r.id }));
    refs.push({ git: `refs/heads/${s.base}`, ref: s.base, item: null });
    const left = budgetMs - (Date.now() - t0);
    if (left <= 0) { truncated = true; break; }
    const r = await run("git", ["grep", "-n", "-I", "-i", "-F", "-z", "--no-textconv", "-e", q.query,
      ...refs.map((x) => x.git), "--", "specs/"], { cwd: s.clone, env: gitEnv(), timeoutMs: left, maxBytes: 32 << 20 });
    // 1: no match. Anything else but 0 is a timeout or a cap: keep what came, and say so.
    if (r.code !== 0 && r.code !== 1) truncated = true;
    const seen = new Set<string>();
    const lines = r.stdout.split("\n");
    if (r.code !== 0) lines.pop(); // a run cut short may end mid-line
    for (const l of lines) {
      const [head, num, text] = l.split("\0");
      if (text === undefined) continue;
      const at = refs.find((x) => head.startsWith(`${x.git}:`));
      if (!at) continue;
      const path = head.slice(at.git.length + 1);
      const key = `${path}\0${num}\0${text}`;
      if (seen.has(key)) continue;
      seen.add(key);
      if (matches.length === limit) { truncated = true; break; }
      matches.push({ repo: name, ref: at.ref, item: at.item, path, line: Number(num), text: text.slice(0, TEXT) });
    }
    if (matches.length === limit && truncated) break;
  }
  return { matches, truncated };
}

// RepoIndex: per repo, the rows of the bundled sdd's `ls --json --all` over its clone, held in
// memory and swapped whole (FR-53.9); a failure keeps the last good rows (FR-53.10). Nothing is
// stored: a restart rebuilds it from git (C-2).
import { join } from "node:path";
import type { Repo } from "./config.ts";
import { baseBranch, ensureClone, fetchRepo, git, projectConfig } from "./mirror.ts";
import { sddHome, sddJson } from "./sdd.ts";

export type Row = Record<string, unknown> & { id: number; status: string; branch: string; source: string };
export interface Snapshot { repo: string; base: string; ok: boolean; error: string; fetched: string;
  gen: number; sdd: string; rows: Row[]; home: string; clone: string }

const MARKDOWN_CAP = 256 * 1024;
export const now = () => new Date().toISOString().replace(/\.\d{3}Z$/, "Z");

export class RepoIndex {
  readonly data: string;
  readonly knownHosts: string;
  readonly bundled: string;
  readonly repos: Repo[];
  private snaps = new Map<string, Snapshot>();
  private busy = new Map<string, Promise<void>>();
  private shows = new Map<string, Record<string, unknown>>();
  private gen = 0;

  constructor(o: { data: string; knownHosts: string; bundled: string; repos: Repo[] }) {
    this.data = o.data;
    this.knownHosts = o.knownHosts;
    this.bundled = o.bundled;
    this.repos = o.repos;
  }

  names(): string[] {
    return this.repos.map((r) => r.name);
  }

  snapshot(name: string): Snapshot | undefined {
    return this.snaps.get(name);
  }

  // rebuild: clone if needed, fetch, and when a ref moved (or nothing is indexed yet) index again;
  // one run per repo at a time (a second call joins the running one).
  rebuild(repo: Repo): Promise<void> {
    const running = this.busy.get(repo.name);
    if (running) return running;
    const p = this.refresh(repo).finally(() => this.busy.delete(repo.name));
    this.busy.set(repo.name, p);
    return p;
  }

  private async refresh(repo: Repo): Promise<void> {
    const clone = join(this.data, "repos", repo.name);
    const last = this.snaps.get(repo.name);
    try {
      await ensureClone(repo, clone, this.knownHosts);
      const { changed } = await fetchRepo(repo, clone, this.knownHosts);
      const fetched = now();
      if (!changed && last && last.gen > 0 && last.ok) {
        this.snaps.set(repo.name, { ...last, fetched });
        return;
      }
      const base = await baseBranch(clone);
      const home = await sddHome(this.data, repo.name, this.bundled, await projectConfig(clone, base));
      const rows = (await sddJson(home, clone, ["ls", "--json", "--all"])) as Row[];
      this.swap({ repo: repo.name, base, ok: true, error: "", fetched, gen: ++this.gen, sdd: "", rows, home, clone });
    } catch (e) {
      const error = (e as Error).message;
      this.snaps.set(repo.name, last && last.gen > 0
        ? { ...last, ok: false, error }
        : { repo: repo.name, base: "", ok: false, error, fetched: "", gen: 0, sdd: "", rows: [], home: "", clone });
    }
  }

  private swap(s: Snapshot): void {
    this.snaps.set(s.repo, s);
    for (const k of this.shows.keys()) if (k.startsWith(`${s.repo}\0`)) this.shows.delete(k);
  }

  // show: `sdd show <id> --json` for an item of the index, cached per index generation (FR-53.23);
  // with raw, the item file at the ref the index read it from (FR-53.24).
  async show(name: string, id: number, raw: boolean): Promise<Record<string, unknown>> {
    const s = this.snaps.get(name);
    if (!s || !this.repos.some((r) => r.name === name)) throw new Error(`no repo ${name} (repos: ${this.names().join(", ")})`);
    const row = s.rows.find((r) => r.id === id);
    if (!row) throw new Error(`no item ${id} in ${name} (repos: ${this.names().join(", ")})`);
    const key = `${name}\0${s.gen}\0${id}`;
    let shown = this.shows.get(key);
    if (!shown) {
      shown = (await sddJson(s.home, s.clone, ["show", String(id), "--json"]))[0] as Record<string, unknown>;
      this.shows.set(key, shown);
    }
    const out: Record<string, unknown> = { repo: name, ...shown };
    if (raw) Object.assign(out, await this.markdown(s, row));
    return out;
  }

  private async markdown(s: Snapshot, row: Row): Promise<{ markdown: string; markdown_truncated: boolean }> {
    const ref = row.source === "archive" || row.source === "base" || row.branch === "" ? `refs/heads/${s.base}`
      : row.source === "remote" ? `refs/remotes/${row.branch}` : `refs/heads/${row.branch}`;
    const ls = await git(s.clone, ["ls-tree", "-r", "--name-only", ref, "--", "specs/changes", "specs/archive"]);
    const re = new RegExp(`^specs/(changes|archive)/${row.id}-[^/]*/item\\.md$`);
    const path = ls.stdout.split("\n").find((p) => re.test(p));
    if (!path) throw new Error(`item ${row.id} has no file on ${ref}`);
    const r = await git(s.clone, ["show", `${ref}:${path}`]);
    if (r.code !== 0) throw new Error(`could not read ${path} on ${ref}`);
    const bytes = Buffer.from(r.stdout);
    return bytes.length > MARKDOWN_CAP
      ? { markdown: bytes.subarray(0, MARKDOWN_CAP).toString(), markdown_truncated: true }
      : { markdown: r.stdout, markdown_truncated: false };
  }
}

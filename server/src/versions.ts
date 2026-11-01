// sdd versions per branch (FR-53.28, FR-53.29): .sdd/VERSION read as text, never run.
import { git } from "./mirror.ts";

export type VsBase = "same" | "behind" | "ahead";

// A branch as sdd names it: origin/<b> is a remote-tracking branch, anything else a local one.
const refOf = (b: string) => (b.startsWith("origin/") ? `refs/remotes/${b}` : `refs/heads/${b}`);

async function version(clone: string, ref: string): Promise<string> {
  const r = await git(clone, ["show", `${ref}:.sdd/VERSION`]);
  return r.code === 0 ? r.stdout.split("\n")[0].trim() : "";
}

// branchVersions: the base's version, and per branch its version and how it stands: behind when
// the base's last commit to .sdd/VERSION is not in the branch, ahead when it is (the branch
// changed sdd itself), same when the texts match.
export async function branchVersions(clone: string, base: string, branches: string[]):
  Promise<{ base: string; branches: Record<string, { sdd: string; vs: VsBase }> }> {
  const baseRef = `refs/heads/${base}`;
  const baseV = await version(clone, baseRef);
  const last = (await git(clone, ["log", "-1", "--format=%H", baseRef, "--", ".sdd/VERSION"])).stdout.trim();
  const out: Record<string, { sdd: string; vs: VsBase }> = {};
  for (const b of branches) {
    const ref = refOf(b);
    const sdd = await version(clone, ref);
    let vs: VsBase = "same";
    if (sdd !== baseV) {
      vs = last === "" || (await git(clone, ["merge-base", "--is-ancestor", last, ref])).code === 0 ? "ahead" : "behind";
    }
    out[b] = { sdd, vs };
  }
  return { base: baseV, branches: out };
}

---
id: 63
type: fix
title: sdd-server: search and fetch survive real repo changes
status: open
created: 2026-11-08
approved: 93545e30ba06bfdb0bc670f9d5418ec2a5cb80a2 2026-11-08 joexbayer
---
# 63 sdd-server: search and fetch survive real repo changes

## Current behaviour
A state-machine hunt (2026-11-08) reproduced five bugs on local fixtures:
1. A deleted branch: the index still lists it, `git grep` exits 128 on the missing ref, so `search` returns nothing for that repo, base included, until the next index.
2. A repo not indexed yet, or failing, is skipped silently: `search` reports no matches, a false "no overlap". `item` says "no repo api".
3. `ensureClone` only checks `.git` exists, and fetch uses the stored origin: a changed `repo.url` keeps serving the old repo, health green.
4. `origin/HEAD` is set only at clone (git before 2.48): a renamed default branch leaves it dangling, base falls back to main, `update-ref` is skipped, and a frozen base is served as healthy.
5. A fetch killed during a ref update leaves `*.lock` behind; every later fetch fails until someone deletes it.

## Expected behaviour
FR-63.1 WHEN a ref in the index no longer exists in the clone THE SYSTEM SHALL search the refs that do.
  e.g. item 6's branch is pruned → main's matches are returned, `truncated: false`
FR-63.2 WHEN a repo has no usable index THE SYSTEM SHALL say so in `search`: `skipped: [{repo, reason}]` and a text line.
  e.g. `web` never cloned → `skipped: [{"repo":"web","reason":"…"}]`, text `not searched: web (…)`
FR-63.3 WHEN `item` names a configured repo with no index yet THE SYSTEM SHALL say so.
  e.g. → `repo web is not indexed yet: <error>`, not "no repo web"
FR-63.4 WHEN a repo's `url` in the config differs from the clone's origin THE SYSTEM SHALL fetch from the configured url.
  e.g. url changed to B → the next index serves B's items
FR-63.5 WHEN `origin/HEAD` is missing or dangling THE SYSTEM SHALL refresh it from the remote; WHEN the base branch is not on origin it SHALL fail that repo's index with the reason.
  e.g. main renamed to trunk → base becomes trunk; a base gone from origin → `ok:false`, `base branch main is not on origin`
FR-63.6 WHEN a ref lock file under the clone is older than the fetch timeout THE SYSTEM SHALL remove it before fetching.
  e.g. a leftover `refs/remotes/origin/x.lock` 2 minutes old → the fetch succeeds; a fresh lock is left alone

How: `server/src/search.ts`: `for-each-ref` for the repo's refs, keep only existing ones; collect `skipped`; `SearchOut` in `tools.ts` gains it.
`repo-index.ts` `show`: the "not indexed yet" branch when `!s || s.gen === 0`. `mirror.ts` `fetchRepo`: first remove stale locks (fs walk of `.git/refs` plus
`.git/packed-refs.lock`, mtime older than `FETCH_MS`), then `remote set-url origin <url>`; after the fetch, `rev-parse origin/HEAD` and on failure `remote set-head origin --auto` (ssh env); then throw if `origin/<base>` is missing.
Size: refs per repo stay in the hundreds, and one `for-each-ref` per search is cheap; no cache.
D-63.1 `skipped` beside `truncated`, not `truncated: true`: it says which repo and why.
D-63.2 Age guard on locks, not a blanket delete: `busy` makes the server the only fetcher, but a background gc may hold one.

## Must not change
- A repo with no `.sdd/` still reports "not an sdd repo"; keep-last-good on failure; `refs/heads/<base>` updated as today.

## Security
`repo.url` comes from the operator's config and is one argv entry, never a shell string. Lock removal stays under the clone's `.git` and skips symlinks. No new dependency.

## Test
`server/test/search.test.ts` (FR-63.1, 63.2), `index.test.ts` (FR-63.3), `mirror.test.ts` (FR-63.4 to 63.6: a changed url serves the new repo; origin/HEAD removed by hand is refreshed after a rename; a base gone from origin fails with the reason; a 2-minute-old lock is removed, a fresh one kept). Each written first and seen to fail.

## Built
- FR-63.1: `server/src/search.ts:31-34` lists existing refs (`for-each-ref`) and drops indexed refs that are gone. Test: `search.test.ts` "FR-63.1 search skips an indexed ref...".
- FR-63.2: `search.ts:19,22` collects `skipped`; `tools.ts:21-22` (schema), `:196` (one `not searched: <repo> (<reason>)` line per repo). Test: `search.test.ts` "FR-63.2 ..." (failed and never-indexed repo, structured and text).
- FR-63.3: `repo-index.ts:98` `show` says `repo X is not indexed yet: <error>`; "no repo" kept for unconfigured names. Test: `index.test.ts` "FR-63.3 ...".
- FR-63.4: `mirror.ts:72` `remote set-url origin <url>` before fetch. Test: `mirror.test.ts` "FR-63.4 ...".
- FR-63.5: `mirror.ts:77-85` `rev-parse origin/HEAD`, else `remote set-head origin --auto`; throws `base branch X is not on origin` (the old silent skip of update-ref is gone). Tests: "FR-63.5 ..." x2 (rename to trunk with followRemoteHEAD=never; base gone).
- FR-63.6: `mirror.ts:58-66` `removeStaleLocks` (regular files only, under `.git/refs` plus `packed-refs.lock`, older than FETCH_MS), called first in `fetchRepo`. Test: "FR-63.6 ..." (fresh lock kept and fetch fails, backdated 2 min lock removed).
- Deviations: `search` also skips a repo (reason `base branch X is missing in the clone`) when even the base ref is gone; the rename test sets `sdd.base = trunk` on the new branch, since base comes from origin/HEAD's config. Existing search tests' `deepEqual` gained `skipped: []`.
- Follow-ups: none.

Verified by:

## Review (optional)
<!-- The human's review notes: what to change, one per line. The agent works through them
and says under "## Built" what it changed for each. -->

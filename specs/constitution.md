# Constitution

The ground truths of sdd. Each article is enforced: by a command inside `sdd check`, or by
the human at every review. They change only through `sdd new amendment "…"`.

C-1 The core needs only POSIX sh, git and awk; jq only where agent hook JSON is unavoidable.
  Why: sdd must run wherever an agent has a shell, with nothing to install.
  Enforced: check sh tests/constitution/c1-deps.sh

C-2 Item state is derived from files and git, never stored; the only stored state is status.
  Why: stored state drifts (Spec Kit's stale feature.json sent work to the wrong spec).
  Enforced: review

C-3 IDs never change and are never reused; gaps are fine.
  Why: every reference (tests, commits, other items) depends on them staying put.
  Enforced: review

C-4 Only new, approve and ship create commits, and no verb pushes.
  Why: the human decides what lands and what leaves the machine.
  Enforced: check sh tests/constitution/c4-commits.sh

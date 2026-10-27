Item {{id}} is shipped into a pull request and waits to merge. On this branch its file is now
in the archive folder.

- Do not change code unless the human asks. If review comments need changes, make them on this
  branch, run `{{cmd}} check`, and say what changed; the human ships again to push them.
- Merging is the human's: they run `{{cmd}} ship` again once CI passes, and it merges the PR.
- `{{cmd}} status` shows the PR, its review and its CI.

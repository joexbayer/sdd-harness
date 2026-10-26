# sdd

Spec-driven changes for people working with coding agents. One short file per change,
plain shell scripts, and any agent. It is simple by default; rigour is there if you want it.

```
$ .sdd/bin/sdd new fix "Pagination drops last item"
1 fix · Pagination drops last item
branch  fix/1-pagination-drops-last-item
item    specs/changes/1-pagination-drops-last-item/item.md
next    fill in the item, then: .sdd/bin/sdd next
$ .sdd/bin/sdd check        # your tests; "0 tests ran" counts as a failure
$ .sdd/bin/sdd ship         # gates → archive the item → fast-forward main locally
```

## Install into a repo

```sh
/path/to/swe-harness/.sdd/bin/sdd init    # vendors .sdd/, writes .sdd/config, adds an AGENTS.md block
.sdd/bin/sdd sync claude                  # optional: hooks for your agent (claude, codex), never committed
```

Requirements: POSIX `sh`, `git` ≥ 2.31, awk, grep and sed. `jq` is needed only for `sync`
and the hooks. Windows works through WSL or Git Bash.

## What you get

| | |
|---|---|
| types | hotfix, fix, chore, refactor, spike, feature. Each has its own template and gates |
| phases | describe → build → ship, computed from the item and the last check, never stored |
| profiles | `lite` (default), `standard`, `strict` in `.sdd/config` decide how hard the gates are |
| any agent | agents read the AGENTS.md block and run `.sdd/bin/sdd next`; hooks are optional |
| customise | put a file at the same path under `.sdd/local/` to override core, or add `<prompt>.append.md` |

The design, the roadmap (standard, team with an MCP server, knowledge, strict) and the
reasons behind each choice are in [specs/design.md](specs/design.md). The research behind
them is in [specs/kb/](specs/kb/).

## Develop

```sh
sh tests/run.sh && dash tests/run.sh dash        # the suite under both shells
.sdd/bin/sdd check                               # shellcheck + both suites (this repo uses sdd)
```

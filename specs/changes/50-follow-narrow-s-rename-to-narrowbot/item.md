---
id: 50
type: refactor
title: Follow narrow's rename to NarrowBot
status: open
created: 2026-11-01
approved: 61d8812298aabb1a95f5117c625a085b80c21c12 2026-11-01 joexbayer
---
# 50 Follow narrow's rename to NarrowBot

## Goal
narrow is now NarrowBot (2026-11-01, repo joexbayer/narrowbot): the binary is `narrowbot`, its
config folder `~/.config/narrowbot`, and every `NARROW_*` variable is `NARROWBOT_*` with no
fallback. sdd follows, with no alias (no backward compatibility):
- `.sdd/core/agents/narrow.sh` becomes `.sdd/core/agents/narrowbot.sh`, so `agent = narrowbot`
  finds the `narrowbot` binary by default (`agent.<name>.bin`, `.sdd/core/cmd/run.sh:27`); its
  messages say narrowbot. `.sdd/core/cmd/run.sh:23` lists `<claude|narrowbot>`.
- The experiment: `experiment/narrow/` becomes `experiment/narrowbot/`; `experiment/run.sh` uses the
  `narrowbot` binary, `EXPERIMENT_NARROWBOT_BIN` and `NARROWBOT_CONFIG_DIR` (with the old name the
  experiment's gateway config would be silently ignored and the developer's own config used);
  the fake on PATH for `--dry` is named `narrowbot`.
- Tests (`tests/t_run.sh`, `t_agent_usage.sh`, `t_batch.sh`, `t_roles.sh`, `t_role_guard.sh`,
  `t_build_loop.sh`, `t_usage.sh`, `t_summary.sh`), `experiment/fake/fake_agent.py`,
  `experiment/README.md`, `README.md`, `specs/design.md` and `.claude/skills/sdd-dev/SKILL.md`
  follow: the agent, binary and variable names.

D-50.1 `specs/archive/` and `specs/kb/` keep "narrow": they record what was true then.
D-50.2 NarrowBot's own names (`.git/sdd/narrow-pending-green`, `narrow-sdd.sh`) are not sdd's: sdd
reads neither, so nothing changes here (narrow told).
D-50.3 Prose that means the project in the past (e.g. "the narrow pilot", the 2026-10-30 runs) may
stay; names a user types or a program reads change.

## Invariants
- `sdd run` with a tier whose agent is `narrowbot` behaves exactly as with `narrow` before:
  same args (`-C <root> -m <model> --json <args> -p <prompt>`), usage from the `finish` event, exit
  3 as "could not verify" (the renamed tests in `tests/t_run.sh`, `t_agent_usage.sh` pass).
- `sh experiment/run.sh A --dry` and `C --dry` still run end to end on the fakes.
- `sdd check` passes; nothing outside the named files changes.

## Built
- Adapter: `git mv .sdd/core/agents/narrow.sh .sdd/core/agents/narrowbot.sh`, its messages say
  narrowbot; `.sdd/core/cmd/run.sh:23` lists `<claude|narrowbot>`.
- Experiment: `experiment/narrow/` → `experiment/narrowbot/`; `experiment/run.sh` uses
  `narrowbot_bin` (from `EXPERIMENT_NARROWBOT_BIN`, else `narrowbot` on PATH), `NARROWBOT_CONFIG_DIR`
  (`<run>/narrowbot-config`), `tier.xp-builder.agent narrowbot`, `agent.narrowbot.bin`; the `--dry`
  fakes include `narrowbot`; `experiment/fake/fake_agent.py` dispatches on `narrowbot`;
  `provider.lisp` reads the key from `~/.config/narrowbot/api.key`.
- Deviation: dropped the old fallback to the newest `~/narrowbot-bench/bin/narrow-*` build (those are
  pre-rename builds named `narrow-<version>`); the binary now comes from `EXPERIMENT_NARROWBOT_BIN`
  or PATH.
- Tests: agent, stub binary and `NARROWBOT_DO`/`NARROWBOT_RC` names in t_run, t_agent_usage,
  t_batch, t_build_loop, t_role_guard, t_roles, t_usage (log rows too). `t_summary.sh` "Narrow
  terminals" means width and stays.
- Docs: README, specs/design.md, experiment/README.md, `.claude/skills/sdd-dev/SKILL.md`; kept:
  `specs/kb/narrow-lessons.md` links, `~/narrowbot-bench/narrow-sdd.sh` (NarrowBot's own name).
- Invariants: the renamed tests pass under sh and dash; `sh experiment/run.sh A --dry` and
  `C --dry` ran to the end with the narrowbot builder; your own sdd config and this clone's had
  no narrow agent to change.
- Check: `sdd check` passed (132 s).
- Security pass (the fresh verifier, Sonnet, read the diff for it): no findings. It found no
  leftover name a user types or a program reads, and confirmed the experiment sets
  `NARROWBOT_CONFIG_DIR`, so NarrowBot reads the experiment's config, not the developer's.
Verified by: claude-sonnet-5-5: 3 of 3 invariants proven; no findings

## Review (optional)
<!-- The human's review notes: what to change, one per line. The agent works through them
and says under "## Built" what it changed for each. -->

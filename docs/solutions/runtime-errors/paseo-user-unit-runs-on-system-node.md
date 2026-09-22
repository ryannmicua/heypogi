---
title: "Paseo systemd user unit silently runs on system node via unexpanded $HOME in PATH"
date: 2026-09-06
category: runtime-errors
module: "tooling/dev-stack (Paseo daemon lifecycle)"
problem_type: runtime_error
component: development_workflow
symptoms:
  - "`readlink /proc/<pid>/exe` for the Paseo daemon shows `/usr/bin/node` instead of the userspace node"
  - "`/proc/<pid>/environ` shows `PATH=$HOME/.local/bin:...` with a literal unexpanded `$HOME`"
  - "`systemctl --user show -p Environment` displays the correct PATH while the running process has a different one"
root_cause: config_error
resolution_type: config_change
severity: medium
related_components: [tooling, development_workflow]
tags: [paseo, systemd, user-unit, environmentfile, path, node, userspace, env-common]
---

# Paseo systemd user unit silently runs on system node via unexpanded $HOME in PATH

## Problem

After migrating Paseo to a systemd user unit (`~/.config/systemd/user/paseo.service` with `ExecStart=%h/.local/bin/paseo`), the daemon and its spawned workers ran under the wrong Node: `/usr/bin/node` instead of the userspace Node under `~/.nvm/...`. The root cause was a broken `PATH` inside the running process: `/proc/<pid>/environ` contained a literal, unexpanded `$HOME` in `PATH` (e.g. `PATH=$HOME/.local/bin:...`), sourced from `~/.config/heypogi/.env-common` via `EnvironmentFile=`.

Because the paseo binary's shebang is `#!/usr/bin/env -S node --disable-warning=DEP0040`, `env` resolved `node` through that broken `PATH`, fell through to the system copy at `/usr/bin/node`, and spawned workers inherited it.

## Symptoms

- `readlink /proc/<pid>/exe` for the Paseo daemon showed `/usr/bin/node` instead of the expected `/home/rgm/.nvm/versions/node/v24.20.0/bin/node`.
- `/proc/<pid>/environ` showed `PATH=$HOME/.local/bin:...` with a literal unexpanded `$HOME`, traced to `~/.config/heypogi/.env-common`.
- `systemctl --user show -p Environment paseo.service` displayed the CORRECT expanded unit `PATH`, while the running process had the file's `PATH`. Per this session's observation, this divergence is evidence that `EnvironmentFile=` wins over `Environment=` regardless of ordering within the unit.

## What Didn't Work

1. **Placing `Environment=PATH=...` after the `EnvironmentFile=` lines in the unit.** The running process still carried the file's `PATH`. Per this session's observation, `EnvironmentFile=` overrides `Environment=` regardless of line order, so reordering alone cannot fix it.

2. **Fixing only `~/.config/heypogi/.env-common`'s `PATH` ordering to userspace-first.** The values still contained literal `$HOME` references. That ordering is correct for bash (which expands `$HOME`) but unusable to systemd, which per this session's observation performs no `$VAR` expansion when reading `EnvironmentFile=`, so the daemon's `PATH` stayed broken.

## Solution

Two-part fix, both in the working tree (uncommitted as of 2026-09-06; re-verify after commit):

**Part 1 - unit uses `%h` specifiers and forces `PATH` last as belt-and-braces.** `tooling/dev-stack/paseo.service:21-22` sets `WorkingDirectory=%h` and `ExecStart=%h/.local/node-bin/paseo daemon run` (the foreground subcommand; `daemon start` daemonizes and is unsuitable for `Type=simple`); `tooling/dev-stack/paseo.service:26-30` sets `HOME`/`PASEO_HOME` via `%h` and then loads the three env files; `tooling/dev-stack/paseo.service:36` forces `Environment=PATH=%h/.local/bin:%h/.local/node-bin:%h/.opencode/bin:/usr/bin:/bin` last, with the comment at `tooling/dev-stack/paseo.service:31-33` noting systemd expands `%h` but NOT `$HOME/~`.

**Part 2 - `setup-env.sh` renders `$HOME` to an absolute path at generation time.** `tooling/env/setup-env.sh:45-48` expands both `__REPO_ROOT__` and `$HOME` via `sed` when generating `~/.config/heypogi/.env-common`, with the comment explaining the generated file is sourced by bash AND read by systemd `EnvironmentFile=`, which per the in-tree comments performs no `$VAR` expansion. The template documents the same constraint at `tooling/env/env-common.template:10-12`, warning that `$HOME` is expanded at generation time because systemd performs no `$VAR` expansion.

## Why This Works

- The paseo entrypoint relies on `#!/usr/bin/env -S node`, so the only thing deciding which Node runs is `PATH` lookup at exec time. A `PATH` containing a literal `$HOME` component never matches the userspace bin directories, so lookup falls through to `/usr/bin/node`.
- Rendering `$HOME` to an absolute path in the generated `.env-common` makes the `EnvironmentFile=`-supplied `PATH` valid for both consumers: bash (which would have expanded it anyway) and systemd (which, per this session's observation and the in-tree comments, does not expand it).
- Using `%h` in the unit is the only portable way to reference the home directory there, since, per this session's observation (and the unit comment at `tooling/dev-stack/paseo.service:31-33`), systemd expands `%h` but not `$HOME`/`~`. The unit's trailing forced `PATH` is defense-in-depth so the daemon gets a sane userspace-first `PATH` even if the env files regress.
- Verified after restart: `readlink /proc/<pid>/exe` showed `/home/rgm/.nvm/versions/node/v24.20.0/bin/node` and the daemon answered health 200 on `:6767`.

## Prevention

- Never put `$HOME`, `$VAR`, or `~` references in any file consumed via systemd `EnvironmentFile=`; per this session's observation systemd performs no such expansion. Keep the generator-side expansion in `tooling/env/setup-env.sh:48` and the warning comment in `tooling/env/env-common.template:10-12` in sync.
- Keep unit paths on `%h` specifiers (e.g. `tooling/dev-stack/paseo.service:21`, `tooling/dev-stack/paseo.service:26`, `tooling/dev-stack/paseo.service:36`) and never switch them to `$HOME` form.
- After any env-file or unit change, verify the running process, not just the unit definition: compare `systemctl --user show -p Environment` against `/proc/<pid>/environ` and `readlink /proc/<pid>/exe`, since, per this session's observation above, the two can diverge when `EnvironmentFile=` overrides `Environment=`.

## Related

- Adjacent, same theme, different bug: `docs/solutions/runtime-errors/paseo-daemon-inherits-opencode-server-password.md` (process-env inheritance vs unit-file semantics).

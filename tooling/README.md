# Dev Stack Setup — OpenCode, OpenChamber, Paseo

Scripts in `tooling/` follow the repository's [general script standard](../docs/standards/scripts.md). Bash scripts additionally follow the [Bash script standard](../docs/standards/bash-scripts.md).
Contract details live in the `script-contract` + `bash-script-contract`
skills (`src/skills/`).

## Linux: bootstrap delegation (2026-09-07)

`bootstrap/bootstrap.sh` is a thin orchestrator: arg parsing, env-first
ordering, `--skip-*` mapping, `--user` target context, run-history
markers, and `status` aggregation. All install logic lives here, in
`tooling/`, one owner per state:

| Domain | Owner scripts | Owns |
|--------|---------------|------|
| `env/` | `setup-env.sh` (+ `require-env.sh` sourced guard) | `~/.config/heypogi/.env-{common,override,secrets}`, `.bashrc` marker block; every dependent gates on the guard before mutating |
| `machine/` | `check-prereqs.sh`, `install-{claude,codex,gh}-cli.sh` | System checks (node/npm/curl/git/docker/uv/AVX) + CLI installers; narrow sudo for apt only |
| `sources/` | `clone-*.sh` via `update-external-repos.sh` | `external/` checkouts, acquired before skills; failures propagate |
| `skills/` | `install-{skills,ce-skills,knowledge-skills}.sh` | `~/.agents/skills/*` symlinks (correct link = no-op; conflicting dirs never removed) |
| `bin/` | `userspace-shims.sh` (+ PATH entry points) | `~/.local/bin`, `~/.local/node-bin`, npm prefix, CLI shims the rootless unit needs |
| `dev-stack/` | `dev-stack.sh` (+ `paseo.service` user-unit template) | Paseo config seed (additive, password-preserving merge), rootless user unit, legacy system-unit migration, linger ownership, fail-closed bind, `~/.config/heypogi/.env-paseo` secrets allowlist |

Every bootstrap-callable script supports `status` (default, read-only) /
`install` with `-f`/`-q`/`--dry-run` and exits 0 converged, 1 drift/failed,
2 usage error, 3 blocked. `--dry-run` writes nothing (no marker, logs,
or child mutations). Paseo binds `0.0.0.0` only with `PASEO_PASSWORD` set.

## Windows setup (dev-stack.ps1)

This machine runs three always-on developer tools as **npm CLIs** (no desktop
apps as servers):

| Tool | Role | Port | Autostart |
|------|------|------|-----------|
| **OpenCode** | CLI / agent runtime (also the OpenChamber sidecar) | — (sidecar on 49180) | — |
| **OpenChamber** | Web UI server (with OpenCode sidecar) | `0.0.0.0:7777` | HKCU `Run` key |
| **Paseo** | Headless agent daemon + web UI | `0.0.0.0:6767` | Scheduled task `PaseoDaemon` |

The intended state, verified by `dev-stack.ps1`:

- All three **up to date** (checked against the npm registry).
- **CLI installs only** — the listening processes must be the npm binaries
  (`cli.js`, `daemon-worker.js`), not desktop apps.
- **Listening on all interfaces** (`0.0.0.0`) so OpenChamber and Paseo are
  reachable remotely.
- **Autostart at login** for OpenChamber and Paseo.
- **One Paseo daemon** — the headless CLI one. The optional Paseo desktop app
  connects to it as a client with "Manage built-in daemon" disabled.
- **One OpenChamber server** — the headless CLI one. The optional OpenChamber
  desktop app connects to it as a client with `OPENCHAMBER_SKIP_LOCAL_SERVER=1`
  and the CLI server added to its host list.

## Setup order

```powershell
# 1. Prerequisite: Node.js (https://nodejs.org) - required by npm

# 2. One command: installs all three tools + configures autostarts + verifies
tooling/dev-stack/dev-stack.ps1 install

# 3. Manual: set the two UI passwords (interactive, cannot be automated;
#    the script prints reminders when they are missing)
paseo daemon set-password
[Environment]::SetEnvironmentVariable("OPENCHAMBER_UI_PASSWORD", "yourpassword", "User")

# 4. Optional manual: Paseo desktop app as a client only
#    - install from https://paseo.sh/download
#    - disable "Manage built-in daemon" (Settings -> Daemon)
#      -> persists as "manageBuiltInDaemon": false in
#         %APPDATA%\Paseo\desktop-settings.json

# 4b. Optional manual: OpenChamber desktop app as a client only
#    - set OPENCHAMBER_SKIP_LOCAL_SERVER=1 (user env var)
#    - add http://localhost:7777 to the desktop app's host list

# 5. Confirm everything is as intended
tooling/dev-stack/dev-stack.ps1 status
```

## Supervisor — `tooling/dev-stack/dev-stack.ps1`

One entry point for the whole stack. Full reference:
[`dev-stack.md`](stack/dev-stack.md).

| Command | Role |
|---------|------|
| `install` (alias `update`) | Explicit setup: install/update the three tools, restart daemons, ensure autostart + config, then verify. Idempotent. |
| `status` (default) | Read-only check of the intended state. Exit 0 = all good, 1 = issues, 2 = cannot verify (npm offline). |
| `fix` | Repair stopped daemons, autostart registrations, and `0.0.0.0`/web UI config. |
| `start` / `stop` | Control both daemons. Accepts `-App <tool>` to target just one. |
| `startup <verb>` | Manage autostart-at-login registration only (package stays installed). |
| `uninstall -App <tool>` | Full teardown per tool: stop, remove autostart, `npm uninstall -g` the package. Keeps config unless `-WipeConfig`. |

`status`/`start`/`stop`/`uninstall` delegate per-tool work to
`opencode-ctl.ps1` / `openchamber-ctl.ps1` / `paseo-ctl.ps1`, each of which
also works standalone (install/status/uninstall, plus start/stop for the two
daemon-backed tools).

Every check it performs, plus autostart/health details:
[`dev-stack.md`](stack/dev-stack.md).

## Config files

| File | Created by | Intended values |
|------|-----------|-----------------|
| `~/.config/github-app/app.conf` | Repo template `tooling/machine/github-app.app.conf.template` via `tooling/machine/github-app-identity.sh` | `GITHUB_APP_ID`, `GITHUB_APP_SLUG`, named `<installation>=<id>` entries (first = git default) — see [`machine/github-app-identity.md`](machine/github-app-identity.md) |
| `~/.config/openchamber/settings.json` | Repo template `tooling/dev-stack/openchamber.settings.json` via `openchamber-ctl.ps1 configure` (or the OpenChamber app itself) | `port: 7777`, `host: 0.0.0.0`, `autoStart: true` (defaults applied by the script when keys are absent) |
| `~/.paseo/config.json` | Paseo itself on first load (default is localhost-only) | `daemon.listen: "0.0.0.0:6767"`, `features.webUi.enabled: true`, `daemon.auth.password` (bcrypt) |
| `%APPDATA%\Paseo\desktop-settings.json` | Paseo desktop app | `settings.daemon.manageBuiltInDaemon: false` — **advisory only**, never modified by the scripts |
| `~/.config/openchamber/startup.ps1` + `launch.vbs` | `openchamber-ctl.ps1 configure` | Launch the OpenChamber server hidden at login (wrappers used by the Run key) |

Note: Paseo's own defaults are localhost-only with the web UI off — the
`0.0.0.0` + web UI + password on this machine come from the headless setup
steps, which is why `status` verifies them explicitly.

## Autostart mechanisms

- **OpenChamber**: HKCU `Run` key → `wscript launch.vbs` → `startup.ps1` →
  `node cli.js serve --foreground --port 7777 --host 0.0.0.0`.
  (Windows Task Scheduler's `schtasks.exe` truncates long commands — the Run
  key avoids that. Details: [`openchamber-startup-setup.md`](openchamber-startup-setup.md).)
- **Paseo**: scheduled task `PaseoDaemon` (logon trigger, runs
  `node ...\@getpaseo\cli\bin\paseo daemon start`).
  Details: [`paseo-headless-setup.md`](paseo-headless-setup.md).

## Layout — organized by domain

Each domain folder is self-contained: docs sit next to their scripts.
`bin/` holds PATH entry points (wired by `bootstrap/bootstrap.sh` and
`setup-environment.ps1`) that point into the domains, plus
`userspace-shims.sh` (userspace PATH provisioning for the Linux
rootless unit).

| Domain | Contents |
|--------|----------|
| [`dev-stack/`](dev-stack/) | Always-on dev services (OpenCode, OpenChamber, Paseo): Linux supervisor `dev-stack.sh` + `paseo.service` user-unit template, Windows `dev-stack.ps1` + per-tool ctl scripts and docs, `openchamber.settings.json` template |
| [`machine/`](machine/) | Provisioning this box: Linux `check-prereqs.sh` + `install-{claude,codex,gh}-cli.sh`, PowerShell profile, GitHub App agent identity (`github-app-identity.sh`, token CLI, credential helper, config template) |
| [`env/`](env/) | heypogi env owner: `setup-env.sh`, `require-env.sh` sourced guard, templates |
| [`sources/`](sources/) | External reference repos: clone scripts, status/recording helpers |
| [`skills/`](skills/) | Installing skill collections into the agent environment |
| `bin/` | PATH entry points (`dev-stack`) + `userspace-shims.sh` + `symlink-nvm-node-bin.sh` |

## Related docs

### `stack/`

| Doc | Covers |
|-----|--------|
| [`stack/dev-stack.md`](stack/dev-stack.md) | Cross-tool supervisor commands, every status check, fresh-machine workflow |
| [`stack/opencode-ctl.md`](stack/opencode-ctl.md) | OpenCode CLI lifecycle script (install/status/uninstall) |
| [`stack/openchamber-startup-setup.md`](stack/openchamber-startup-setup.md) | OpenChamber lifecycle script (`openchamber-ctl.ps1`), settings, wrappers, OpenCode sidecar env vars |
| [`stack/paseo-ctl.md`](stack/paseo-ctl.md) | Paseo CLI/daemon lifecycle script (install/status/start/stop/uninstall) |
| [`stack/paseo-headless-setup.md`](stack/paseo-headless-setup.md) | Manual headless Paseo setup: listen address, password, scheduled task |

### `machine/`

| Doc | Covers |
|-----|--------|
| [`machine/setup-environment.md`](machine/setup-environment.md) | Sets `HEYPOGI_ROOT` / `OPENCODE_CONFIG_DIR`, writes PowerShell profiles |
| [`machine/install-codex-cli.md`](machine/install-codex-cli.md) | Installs/verifies Codex CLI and Linux Bubblewrap/AppArmor prerequisites |
| [`machine/github-app-identity.md`](machine/github-app-identity.md) | GitHub App as the agent GitHub/git identity: token CLI, credential helper, commit attribution |

### `sources/` and `skills/`

Doc–script pairs share filenames in those folders; each doc documents its own
script. Entry points: [`sources/clone-ce-source.md`](sources/clone-ce-source.md),
[`sources/clone-knowledge-source.md`](sources/clone-knowledge-source.md),
[`sources/clone-opencode-source.md`](sources/clone-opencode-source.md),
[`skills/install-skills.md`](skills/install-skills.md),
[`skills/install-ce-skills.md`](skills/install-ce-skills.md),
[`skills/install-knowledge-skills.md`](skills/install-knowledge-skills.md),
[`skills/install-opencode-learn.md`](skills/install-opencode-learn.md).

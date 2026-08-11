# Dev Stack Setup — OpenCode, OpenChamber, Paseo

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
install/scripts/dev-stack.ps1 install

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
install/scripts/dev-stack.ps1 status
```

## Supervisor — `install/scripts/dev-stack.ps1`

One entry point for the whole stack. Full reference:
[`dev-stack.md`](dev-stack.md).

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
[`dev-stack.md`](dev-stack.md).

## Config files

| File | Created by | Intended values |
|------|-----------|-----------------|
| `~/.config/openchamber/settings.json` | Repo template `install/openchamber.settings.json` via `openchamber-ctl.ps1 configure` (or the OpenChamber app itself) | `port: 7777`, `host: 0.0.0.0`, `autoStart: true` (defaults applied by the script when keys are absent) |
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

## Related docs in this folder

| Doc | Covers |
|-----|--------|
| [`dev-stack.md`](dev-stack.md) | Cross-tool supervisor commands, every status check, fresh-machine workflow |
| [`openchamber-startup-setup.md`](openchamber-startup-setup.md) | OpenChamber lifecycle script (`openchamber-ctl.ps1`), settings, wrappers, OpenCode sidecar env vars |
| [`opencode-ctl.md`](opencode-ctl.md) | OpenCode CLI lifecycle script (install/status/uninstall) |
| [`paseo-ctl.md`](paseo-ctl.md) | Paseo CLI/daemon lifecycle script (install/status/start/stop/uninstall) |
| [`paseo-headless-setup.md`](paseo-headless-setup.md) | Manual headless Paseo setup: listen address, password, scheduled task |

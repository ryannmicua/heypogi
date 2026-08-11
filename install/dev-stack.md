# Check / Supervise Dev Stack (OpenCode, OpenChamber, Paseo)

One script for the three always-on developer tools:

- **OpenCode** — CLI installed and current (used as the OpenChamber sidecar).
- **OpenChamber** — web UI server on `0.0.0.0:7777`, CLI-run (not desktop app),
  auto-starting at login.
- **Paseo** — headless daemon on `0.0.0.0:6767`, CLI-run (not desktop app),
  auto-starting at login via scheduled task.

All three are installed as npm CLIs. The script has a strict separation:

- **`install` is an explicit process** — it deliberately installs/updates the
  tools AND configures everything (autostarts, listen addresses, web UI,
  daemon state) so a fresh machine ends up fully set up.
- **`status` only verifies** — read-only; it checks that everything has been
  installed and configured (including autostarts) as intended.
- **`fix` repairs** — brings a broken install back to the intended state.

## Usage

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File install/scripts/dev-stack.ps1 [command]
```

| Command | What it does |
|---------|--------------|
| `install` | Explicit full setup: detects missing/outdated tools, runs the installers (`opencode-ctl.ps1`, `openchamber-ctl.ps1`, `paseo-ctl.ps1`), restarts daemons, then ensures autostart + config (Run key, scheduled task, `0.0.0.0` listen, web UI, password reminders) and verifies. Idempotent - safe to re-run. |
| `update` | Alias for `install`. |
| `status` (default) | Read-only check of the intended state. Exit code 0 = all good, 1 = issues found, 2 = could not verify (npm offline). |
| `fix` | Repairs runtime state: restarts stopped daemons, re-registers autostart, fixes listen config to `0.0.0.0` (prompted unless `-Force`), then re-verifies. |
| `start` | Starts OpenChamber + Paseo daemon (no-op if already running). |
| `stop` | Stops OpenChamber + Paseo daemon. |
| `startup <verb> [-App <app>]` | Manage autostart-at-login registration per tool (package stays installed). See below. |
| `uninstall -App <app>` | Full teardown per tool: stop, remove autostart, `npm uninstall -g` the package. See below. |

`status`, `start`, and `stop` accept `-App <opencode|openchamber|paseo|all>`
(alias `paseo-cli`) to target just one tool instead of all three - e.g.
`dev-stack.ps1 stop -App paseo-cli` stops only the Paseo daemon, leaving
OpenChamber running. Defaults to all tools when omitted. OpenCode has no
daemon of its own (it runs as an OpenChamber sidecar), so
`start`/`stop -App opencode` are no-ops that just explain that.

Use single-dash flags (`-App`, `-Quiet`, `-Force`, ...) - `-App` only
resolves to `-App` when the script is launched via `powershell -File`;
running it directly (`.\dev-stack.ps1 ...` or `& dev-stack.ps1 ...`, the
normal way) does **not** translate `--` to `-`, and `-App opencode` will
fail with `A positional parameter cannot be found that accepts argument
'opencode'`.

All commands accept `-Quiet` (suppress prompts/output) and `-Force` (skip
confirmation prompts). `install` and `fix` prompt before any destructive
action (stopping daemons, editing config files) unless `-Force` is given.

## `startup` - per-app autostart management

```powershell
install/scripts/dev-stack.ps1 startup <enable|disable|install|uninstall> [-App <app>]
```

Valid apps: `opencode`, `openchamber`, `paseo` (alias `paseo-cli`), `all`.

| Verb | `-App` required? | What it does |
|------|-------------------|--------------|
| `enable` | No - defaults to `all` | Turns autostart on. Registers it from scratch if not already installed. |
| `disable` | No - defaults to `all` | Turns autostart off (removes the OpenChamber Run key / disables the Paseo scheduled task) but leaves the underlying install in place. |
| `install` | Yes | Registers the autostart mechanism from scratch (OpenChamber Run key + startup wrappers, or the Paseo `PaseoDaemon` scheduled task). |
| `uninstall` | Yes | Removes the autostart mechanism entirely (OpenChamber Run key + wrapper files, or unregisters the Paseo scheduled task). |

Examples:

```powershell
install/scripts/dev-stack.ps1 startup enable -App opencode
install/scripts/dev-stack.ps1 startup install -App all
install/scripts/dev-stack.ps1 startup uninstall -App paseo-cli
install/scripts/dev-stack.ps1 startup disable   # all apps
```

OpenCode has no autostart mechanism of its own - it runs as an OpenChamber
sidecar, not a standalone daemon - so every verb is a no-op message for it.
This means `-App all` never errors on it. Registering/enabling the Paseo
scheduled task requires an elevated shell (it runs with `RunLevel Highest`);
run from an Admin PowerShell if you hit "Access is denied".

## `uninstall` - full lifecycle teardown

```powershell
install/scripts/dev-stack.ps1 uninstall -App <opencode|openchamber|paseo|all> [-WipeConfig]
```

Unlike `startup uninstall` (which only removes the autostart registration),
this stops the app, removes its autostart, and runs `npm uninstall -g` for
its package. `-App` has no default here - it's destructive, so you must name
what to remove. Delegates to each tool's own control script:

| App | Delegates to | Package removed |
|-----|---------------|------------------|
| `opencode` | `opencode-ctl.ps1 uninstall` | `opencode-ai` |
| `openchamber` | `openchamber-ctl.ps1 uninstall` | `@openchamber/web` |
| `paseo` | `paseo-ctl.ps1 uninstall` | `@getpaseo/cli` (also unregisters the `PaseoDaemon` scheduled task) |

Config/settings are **kept by default** (OpenChamber's `settings.json`,
Paseo's `~/.paseo` including any provider API keys, OpenCode's
`~/.config/opencode`). Pass `-WipeConfig` to also remove them - each control
script always asks for confirmation before wiping config, even with
`-WipeConfig`, unless `-Force` is given too.

```powershell
install/scripts/dev-stack.ps1 uninstall -App paseo-cli              # keeps ~/.paseo
install/scripts/dev-stack.ps1 uninstall -App opencode -WipeConfig   # prompts, then wipes config too
install/scripts/dev-stack.ps1 uninstall -App all -WipeConfig -Force # full wipe, no prompts
```

## Fresh machine workflow

```powershell
# 1. Install Node.js first (https://nodejs.org) - required by npm

# 2. One command: installs everything + configures autostarts + verifies
install/scripts/dev-stack.ps1 install

# 3. Only manual step: set the two UI passwords (interactive, cannot be
#    automated - the script prints reminders when they are missing)
paseo daemon set-password
[Environment]::SetEnvironmentVariable("OPENCHAMBER_UI_PASSWORD", "yourpassword", "User")

# 4. Confirm everything is as intended
install/scripts/dev-stack.ps1 status
```

## Paseo desktop app (optional, manual)

The intended layout is **one daemon: the CLI one**. The Paseo desktop app is
installed manually on top as a client, with its built-in daemon management
disabled so it does not start a second daemon:

1. Install the headless CLI first (covered by `install`).
2. Install the Paseo desktop app manually (https://paseo.sh/download).
3. In the desktop app, disable **Manage built-in daemon** (Settings -> Daemon).
   This persists as `"manageBuiltInDaemon": false` in
   `%APPDATA%\Paseo\desktop-settings.json`.

**This is advisory-only.** The script never modifies the desktop app's own
settings. `status` flags it with a WARN if the flag is not `false` (so the
exit code stays 0), and `install`/`fix` print the manual instruction — the
change must be done by you in the desktop app. The reason: if the desktop app
manages its own daemon while the headless CLI daemon is also running, two
daemons run side by side, which is exactly what we want to avoid.

## OpenChamber desktop app (optional, manual)

Same principle: **one server, the CLI one.** The OpenChamber desktop app
(Electron, installed at `%LOCALAPPDATA%\Programs\@openchamberelectron\`) can
run its own in-process web server by default — point it at the CLI server
instead:

1. Install the headless CLI first (covered by `install`).
2. Install the OpenChamber desktop app manually.
3. Set `OPENCHAMBER_SKIP_LOCAL_SERVER=1` (user env var) so the desktop app
   skips its in-process server entirely:
   ```powershell
   [Environment]::SetEnvironmentVariable("OPENCHAMBER_SKIP_LOCAL_SERVER", "1", "User")
   ```
4. In the desktop app, add `http://localhost:7777` (or the machine's LAN
   address) to its host/server list so it has a remote instance to connect to.

**This is advisory-only.** The script never modifies the desktop app's own
settings or host list (there is no simple JSON file for it — the host list
lives in the app's Electron storage). `status` flags it with a WARN if
`OPENCHAMBER_SKIP_LOCAL_SERVER` is not `1` while the desktop app is installed
(so the exit code stays 0), and `install`/`fix` print the manual instruction —
step 4 (adding the host) must be done by you in the desktop app's UI. The
reason: if the desktop app runs its own local server while the headless CLI
server is also running, two servers run side by side, which is exactly what
we want to avoid.

## What `status` checks

Per tool: CLI present on PATH, CLI resolves from npm (not a desktop app), the
real binary path (resolved from the npm shim to `node_modules\...`), installed
version vs. available on npm, daemon running, listening on `0.0.0.0` (all
interfaces, for remote access), health endpoint responding, and autostart
registration:

| Tool | Autostart mechanism | Health endpoint |
|------|---------------------|-----------------|
| OpenChamber | HKCU `Run` key → `~/.config/openchamber/launch.vbs` (settings `autoStart`, wrapper files present) | `http://localhost:7777/health` |
| Paseo | Scheduled task `PaseoDaemon` (runs `paseo daemon start` at logon) | `http://localhost:6767/api/health` |

Additional checks:

- The real binary per tool is resolved and reported:
  `node_modules\opencode-ai\bin\opencode.exe`,
  `node_modules\@openchamber\web\bin\cli.js`,
  `node_modules\@getpaseo\cli\bin\paseo` — plus the **running** daemon binary
  extracted from the live process command line (e.g.
  `...\@getpaseo\server\dist\server\server\daemon-worker.js`).
- For Paseo, "available version" considers both the `latest` and `beta` npm
  dist-tags and reports both; the newest of the two is used for the up-to-date
  check and for installs. `install`/`paseo-ctl.ps1` install
  `@getpaseo/cli@beta` when it is newer than `latest`, else `@getpaseo/cli@latest`.
- Paseo desktop app (if installed at `%LOCALAPPDATA%\Programs\Paseo\Paseo.exe`)
  is checked for its own version against the same available versions, so a
  stale desktop app is reported separately from a stale CLI.
- OpenChamber process must be the npm `cli.js serve` server (not the desktop
  app); Paseo's listening process must be `daemon-worker.js`.
- Paseo config (`~/.paseo/config.json`): `daemon.listen = 0.0.0.0:6767` and
  `features.webUi.enabled = true`.
- UI passwords: `OPENCHAMBER_UI_PASSWORD` env var for OpenChamber,
  `daemon.auth.password` in the Paseo config (required for remote access on
  `0.0.0.0`).
- Paseo desktop app (if installed): `manageBuiltInDaemon` must be `false` in
  `%APPDATA%\Paseo\desktop-settings.json` so the CLI daemon stays the only one.
  Flagged as a WARN only — the script never edits the desktop app's settings.
- OpenChamber desktop app (if installed): `OPENCHAMBER_SKIP_LOCAL_SERVER` user
  env var must be `1` so the CLI server stays the only one. Also reports the
  desktop app's own version vs. latest. Flagged as a WARN only — the script
  never edits the desktop app's settings/host list.
- Windows Firewall inbound allow for TCP 6767/7777 — reported as a WARN when
  it can't be determined (firewall cmdlets need elevation); run the script
  from an elevated prompt to get a definitive answer.

## Notes

- `install` intentionally reuses the existing per-tool installers instead of
  duplicating their Windows-specific handling (stopping running instances
  before npm replaces native modules, `allow-scripts` for
  `better-sqlite3`/`node-pty`, etc.).
- The installers stop daemons; `install` restarts them afterwards, then runs
  the same idempotent ensure step as `fix` (autostart + config), then
  re-verifies with the `status` checks.
- `fix` only edits `~/.config/openchamber/settings.json` / `~/.paseo/config.json`
  via targeted replacements (host/listen/webUi keys) and only with a prompt
  unless `-Force` is passed.
- On a machine with no tools at all, `status` reports clean FAILs and exits 1
  (no crash); `install` aborts with exit 2 if npm is unreachable/missing.

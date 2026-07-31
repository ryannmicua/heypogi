---
description: Install, update, configure (0.0.0.0:7777 from settings file), start, and uninstall the OpenChamber web server from heypogi
---

Manage the OpenChamber web UI lifecycle from heypogi with one script: install, update, configure defaults from a settings file (server on `0.0.0.0:7777`), start/stop, and clean up.

## Commands

| Command | What it does |
|---------|--------------|
| `install` | Install or update `@openchamber/web` globally via npm (stops a running instance first, allows native install scripts, re-runs `configure`). |
| `update` | Alias for `install` (updates to latest and reconfigures). |
| `configure` | Creates `~/.config/openchamber/settings.json` from the repo template, writes `startup.ps1` + `launch.vbs` wrappers, registers the HKCU Run key (auto-start on login), and sets `OPENCHAMBER_UI_PASSWORD` if a password is configured. Idempotent - safe to re-run. |
| `serve` | Run in the foreground using settings from file (Ctrl+C to stop). |
| `start` | Start detached/hidden via the VBS launcher and wait for health. |
| `stop` | Stop the running instance (official `openchamber stop`, plus kill fallback on the configured port). |
| `status` | Show version, settings, listening state, health, Run key, wrappers, password status. |
| `uninstall` | Stop, remove Run key + wrappers + settings, and `npm uninstall -g @openchamber/web`. Use `-KeepSettings` / `-KeepPackage` to preserve either. |

All commands take `-Quiet` (no prompts/output) and `-Force` (skip confirmation prompts). Run from PowerShell:

```powershell
& "C:\Users\rmicua\myrepo\heypogi\install\scripts\openchamber.ps1" status
```

## Quick start (new machine)

```powershell
# 1. Install/update the npm package
& "$env:HEYPOGI_ROOT\install\scripts\openchamber.ps1" install

# 2. Optional: set a UI password for the browser interface
#    (edit ~/.config/openchamber/settings.json and set "password")
#    Or set the env var directly:
#    [Environment]::SetEnvironmentVariable("OPENCHAMBER_UI_PASSWORD", "yourpassword", "User")

# 3. Start it
& "$env:HEYPOGI_ROOT\install\scripts\openchamber.ps1" start

# 4. Verify
& "$env:HEYPOGI_ROOT\install\scripts\openchamber.ps1" status
```

## Settings file

OpenChamber itself has no config file for serve settings (port/host are CLI-flag only, password is an env var) - the script is the layer that reads them from a file:

**Repo template:** `install/openchamber.settings.json` (committed defaults)
**Machine copy:** `~/.config/openchamber/settings.json` (created on first `configure`, edit for machine-specific overrides; re-run `configure` after editing)

| Key | Default | Effect |
|-----|---------|--------|
| `port` | `7777` | Web UI port |
| `host` | `0.0.0.0` | Bind address (all interfaces) |
| `autoStart` | `true` | Register HKCU Run key so OpenChamber starts on login |
| `password` | `""` | If non-empty, written to `OPENCHAMBER_UI_PASSWORD` (user env). Empty means unmanaged. |

The generated `startup.ps1` re-reads the machine settings file at launch, so you can also edit it without re-running `configure`.

## Updating

```powershell
& "$env:HEYPOGI_ROOT\install\scripts\openchamber.ps1" install
```

The script stops the running daemon first - this matters: on Windows, npm cannot replace `better-sqlite3.node` while the server holds it (EPERM). It also configures npm `allow-scripts=better-sqlite3,node-pty` so the native addons build/install correctly.

## Cleanup

```powershell
& "$env:HEYPOGI_ROOT\install\scripts\openchamber.ps1" uninstall
```

Stops the server, removes the Run key, deletes the wrappers and settings, and uninstalls the npm package.

## Why the wrapper scripts exist

- `openchamber startup enable` fails on Windows: `schtasks.exe` truncates the `/TR` argument at 261 chars and the generated command exceeds it. A HKCU `Run` key avoids this and needs no admin.
- The wrappers (`~/.config/openchamber/startup.ps1` + `launch.vbs`) launch the server hidden and detached so it survives the launching shell. `launch.vbs` is what the Run key invokes.
- The generated `startup.ps1` resolves `node.exe` and the npm-installed `cli.js` at configure time instead of hardcoding one machine layout.

## Manual fallback (no repo)

```powershell
# password for the UI (persistent, optional)
[Environment]::SetEnvironmentVariable("OPENCHAMBER_UI_PASSWORD", "yourpassword", "User")
# foreground serve with the same settings
openchamber serve --foreground --port 7777 --host 0.0.0.0
```

## Controlling the OpenCode sidecar

OpenChamber starts its own OpenCode server as a sidecar. Env vars to control that:

| Env var | Scope | Effect |
|---------|-------|--------|
| `OPENCODE_SKIP_START=true` | CLI + Desktop | UI runs but does **not** spawn the OpenCode sidecar. Connect to an existing server via `OPENCODE_HOST` (full URL) or `OPENCODE_HOST` + `OPENCODE_PORT`. |
| `OPENCHAMBER_SKIP_OPENCODE_START=true` | CLI + Desktop | Alias for the above. |
| `OPENCHAMBER_SKIP_LOCAL_SERVER=1` | Desktop only | Desktop skips its in-process web server entirely; needs a remote instance in the host list. |

Example - serve UI on 7777 but point at an existing OpenCode server:

```powershell
$env:OPENCODE_SKIP_START = "true"
$env:OPENCODE_HOST = "http://192.168.1.50:4096"
openchamber serve --foreground --port 7777 --host 0.0.0.0
```

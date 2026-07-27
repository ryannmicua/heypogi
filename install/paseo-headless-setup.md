---
description: Install Paseo headless CLI, enable web UI on a chosen network interface, set a password, and auto-start at login
---

Set up Paseo as a headless daemon that starts automatically when you log in, with the web UI enabled on a network of your choice.

## Prerequisites

- [Node.js](https://nodejs.org) (LTS recommended)
- npm (ships with Node.js)

## Steps

1. **Install the headless CLI**
   ```powershell
   npm install -g @getpaseo/cli
   paseo --version
   ```

2. **Choose which network to listen on**

   List your network interfaces to find the right IP:
   ```powershell
   Get-NetIPAddress | Where-Object {$_.AddressFamily -eq "IPv4"} | Format-Table IPAddress, InterfaceAlias
   ```

   Pick one:
   - `127.0.0.1` — localhost only (safe, no setup needed)
   - A LAN IP like `10.x.x.x` or `192.168.x.x` — reachable on your local network
   - A VPN/tailnet IP like `100.x.x.x` (Netbird, Tailscale, ZeroTier) — reachable across your private network
   - `0.0.0.0` — all interfaces (use with caution; requires a password)

3. **Set a password** (required when binding beyond localhost)

   ```powershell
   paseo daemon set-password
   ```

   This prompts for a password and stores a bcrypt hash in config.json.

   Alternatively, set it via environment variable (plaintext, hashed at startup):
   ```powershell
   [Environment]::SetEnvironmentVariable("PASEO_PASSWORD", "yourpassword", "User")
   ```

4. **Edit config.json**

   Open `~\.paseo\config.json` and set the listen address, hostnames, and web UI:

   ```json
   {
     "version": 1,
     "daemon": {
       "listen": "<your-chosen-ip>:6767",
       "hostnames": [".your-domain.com"],
       "auth": {
         "password": "<added-by-set-password-command>"
       }
     },
     "features": {
       "webUi": {
         "enabled": true
       }
     }
   }
   ```

   Replace:
   - `<your-chosen-ip>` with the IP from step 2
   - `.your-domain.com` with your DNS domain if accessing via hostname, or remove it if using IP directly
   - The `auth.password` field is filled in automatically by `paseo daemon set-password`

5. **Test the daemon starts correctly**

   ```powershell
   paseo daemon start
   ```

   Verify it's listening:
   ```powershell
   paseo daemon status
   netstat -ano | Select-String ":6767"
   curl -s http://<your-chosen-ip>:6767/api/health
   ```

   Open `http://<your-chosen-ip>:6767` in a browser — the web UI should load and prompt for the password.

   Stop the test daemon:
   ```powershell
   paseo daemon stop
   ```

6. **Register to auto-start at login via Task Scheduler**

   Create a scheduled task that runs `paseo daemon start` at user logon.
   PowerShell's `Register-ScheduledTask` uses the Task Scheduler COM API
   (not `schtasks.exe`), so it avoids the 261-char argument limit.
   Paths are resolved at registration time so the task works even before
   the shell profile is fully loaded:

   ```powershell
   $nodePath = (Get-Command node).Source
   $paseoBin = "$env:APPDATA\npm\node_modules\@getpaseo\cli\bin\paseo"
   $action = New-ScheduledTaskAction -Execute $nodePath `
     -Argument "--disable-warning=DEP0040 `"$paseoBin`" daemon start"
   $trigger = New-ScheduledTaskTrigger -AtLogOn -User $env:USERNAME
   $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries
   Register-ScheduledTask -TaskName "PaseoDaemon" -Action $action -Trigger $trigger -Settings $settings -RunLevel Highest -Force
   ```

   > `-RunLevel Highest` runs the daemon with elevated privileges (required for binding any port or network interface). The task runs in the user's session so `USERPROFILE` and other user env vars are available — `PASEO_HOME` defaults to `~/.paseo` automatically.

7. **Verify the registration**
   ```powershell
   Get-ScheduledTask -TaskName "PaseoDaemon" | Format-List TaskName, State, Actions, Triggers
   ```

8. **Reboot and confirm**

   ```powershell
   Restart-Computer
   ```

   After login, check:
   ```powershell
   paseo daemon status
   curl -s http://<your-chosen-ip>:6767/api/health
   ```

## How it works

| Component | Detail |
|---|---|
| CLI | `@getpaseo/cli` via npm — no desktop app dependency |
| Auto-start mechanism | Task Scheduler — runs `paseo daemon start` via node at user logon |
| Config | `~/.paseo/config.json` — listen, web UI, password |
| Web UI | Daemon-served at `http://<ip>:6767` (login screen without auth, API behind password) |
| Password | bcrypt hash in config.json, set via `paseo daemon set-password` |

## Troubleshooting

- **Daemon not running after login**: Check the scheduled task exists and is enabled (`Get-ScheduledTask -TaskName "PaseoDaemon"`).
- **Web UI loads but can't connect**: Make sure the browser can reach the IP/port. Check Windows firewall for port 6767.
- **Daemon can't find config**: Verify `PASEO_HOME` is correct or `~/.paseo/config.json` exists.
- **Two daemons running**: Each login creates a new daemon process. Paseo handles PID file conflicts gracefully; the older process becomes stale and is cleaned up.

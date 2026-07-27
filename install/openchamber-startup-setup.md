---
description: Configure OpenChamber web server to run on login, listening on all interfaces at port 7777 with UI password auth
---

Set OpenChamber to start automatically on Windows login, bound to `0.0.0.0:7777`.

## Steps

1. **Confirm OpenChamber is installed**
   ```powershell
   openchamber --version
   ```

2. **User must set `OPENCHAMBER_UI_PASSWORD` as a persistent user env var**
   Run this in PowerShell (replace `yourpassword`):
   ```powershell
   [Environment]::SetEnvironmentVariable("OPENCHAMBER_UI_PASSWORD", "yourpassword", "User")
   ```

3. **Create the startup wrapper script and VBS launcher**
   ```powershell
   $dir = "$env:USERPROFILE\.config\openchamber"
   New-Item -ItemType Directory -Path $dir -Force
   @"
   & 'C:\Program Files\nodejs\node.exe' "$env:APPDATA\npm\node_modules\@openchamber\web\bin\cli.js" serve --foreground --port 7777 --host 0.0.0.0
   "@ | Set-Content "$dir\startup.ps1"
   @"
   CreateObject("Wscript.Shell").Run "powershell.exe -NoProfile -ExecutionPolicy Bypass -File " & CreateObject("Scripting.FileSystemObject").GetParentFolderName(WScript.ScriptFullName) & "\startup.ps1", 0, False
   "@ | Set-Content "$dir\launch.vbs"
   ```

4. **Register via HKCU Run key** (no admin required)
   ```powershell
   New-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run" -Name "OpenChamber" -Value "wscript.exe //NoLogo $env:USERPROFILE\.config\openchamber\launch.vbs" -PropertyType String -Force
   ```

5. **Verify the registration**
   ```powershell
   Get-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run" -Name "OpenChamber"
   ```

6. **Test by running the script**
   ```powershell
   powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.config\openchamber\startup.ps1"
   ```

7. **Confirm it's listening**
   ```powershell
   netstat -ano | Select-String ":7777"
   curl -s http://localhost:7777/health
   ```

## Why this approach

`openchamber startup enable` fails because `schtasks.exe` has a 261-char limit on the `/TR` argument and the generated command exceeds it. The registry `Run` key avoids this entirely and works per-user without admin rights.

## Controlling OpenCode server startup

OpenChamber normally starts its own OpenCode server as a sidecar. Use these env vars to control that behavior:

| Env var | Scope | Effect |
|---------|-------|--------|
| `OPENCODE_SKIP_START=true` | CLI + Desktop | OpenChamber UI runs but **does not spawn** the OpenCode sidecar. Connect to an existing server by setting `OPENCODE_HOST` (full URL, e.g. `http://192.168.1.50:4096`) or `OPENCODE_HOST` + `OPENCODE_PORT` separately. |
| `OPENCHAMBER_SKIP_OPENCODE_START=true` | CLI + Desktop | Alias for `OPENCODE_SKIP_START=true` (same behavior). |
| `OPENCHAMBER_SKIP_LOCAL_SERVER=1` | Desktop only | Desktop app skips starting its in-process web server entirely (no UI served locally). Requires a remote instance in the host list. |

Setting `OPENCHAMBER_SKIP_LOCAL_SERVER` and `OPENCODE_SKIP_START` together means the desktop starts nothing locally — it relies entirely on a remote instance for both UI and OpenCode.

### CLI: Skip OpenCode sidecar (still serve UI)

```powershell
$env:OPENCODE_SKIP_START = "true"
openchamber serve --foreground --port 7777 --host 0.0.0.0
```

The web UI runs but won't start OpenCode. Point it at an existing server by setting the full URL:

```powershell
$env:OPENCODE_SKIP_START = "true"
$env:OPENCODE_HOST = "http://192.168.1.50:4096"
openchamber serve --foreground --port 7777 --host 0.0.0.0
```

Or set host and port separately:

```powershell
$env:OPENCODE_SKIP_START = "true"
$env:OPENCODE_HOST = "192.168.1.50"
$env:OPENCODE_PORT = "4096"
openchamber serve --foreground --port 7777 --host 0.0.0.0
```

### Desktop: Skip local server entirely

```powershell
$env:OPENCHAMBER_SKIP_LOCAL_SERVER = "1"
openchamber-desktop
```

The Electron app won't start its in-process server at all — it connects to a remote instance from its host list.

### Desktop: Skip only the OpenCode sidecar

```powershell
$env:OPENCODE_SKIP_START = "true"
openchamber-desktop
```

Desktop still serves its UI locally but won't spawn OpenCode. Useful when you have a dedicated OpenCode server elsewhere.

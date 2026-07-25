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

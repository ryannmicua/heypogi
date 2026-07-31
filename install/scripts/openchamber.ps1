[CmdletBinding()]
param(
  [Parameter(Position = 0)]
  [ValidateSet("install", "update", "configure", "serve", "start", "stop", "status", "uninstall")]
  [string]$Command = "status",
  [switch]$Quiet,
  [switch]$Force,
  [switch]$KeepSettings,
  [switch]$KeepPackage
)

$ErrorActionPreference = "Stop"

# ---------- helpers ----------
function Read-Choice {
  param([string]$Prompt, [string[]]$ValidChoices)
  while ($true) {
    $answer = Read-Host $Prompt
    if ($null -eq $answer) { continue }
    $answer = $answer.Trim().ToUpperInvariant()
    if ($ValidChoices -contains $answer) { return $answer }
    Write-Host "Invalid choice. Valid: $($ValidChoices -join ', ')" -ForegroundColor Yellow
  }
}

function Get-SettingsPath {
  return Join-Path $env:USERPROFILE ".config\openchamber\settings.json"
}

function Get-WrapperDir {
  return Join-Path $env:USERPROFILE ".config\openchamber"
}

function Read-Settings {
  $settingsPath = Get-SettingsPath
  $defaults = @{
    port      = 7777
    host      = "0.0.0.0"
    autoStart = $true
    password  = ""
  }
  if (Test-Path -LiteralPath $settingsPath) {
    try {
      $file = Get-Content -LiteralPath $settingsPath -Raw | ConvertFrom-Json
      if ($null -ne $file.port) { $defaults.port = [int]$file.port }
      if ($null -ne $file.host -and "$($file.host)".Trim() -ne "") { $defaults.host = "$($file.host)".Trim() }
      if ($null -ne $file.autoStart) { $defaults.autoStart = [bool]$file.autoStart }
      if ($null -ne $file.password) { $defaults.password = "$($file.password)" }
    } catch {
      Write-Host "Warning: could not parse $settingsPath : $($_.Exception.Message)" -ForegroundColor Yellow
      Write-Host "Using defaults." -ForegroundColor Yellow
    }
  }
  return $defaults
}

function Get-CliJsPath {
  $candidates = @(
    (Join-Path $env:APPDATA "npm\node_modules\@openchamber\web\bin\cli.js"),
    (Join-Path $env:LOCALAPPDATA "npm\node_modules\@openchamber\web\bin\cli.js")
  )
  $shim = Get-Command "openchamber" -ErrorAction SilentlyContinue
  if ($shim -and $shim.Source -match "^(?<dir>.+)\\(?:openchamber(?:\.ps1|\.cmd)?)$") {
    $candidates += (Join-Path $matches["dir"] "node_modules\@openchamber\web\bin\cli.js")
  }
  foreach ($candidate in $candidates) {
    if (Test-Path -LiteralPath $candidate) { return $candidate }
  }
  return $null
}

function Get-NodeExe {
  $node = Get-Command "node" -ErrorAction SilentlyContinue
  if ($node) { return $node.Source }
  $nodeJs = "C:\Program Files\nodejs\node.exe"
  if (Test-Path -LiteralPath $nodeJs) { return $nodeJs }
  return $null
}

function Get-ListeningPid {
  param([int]$Port)
  $lines = netstat -ano 2>$null
  foreach ($line in $lines) {
    if ($line -match ":$Port\s+\S+:0\s+LISTENING\s+(\d+)\s*$") {
      return [int]$matches[1]
    }
  }
  return $null
}

function Test-Listening {
  param([int]$Port)
  return $null -ne (Get-ListeningPid -Port $Port)
}

function Get-Health {
  param([int]$Port)
  try {
    return Invoke-RestMethod "http://localhost:$Port/health" -TimeoutSec 5
  } catch {
    return $null
  }
}

function Stop-OpenChamberInstance {
  $settings = Read-Settings
  $stopped = $false

  $cli = Get-CliJsPath
  if ($cli) {
    & "openchamber" stop *> $null
    $stopped = $true
  }

  $pidOnPort = Get-ListeningPid -Port $settings.port
  if ($pidOnPort) {
    Stop-Process -Id $pidOnPort -Force -ErrorAction SilentlyContinue
    $stopped = $true
    if (-not $Quiet) {
      Write-Host "Stopped process $pidOnPort listening on port $($settings.port)." -ForegroundColor Cyan
    }
  }

  if ($stopped -and -not $Quiet) {
    Write-Host "OpenChamber stopped." -ForegroundColor Green
  } elseif (-not $Quiet -and -not $cli -and -not $pidOnPort) {
    Write-Host "No running OpenChamber instance found." -ForegroundColor Yellow
  }
}

function Set-EnvVar {
  param([string]$Name, [string]$Value)
  $current = [Environment]::GetEnvironmentVariable($Name, "User")
  if ($null -ne $current -and $current -eq $Value) {
    if (-not $Quiet) {
      Write-Host "Registry ${Name} already set correctly." -ForegroundColor Green
    }
    return
  }
  if (-not $Quiet -and -not $Force -and $null -ne $current -and $current -ne "") {
    Write-Host "Current registry ${Name} differs." -ForegroundColor Yellow
    $choice = Read-Choice -Prompt "Overwrite? [Y]es, [N]o?" -ValidChoices @("Y", "N")
    if ($choice -eq "N") { return }
  }
  [Environment]::SetEnvironmentVariable($Name, $Value, "User")
  if (-not $Quiet) {
    Write-Host "Set ${Name} in user environment." -ForegroundColor Green
  }
}

function Invoke-Configure {
  $settings = Read-Settings
  $wrapperDir = Get-WrapperDir
  $settingsPath = Get-SettingsPath
  $repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
  $template = Join-Path $repoRoot "install\openchamber.settings.json"

  New-Item -ItemType Directory -Path $wrapperDir -Force | Out-Null

  if (-not (Test-Path -LiteralPath $settingsPath)) {
    if (Test-Path -LiteralPath $template) {
      Copy-Item -LiteralPath $template -Destination $settingsPath
      Write-Host "Created settings from repo template: $settingsPath" -ForegroundColor Cyan
    } else {
      Set-Content -LiteralPath $settingsPath -Value ($settings | ConvertTo-Json)
      Write-Host "Created default settings: $settingsPath" -ForegroundColor Cyan
    }
  }

  if ($settings.password -ne "") {
    Set-EnvVar -Name "OPENCHAMBER_UI_PASSWORD" -Value $settings.password
  } elseif (-not $Quiet) {
    $hasPassword = $null -ne [Environment]::GetEnvironmentVariable("OPENCHAMBER_UI_PASSWORD", "User")
    if (-not $hasPassword) {
      Write-Host "Warning: no UI password set (settings 'password' is empty) - UI exposed on $($settings.host):$($settings.port) without auth." -ForegroundColor Yellow
    }
  }

  $node = Get-NodeExe
  $cli = Get-CliJsPath
  if (-not $node) { throw "Node.js not found. Install Node.js first." }
  if (-not $cli) { throw "OpenChamber CLI not found. Run: $PSScriptRoot\openchamber.ps1 install" }

  $startupPs1 = Join-Path $wrapperDir "startup.ps1"
  $launchVbs = Join-Path $wrapperDir "launch.vbs"

  @"
`$ErrorActionPreference = "Stop"
`$settingsPath = "$settingsPath"
`$settings = @{ port = $($settings.port); host = "$($settings.host)" }
if (Test-Path -LiteralPath `$settingsPath) {
  `$file = Get-Content -LiteralPath `$settingsPath -Raw | ConvertFrom-Json
  if (`$null -ne `$file.port) { `$settings.port = [int]`$file.port }
  if (`$null -ne `$file.host -and "`$(`$file.host)".Trim() -ne "") { `$settings.host = "`$(`$file.host)".Trim() }
}
if (-not (Test-Path -LiteralPath "$cli")) { throw "OpenChamber CLI not found: $cli. Run install/scripts/openchamber.ps1 install" }
& "$node" "$cli" serve --foreground --port `$settings.port --host `$settings.host
"@ | Set-Content -LiteralPath $startupPs1 -Encoding UTF8

  @"
CreateObject("Wscript.Shell").Run "powershell.exe -NoProfile -ExecutionPolicy Bypass -File " & CreateObject("Scripting.FileSystemObject").GetParentFolderName(WScript.ScriptFullName) & "\startup.ps1", 0, False
"@ | Set-Content -LiteralPath $launchVbs -Encoding ASCII

  $runKeyPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
  $runValue = "wscript.exe //NoLogo $launchVbs"
  if ($settings.autoStart) {
    New-ItemProperty -Path $runKeyPath -Name "OpenChamber" -Value $runValue -PropertyType String -Force | Out-Null
    Write-Host "Registered HKCU Run key: OpenChamber" -ForegroundColor Green
  } else {
    Remove-ItemProperty -Path $runKeyPath -Name "OpenChamber" -ErrorAction SilentlyContinue
    Write-Host "autoStart is false - removed HKCU Run key." -ForegroundColor Yellow
  }

  if (-not $Quiet) {
    Write-Host ""
    Write-Host "Configured:" -ForegroundColor Green
    Write-Host "  Settings : $settingsPath (port $($settings.port), host $($settings.host), autoStart $($settings.autoStart))"
    Write-Host "  Startup  : $startupPs1"
    Write-Host "  Launcher : $launchVbs"
    Write-Host "  UI       : http://localhost:$($settings.port) (http://$($settings.host):$($settings.port) on LAN)"
    Write-Host "  Start    : $PSScriptRoot\openchamber.ps1 start"
  }
}

function Invoke-Install {
  $hasNode = Get-Command "node" -ErrorAction SilentlyContinue
  $hasNpm = Get-Command "npm" -ErrorAction SilentlyContinue
  if (-not $hasNode -or -not $hasNpm) {
    Write-Host "Node.js / npm is required. Install from https://nodejs.org then re-run." -ForegroundColor Red
    exit 1
  }

  $currentVersion = & "openchamber" "--version" 2>$null

  if (Test-Listening -Port (Read-Settings).port) {
    if (-not $Quiet -and -not $Force) {
      Write-Host "OpenChamber is running. It must be stopped before installing/updating (native modules get locked)." -ForegroundColor Yellow
      $choice = Read-Choice -Prompt "Stop it and continue? [Y]es, [N]o?" -ValidChoices @("Y", "N")
      if ($choice -eq "N") { exit 0 }
    }
    Stop-OpenChamberInstance
  }

  if (-not $Quiet) {
    if ($currentVersion) {
      Write-Host "Current: openchamber $currentVersion" -ForegroundColor Green
    } else {
      Write-Host "OpenChamber not installed yet." -ForegroundColor Yellow
    }
  }

  npm config set allow-scripts=better-sqlite3,node-pty --location=user 2>$null

  $out = npm install -g @openchamber/web@latest 2>&1
  $exitCode = $LASTEXITCODE
  $outString = $out | Out-String
  if ($exitCode -ne 0) {
    Write-Host ""
    Write-Host $outString -ForegroundColor Red
    Write-Host "npm install failed (exit $exitCode)." -ForegroundColor Red
    exit $exitCode
  }

  $newVersion = & "openchamber" "--version" 2>$null
  if (-not $newVersion) {
    Write-Host "Install succeeded but 'openchamber --version' failed. Check your PATH." -ForegroundColor Yellow
    exit 1
  }

  Invoke-Configure

  if (-not $Quiet) {
    Write-Host ""
    Write-Host "OpenChamber $newVersion installed." -ForegroundColor Green
    if ($currentVersion -and $currentVersion -ne $newVersion) {
      Write-Host "Updated: $currentVersion -> $newVersion" -ForegroundColor Cyan
    }
    Write-Host "Start with: $PSScriptRoot\openchamber.ps1 start"
  }
}

function Invoke-Start {
  $settings = Read-Settings
  if (Test-Listening -Port $settings.port) {
    $health = Get-Health -Port $settings.port
    Write-Host "Already running on port $($settings.port) (OpenChamber $($health.openchamberVersion))." -ForegroundColor Yellow
    return
  }

  $launchVbs = Join-Path (Get-WrapperDir) "launch.vbs"
  if (-not (Test-Path -LiteralPath $launchVbs)) {
    throw "Launcher not found: $launchVbs. Run: $PSScriptRoot\openchamber.ps1 configure"
  }

  wscript.exe //NoLogo $launchVbs

  $health = $null
  for ($i = 0; $i -lt 30 -and -not $health; $i++) {
    Start-Sleep -Seconds 1
    $health = Get-Health -Port $settings.port
  }

  if ($health) {
    $ocState = if ($health.openCodeRunning) { "running" } else { "not running" }
    Write-Host "OpenChamber $($health.openchamberVersion) up on http://$($settings.host):$($settings.port) (OpenCode $ocState)" -ForegroundColor Green
  } else {
    Write-Host "Launched but health check on port $($settings.port) did not pass yet. Check: $PSScriptRoot\openchamber.ps1 status" -ForegroundColor Yellow
  }
}

function Invoke-Serve {
  $settings = Read-Settings
  $node = Get-NodeExe
  $cli = Get-CliJsPath
  if (-not $node -or -not $cli) {
    throw "OpenChamber CLI not found. Run: $PSScriptRoot\openchamber.ps1 install"
  }
  Write-Host "Starting OpenChamber on port $($settings.port) (foreground, Ctrl+C to stop)" -ForegroundColor Cyan
  & $node $cli serve --foreground --port $settings.port --host $settings.host
}

function Invoke-Status {
  $settings = Read-Settings
  $cli = Get-CliJsPath
  $version = & "openchamber" "--version" 2>$null

  Write-Host "OpenChamber status" -ForegroundColor Green
  Write-Host "  Package version : $version"
  Write-Host "  CLI entry       : $cli"
  if (-not $cli) { Write-Host "  CLI entry       : NOT INSTALLED - run openchamber.ps1 install" -ForegroundColor Red }

  $listening = Test-Listening -Port $settings.port
  $pidOnPort = Get-ListeningPid -Port $settings.port
  Write-Host "  Settings file   : $(Get-SettingsPath) (port $($settings.port), host $($settings.host), autoStart $($settings.autoStart))"
  Write-Host "  Listening       : $(if ($listening) { "YES (pid $pidOnPort)" } else { "no" })"
  if ($listening) {
    $health = Get-Health -Port $settings.port
    if ($health) {
      Write-Host "  Health          : ok - OpenChamber $($health.openchamberVersion), OpenCode running: $($health.openCodeRunning)"
    } else {
      Write-Host "  Health          : port open but /health not responding" -ForegroundColor Yellow
    }
  }

  $wrapperDir = Get-WrapperDir
  Write-Host "  Wrapper files   : startup.ps1 $(if (Test-Path (Join-Path $wrapperDir 'startup.ps1')) {'yes'} else {'MISSING'}), launch.vbs $(if (Test-Path (Join-Path $wrapperDir 'launch.vbs')) {'yes'} else {'MISSING'})"
  $runValue = (Get-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run" -Name "OpenChamber" -ErrorAction SilentlyContinue).OpenChamber
  Write-Host "  HKCU Run key    : $(if ($runValue) { $runValue } else { 'not registered' })"
  $pwd = [Environment]::GetEnvironmentVariable("OPENCHAMBER_UI_PASSWORD", "User")
  Write-Host "  UI password     : $(if ($pwd) { 'set (env)' } else { 'NOT SET' })"

  if ($settings.password -ne "" -and $pwd -ne $settings.password) {
    Write-Host "  Note            : settings password differs from env var - re-run configure" -ForegroundColor Yellow
  }
}

function Invoke-Uninstall {
  Stop-OpenChamberInstance

  $runKeyPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
  Remove-ItemProperty -Path $runKeyPath -Name "OpenChamber" -ErrorAction SilentlyContinue
  Write-Host "Removed HKCU Run key." -ForegroundColor Cyan

  $wrapperDir = Get-WrapperDir
  foreach ($file in @("startup.ps1", "launch.vbs")) {
    $path = Join-Path $wrapperDir $file
    if (Test-Path -LiteralPath $path) {
      Remove-Item -LiteralPath $path -Force
      Write-Host "Removed $path" -ForegroundColor Cyan
    }
  }

  $settingsPath = Get-SettingsPath
  if (-not $KeepSettings -and (Test-Path -LiteralPath $settingsPath)) {
    Remove-Item -LiteralPath $settingsPath -Force
    Write-Host "Removed $settingsPath" -ForegroundColor Cyan
  }

  if (-not $KeepPackage) {
    npm uninstall -g @openchamber/web 2>&1 | Out-Null
    Write-Host "Uninstalled npm package @openchamber/web." -ForegroundColor Cyan
  }

  Write-Host "OpenChamber cleanup complete." -ForegroundColor Green
}

# ---------- dispatch ----------
if ($Command -eq "update") { $Command = "install" }

switch ($Command) {
  "install"    { Invoke-Install }
  "configure"  { Invoke-Configure }
  "serve"      { Invoke-Serve }
  "start"      { Invoke-Start }
  "stop"       { Stop-OpenChamberInstance }
  "status"     { Invoke-Status }
  "uninstall"  { Invoke-Uninstall }
}

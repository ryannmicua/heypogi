[CmdletBinding()]
param(
  [Parameter(Position = 0)]
  [ValidateSet("status", "install", "update", "fix", "start", "stop", "help")]
  [string]$Command = "status",
  [switch]$Quiet,
  [switch]$Force
)

$ErrorActionPreference = "Stop"

# ---------- constants ----------
$OpenChamberPort   = 7777
$PaseoPort         = 6767
$OpenChamberRunKey = "OpenChamber"
$PaseoTaskName     = "PaseoDaemon"
$PkgOpenCode       = "opencode-ai"
$PkgOpenChamber    = "@openchamber/web"
$PkgPaseo          = "@getpaseo/cli"
$RunKeyPath        = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
# package-relative real binary paths (npm global layout: shim dir\node_modules\<rel>)
$OpenCodeBinRel    = "opencode-ai\bin\opencode.exe"
$OpenChamberBinRel = "@openchamber\web\bin\cli.js"
$PaseoBinRel       = "@getpaseo\cli\bin\paseo"

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

# Run a delegated action (openchamber.ps1 / paseo) without crashing the
# supervisor when the tool is missing on a fresh machine.
function Safe-Invoke {
  param([string]$What, [scriptblock]$Body)
  try {
    & $Body
    return $true
  } catch {
    Write-Host "$What failed: $($_.Exception.Message)" -ForegroundColor Red
    return $false
  }
}

# `paseo daemon start` inherits this shell's environment, and the daemon is
# long-lived. When the script runs from inside an opencode/OpenChamber session
# that env carries OPENCODE_SERVER_PASSWORD, which makes every opencode server
# the daemon later spawns require Basic auth that Paseo itself never sends -
# the provider list then fails with "Failed to fetch OpenCode providers: {}".
# Strip the session-scoped vars for the duration of the call only; later checks
# (eg. the OpenChamber password reminder) still need the original env.
function Invoke-PaseoDaemon {
  param([ValidateSet("start", "restart")][string]$Action)
  $saved = @{}
  foreach ($v in 'OPENCODE_SERVER_PASSWORD','OPENCODE_SERVER_USERNAME','OPENCODE_CONFIG_CONTENT','OPENCODE_PID','OPENCODE','AGENT') {
    if (Test-Path "Env:$v") {
      $saved[$v] = (Get-Item "Env:$v").Value
      Remove-Item "Env:$v"
    }
  }
  try {
    & paseo daemon $Action
  } finally {
    foreach ($k in $saved.Keys) { Set-Item "Env:$k" $saved[$k] }
  }
}

function Get-ListeningPid {
  param([int]$Port)
  $line = netstat -ano 2>$null | Select-String "0\.0\.0\.0:$Port\s+0\.0\.0\.0:0\s+LISTENING" | Select-Object -First 1
  if ($line -and $line.Line -match "LISTENING\s+(\d+)\s*$") { return [int]$matches[1] }
  return $null
}

function Get-ProcessCommandLine {
  param([int]$ProcessId)
  try {
    return (Get-CimInstance Win32_Process -Filter "ProcessId=$ProcessId" -ErrorAction Stop).CommandLine
  } catch {
    return ""
  }
}

function Get-CommandSource {
  param([string]$Name)
  $cmd = Get-Command $Name -ErrorAction SilentlyContinue
  if ($cmd) { return $cmd.Source }
  return $null
}

function Test-NpmInstalledCli {
  param([string]$Source)
  if (-not $Source) { return $false }
  return ($Source -match "npm|node_modules|nodejs")
}

# Safe version query - returns $null (not a crash) when the command is missing
function Get-Version {
  param([string]$Name)
  try {
    $v = & $Name --version 2>$null
    if ($v) { return "$v".Trim() }
  } catch { }
  return $null
}

# Read the file version of an installed app (e.g. the Paseo desktop exe)
function Get-FileVersion {
  param([string]$Path)
  try {
    if (-not (Test-Path -LiteralPath $Path)) { return $null }
    $vi = (Get-Item -LiteralPath $Path).VersionInfo
    if ($vi -and $vi.FileVersion) { return "$($vi.FileVersion)".Trim() }
  } catch { }
  return $null
}

# Resolve the real binary from the npm shim location:
# shim dir (e.g. %APPDATA%\npm) + node_modules\<package-relative path>
function Get-NpmBinary {
  param([string]$ShimPath, [string]$PackageRel)
  if (-not $ShimPath) { return $null }
  $shimDir = Split-Path $ShimPath -Parent
  $candidate = Join-Path $shimDir (Join-Path "node_modules" $PackageRel)
  if (Test-Path -LiteralPath $candidate) { return $candidate }
  # Get-Command may resolve straight to the real binary inside node_modules
  # instead of the npm shim - accept it as-is when it already exists.
  if ($ShimPath -match "node_modules" -and (Test-Path -LiteralPath $ShimPath)) { return $ShimPath }
  return $null
}

function Get-LatestVersion {
  param([string]$Package)
  try {
    $v = (& npm view $Package version --fetch-timeout=8000 --fetch-retries=1 2>$null | Select-Object -Last 1)
    if ($v -and "$v" -match "^\d") { return "$v".Trim() }
  } catch { }
  return $null
}

# Query a specific npm dist-tag (e.g. "beta") - $null when the tag does not exist
function Get-DistTagVersion {
  param([string]$Package, [string]$Tag)
  try {
    $v = (& npm view $Package "dist-tags.$Tag" --fetch-timeout=8000 --fetch-retries=1 2>$null | Select-Object -Last 1)
    if ($v -and "$v" -match "^\d") { return "$v".Trim() }
  } catch { }
  return $null
}

# Split a semver-ish string into core version + prerelease suffix so that
# "0.3.0-beta.2" and "0.2.5" can be compared correctly.
function Get-VersionParts {
  param([string]$Version)
  $core = $Version
  $suffix = ""
  if ($Version -match "^(?<core>\d+(\.\d+){1,3})(?:-(?<suffix>.+))?$") {
    $core = $matches["core"]
    if ($matches["suffix"]) { $suffix = $matches["suffix"] }
  }
  return @{ Core = $core; Suffix = $suffix }
}

# Compare two package versions (release + prerelease aware).
# Returns -1/0/1 when comparable, $null when they are not.
function Compare-PkgVersion {
  param([string]$A, [string]$B)
  if ([string]::IsNullOrEmpty($A) -or [string]::IsNullOrEmpty($B)) { return $null }
  $pa = Get-VersionParts -Version $A
  $pb = Get-VersionParts -Version $B
  try {
    $ca = [version]$pa.Core
    $cb = [version]$pb.Core
  } catch { return $null }
  $cmp = $ca.CompareTo($cb)
  if ($cmp -ne 0) { return $cmp }
  # same core: a release (no suffix) beats a prerelease
  if ($pa.Suffix -eq $pb.Suffix) { return 0 }
  if ($pa.Suffix -eq "") { return 1 }
  if ($pb.Suffix -eq "") { return -1 }
  # both prerelease: compare segment by segment
  $aseg = $pa.Suffix.Split(".")
  $bseg = $pb.Suffix.Split(".")
  $n = [Math]::Min($aseg.Length, $bseg.Length)
  for ($i = 0; $i -lt $n; $i++) {
    $ai = 0; $bi = 0
    $aiIsNum = [int]::TryParse($aseg[$i], [ref]$ai)
    $biIsNum = [int]::TryParse($bseg[$i], [ref]$bi)
    if ($aiIsNum -and $biIsNum) {
      if ($ai -ne $bi) { return $ai.CompareTo($bi) }
    } else {
      $c = [string]::Compare($aseg[$i], $bseg[$i], [System.StringComparison]::OrdinalIgnoreCase)
      if ($c -ne 0) { return $c }
    }
  }
  return $aseg.Length.CompareTo($bseg.Length)
}

# Newest of two versions (prerelease aware); falls back to whichever is non-null.
function Select-NewestVersion {
  param([string]$A, [string]$B)
  if ([string]::IsNullOrEmpty($A)) { return $B }
  if ([string]::IsNullOrEmpty($B)) { return $A }
  $cmp = Compare-PkgVersion -A $A -B $B
  if ($null -eq $cmp) { return $A }
  if ($cmp -ge 0) { return $A }
  return $B
}

function Test-VersionOutdated {
  param([string]$Installed, [string]$Latest)
  if (-not $Installed -or -not $Latest) { return $false }
  $cmp = Compare-PkgVersion -A $Installed -B $Latest
  if ($null -eq $cmp) { return $false }
  return ($cmp -lt 0)
}

function Test-Health {
  param([string]$Url)
  try {
    $r = Invoke-RestMethod $Url -TimeoutSec 5
    return ($null -ne $r -and $r.status -eq "ok")
  } catch {
    return $false
  }
}

function Get-RunKeyValue {
  param([string]$Name)
  return (Get-ItemProperty $RunKeyPath -Name $Name -ErrorAction SilentlyContinue).$Name
}

function Get-FirewallAllow {
  param([int]$Port)
  try {
    $rules = Get-NetFirewallRule -Direction Inbound -Action Allow -Enabled True -ErrorAction Stop
    foreach ($rule in $rules) {
      $pf = $rule | Get-NetFirewallPortFilter -ErrorAction SilentlyContinue
      if ($pf -and $pf.Protocol -eq "TCP" -and ($pf.LocalPort -eq "$Port")) { return $true }
    }
    return $false
  } catch {
    return $null # unknown (cmdlets may need elevation)
  }
}

# ---------- report ----------
$script:Checks = [System.Collections.Generic.List[object]]::new()

function Add-Check {
  param([string]$Service, [string]$Check, [bool]$Ok, [string]$Detail = "")
  $script:Checks.Add([pscustomobject]@{
    Service = $Service
    Check   = $Check
    Ok      = $Ok
    Detail  = $Detail
  })
}

function Add-Warn {
  param([string]$Service, [string]$Check, [string]$Detail = "")
  $script:Checks.Add([pscustomobject]@{
    Service = $Service
    Check   = $Check
    Ok      = $true
    Warn    = $true
    Detail  = $Detail
  })
}

function Write-CheckResult {
  param([object]$Check)
  if ($Check.Warn) {
    $detail = if ($Check.Detail) { " - $($Check.Detail)" } else { "" }
    Write-Host ("  {0,-28}: WARN{1}" -f $Check.Check, $detail) -ForegroundColor Yellow
    return
  }
  $color = if ($Check.Ok) { "Green" } else { "Red" }
  $mark  = if ($Check.Ok) { "ok  " } else { "FAIL" }
  $detail = if ($Check.Detail) { " - $($Check.Detail)" } else { "" }
  Write-Host ("  {0,-28}: {1}{2}" -f $Check.Check, $mark, $detail) -ForegroundColor $color
}

function Write-StatusReport {
  $services = @("OpenCode", "OpenChamber", "Paseo")
  foreach ($svc in $services) {
    $rows = @($script:Checks | Where-Object { $_.Service -eq $svc })
    if ($rows.Count -eq 0) { continue }
    Write-Host ""
    Write-Host $svc -ForegroundColor Cyan
    foreach ($check in $rows) { Write-CheckResult $check }
  }
  $issues = @($script:Checks | Where-Object { -not $_.Ok })
  Write-Host ""
  if ($issues.Count -eq 0) {
    Write-Host "All checks passed." -ForegroundColor Green
  } else {
    Write-Host "$($issues.Count) issue(s) found. Run: $PSScriptRoot\check-dev-stack.ps1 fix" -ForegroundColor Yellow
  }
}

# ---------- status collection ----------
function Collect-Status {
  $script:Checks.Clear()
  $latest = @{
    opencode    = $null
    openchamber = $null
    paseo       = $null
    paseoLatest = $null
    paseoBeta   = $null
  }

  if (-not $Quiet) {
    Write-Host "Checking latest versions on npm..." -ForegroundColor DarkGray
  }
  $latest.opencode    = Get-LatestVersion -Package $PkgOpenCode
  $latest.openchamber = Get-LatestVersion -Package $PkgOpenChamber
  # paseo: consider both the stable (latest) and the beta dist-tag, prefer newest
  $latest.paseoLatest = Get-LatestVersion -Package $PkgPaseo
  $latest.paseoBeta   = Get-DistTagVersion -Package $PkgPaseo -Tag "beta"
  $latest.paseo       = Select-NewestVersion -A $latest.paseoLatest -B $latest.paseoBeta

  # ----- opencode -----
  $ocPath = Get-CommandSource "opencode"
  Add-Check "OpenCode" "CLI present" (-not [string]::IsNullOrEmpty($ocPath)) $ocPath
  if ($ocPath) {
    Add-Check "OpenCode" "CLI (not desktop app)" (Test-NpmInstalledCli $ocPath) $ocPath
  }
  $ocBin = Get-NpmBinary -ShimPath $ocPath -PackageRel $OpenCodeBinRel
  Add-Check "OpenCode" "Binary" ($null -ne $ocBin) $(if ($ocBin) { $ocBin } else { "not found under npm node_modules" })
  $ocVer = Get-Version -Name "opencode"
  if ($ocVer) { $ocVer = "$ocVer".Trim() }
  Add-Check "OpenCode" "Version" (-not [string]::IsNullOrEmpty($ocVer)) $ocVer
  if ($ocVer -and $latest.opencode) {
    if (Test-VersionOutdated -Installed $ocVer -Latest $latest.opencode) {
      Add-Check "OpenCode" "Up to date" $false "installed $ocVer, latest $($latest.opencode)"
    } else {
      Add-Check "OpenCode" "Up to date" $true "latest $($latest.opencode)"
    }
  } elseif ($latest.opencode) {
    Add-Check "OpenCode" "Up to date" $false "latest $($latest.opencode)"
  } else {
    Add-Check "OpenCode" "Up to date" $false "could not query npm (offline?)"
  }

  # ----- openchamber -----
  $ocShim = Get-CommandSource "openchamber"
  Add-Check "OpenChamber" "CLI present" (-not [string]::IsNullOrEmpty($ocShim)) $ocShim
  if ($ocShim) {
    Add-Check "OpenChamber" "CLI (not desktop app)" (Test-NpmInstalledCli $ocShim) $ocShim
  }
  $ocServerBin = Get-NpmBinary -ShimPath $ocShim -PackageRel $OpenChamberBinRel
  Add-Check "OpenChamber" "Binary" ($null -ne $ocServerBin) $(if ($ocServerBin) { $ocServerBin } else { "not found under npm node_modules" })
  $ocVer = Get-Version -Name "openchamber"
  if ($ocVer) { $ocVer = "$ocVer".Trim() }
  Add-Check "OpenChamber" "Version" (-not [string]::IsNullOrEmpty($ocVer)) $ocVer
  if ($ocVer -and $latest.openchamber) {
    if (Test-VersionOutdated -Installed $ocVer -Latest $latest.openchamber) {
      Add-Check "OpenChamber" "Up to date" $false "installed $ocVer, latest $($latest.openchamber)"
    } else {
      Add-Check "OpenChamber" "Up to date" $true "latest $($latest.openchamber)"
    }
  } elseif ($latest.openchamber) {
    Add-Check "OpenChamber" "Up to date" $false "latest $($latest.openchamber)"
  } else {
    Add-Check "OpenChamber" "Up to date" $false "could not query npm (offline?)"
  }

  $ocPid = Get-ListeningPid -Port $OpenChamberPort
  Add-Check "OpenChamber" "Running" ($null -ne $ocPid) $(if ($ocPid) { "pid $ocPid on port $OpenChamberPort" } else { "not listening on $OpenChamberPort" })
  if ($ocPid) {
    $cmdline = Get-ProcessCommandLine -ProcessId $ocPid
    $runningBin = if ($cmdline -match "node_modules\\(?<bin>@openchamber\\.*?cli\.js)") { "node_modules\$($matches['bin'])" } else { $cmdline }
    if ($cmdline -match "cli\.js") {
      Add-Check "OpenChamber" "Server (not desktop app)" $true "cli.js serve"
    } else {
      Add-Check "OpenChamber" "Server (not desktop app)" $false "process is not the npm cli.js server"
    }
    Add-Check "OpenChamber" "Running binary" $true $runningBin
    Add-Check "OpenChamber" "All interfaces (0.0.0.0)" $true "listening on 0.0.0.0:$OpenChamberPort"
    Add-Check "OpenChamber" "Health" (Test-Health "http://localhost:$OpenChamberPort/health") "http://localhost:$OpenChamberPort/health"
  } else {
    Add-Check "OpenChamber" "All interfaces (0.0.0.0)" $false "not running"
    Add-Check "OpenChamber" "Health" $false "not running"
  }

  # openchamber autostart: Run key + settings autoStart + wrapper files
  # autoStart defaults to $true when the key is absent (mirrors openchamber.ps1 Read-Settings)
  $runValue = Get-RunKeyValue -Name $OpenChamberRunKey
  $settingsPath = Join-Path $env:USERPROFILE ".config\openchamber\settings.json"
  $autoStart = $true
  if (Test-Path -LiteralPath $settingsPath) {
    try {
      $autoStartValue = (Get-Content -LiteralPath $settingsPath -Raw | ConvertFrom-Json).autoStart
      if ($null -ne $autoStartValue) { $autoStart = [bool]$autoStartValue }
    } catch { }
  }
  $wrapperDir = Join-Path $env:USERPROFILE ".config\openchamber"
  $wrappersOk = (Test-Path (Join-Path $wrapperDir "startup.ps1")) -and (Test-Path (Join-Path $wrapperDir "launch.vbs"))
  $autoStartOk = $runValue -and $autoStart -and $wrappersOk
  Add-Check "OpenChamber" "Autostart at login" $autoStartOk $(if ($autoStartOk) { "HKCU Run key + autoStart + wrappers" } else { "Run key: $(if ($runValue) {'set'} else {'MISSING'}), autoStart: $autoStart, wrappers: $wrappersOk" })

  # openchamber UI password (env var, needed for remote access)
  $ocPwd = [Environment]::GetEnvironmentVariable("OPENCHAMBER_UI_PASSWORD", "User")
  Add-Check "OpenChamber" "UI password set" (-not [string]::IsNullOrEmpty($ocPwd)) $(if ($ocPwd) { "OPENCHAMBER_UI_PASSWORD set (env)" } else { "OPENCHAMBER_UI_PASSWORD not set - UI exposed without auth" })

  $firewall7777 = Get-FirewallAllow -Port $OpenChamberPort
  if ($null -eq $firewall7777) {
    Add-Warn "OpenChamber" "Firewall allows 7777" "could not determine (run elevated to check)"
  } elseif ($firewall7777) {
    Add-Check "OpenChamber" "Firewall allows 7777" $true "inbound allow rule present"
  } else {
    Add-Check "OpenChamber" "Firewall allows 7777" $false "no inbound allow rule found"
  }

  # ----- paseo -----
  $paseoShim = Get-CommandSource "paseo"
  Add-Check "Paseo" "CLI present" (-not [string]::IsNullOrEmpty($paseoShim)) $paseoShim
  if ($paseoShim) {
    Add-Check "Paseo" "CLI (not desktop app)" (Test-NpmInstalledCli $paseoShim) $paseoShim
  }
  $paseoBin = Get-NpmBinary -ShimPath $paseoShim -PackageRel $PaseoBinRel
  Add-Check "Paseo" "Binary" ($null -ne $paseoBin) $(if ($paseoBin) { $paseoBin } else { "not found under npm node_modules" })
  $paseoVer = Get-Version -Name "paseo"
  if ($paseoVer) { $paseoVer = "$paseoVer".Trim() }
  Add-Check "Paseo" "Version" (-not [string]::IsNullOrEmpty($paseoVer)) $paseoVer
  $paseoDetail = "latest $($latest.paseoLatest), beta $($latest.paseoBeta)"
  if ($paseoVer -and $latest.paseo) {
    if (Test-VersionOutdated -Installed $paseoVer -Latest $latest.paseo) {
      Add-Check "Paseo" "Up to date" $false "installed $paseoVer, available $($latest.paseo) ($paseoDetail)"
    } else {
      Add-Check "Paseo" "Up to date" $true "available $($latest.paseo) ($paseoDetail)"
    }
  } elseif ($latest.paseo) {
    Add-Check "Paseo" "Up to date" $false "available $($latest.paseo) ($paseoDetail)"
  } else {
    Add-Check "Paseo" "Up to date" $false "could not query npm (offline?)"
  }

  $paseoPid = Get-ListeningPid -Port $PaseoPort
  Add-Check "Paseo" "Daemon running" ($null -ne $paseoPid) $(if ($paseoPid) { "pid $paseoPid on port $PaseoPort" } else { "not listening on $PaseoPort" })
  if ($paseoPid) {
    $cmdline = Get-ProcessCommandLine -ProcessId $paseoPid
    $runningBin = if ($cmdline -match "node_modules\\(?<bin>@getpaseo\\.*?daemon-worker\.js)") { "node_modules\$($matches['bin'])" } else { $cmdline }
    if ($cmdline -match "daemon-worker") {
      Add-Check "Paseo" "Daemon (not desktop app)" $true "daemon-worker.js"
    } else {
      Add-Check "Paseo" "Daemon (not desktop app)" $false "process is not the npm daemon-worker"
    }
    Add-Check "Paseo" "Running binary" $true $runningBin
    Add-Check "Paseo" "All interfaces (0.0.0.0)" $true "listening on 0.0.0.0:$PaseoPort"
    Add-Check "Paseo" "Health" (Test-Health "http://localhost:$PaseoPort/api/health") "http://localhost:$PaseoPort/api/health"
  } else {
    Add-Check "Paseo" "All interfaces (0.0.0.0)" $false "not running"
    Add-Check "Paseo" "Health" $false "not running"
  }

  # paseo autostart: scheduled task
  $task = Get-ScheduledTask -TaskName $PaseoTaskName -ErrorAction SilentlyContinue
  $taskOk = $null -ne $task -and $task.State -ne "Disabled"
  Add-Check "Paseo" "Autostart at login" $taskOk $(if ($taskOk) { "scheduled task $PaseoTaskName ($($task.State))" } else { "scheduled task $PaseoTaskName MISSING/disabled" })

  # paseo config: listen on 0.0.0.0 + web UI enabled
  $paseoCfg = Join-Path $env:USERPROFILE ".paseo\config.json"
  $cfgListenOk = $false
  $cfgWebUiOk = $false
  if (Test-Path -LiteralPath $paseoCfg) {
    try {
      $cfg = Get-Content -LiteralPath $paseoCfg -Raw | ConvertFrom-Json
      $cfgListenOk = "$($cfg.daemon.listen)" -eq "0.0.0.0:$PaseoPort"
      $cfgWebUiOk = $null -ne $cfg.features.webUi -and $cfg.features.webUi.enabled
    } catch { }
  }
  Add-Check "Paseo" "Config listen 0.0.0.0" $cfgListenOk $(if ($cfgListenOk) { "daemon.listen = 0.0.0.0:$PaseoPort" } else { "daemon.listen is not 0.0.0.0:$PaseoPort" })
  Add-Check "Paseo" "Web UI enabled" $cfgWebUiOk $(if ($cfgWebUiOk) { "features.webUi.enabled = true" } else { "features.webUi not enabled" })

  # paseo daemon password (config auth.password, needed for binding beyond localhost)
  $cfgPwdOk = $false
  if (Test-Path -LiteralPath $paseoCfg) {
    try {
      $cfg = Get-Content -LiteralPath $paseoCfg -Raw | ConvertFrom-Json
      $cfgPwdOk = -not [string]::IsNullOrEmpty("$($cfg.daemon.auth.password)")
    } catch { }
  }
  Add-Check "Paseo" "Password set" $cfgPwdOk $(if ($cfgPwdOk) { "daemon.auth.password in config" } else { "no auth password - run 'paseo daemon set-password' (required when listening on 0.0.0.0)" })

  # paseo desktop app: report version alongside the CLI, advisory only for the
  # built-in daemon flag (never auto-corrected by the script)
  $paseoDesktopExe = Join-Path $env:LOCALAPPDATA "Programs\Paseo\Paseo.exe"
  $paseoDesktopSettings = Join-Path $env:APPDATA "Paseo\desktop-settings.json"
  $desktopInstalled = Test-Path -LiteralPath $paseoDesktopExe
  $desktopVer = if ($desktopInstalled) { Get-FileVersion -Path $paseoDesktopExe } else { $null }
  if ($desktopInstalled) {
    Add-Check "Paseo" "Desktop version" $true $desktopVer
    if ($desktopVer -and $latest.paseo) {
      if (Test-VersionOutdated -Installed $desktopVer -Latest $latest.paseo) {
        Add-Check "Paseo" "Desktop up to date" $false "installed $desktopVer, available $($latest.paseo) ($paseoDetail)"
      } else {
        Add-Check "Paseo" "Desktop up to date" $true "available $($latest.paseo) ($paseoDetail)"
      }
    }
  }
  $manageBuiltIn = $null
  if ($desktopInstalled -and (Test-Path -LiteralPath $paseoDesktopSettings)) {
    try {
      $manageBuiltIn = (Get-Content -LiteralPath $paseoDesktopSettings -Raw | ConvertFrom-Json).settings.daemon.manageBuiltInDaemon
    } catch { }
  }
  if (-not $desktopInstalled) {
    Add-Check "Paseo" "Desktop app (no built-in daemon)" $true "not installed - CLI daemon is the only daemon"
  } elseif ($manageBuiltIn -eq $false) {
    Add-Check "Paseo" "Desktop app (no built-in daemon)" $true "manageBuiltInDaemon = false (connects to CLI daemon)"
  } else {
    Add-Warn "Paseo" "Desktop app (no built-in daemon)" "manageBuiltInDaemon is $manageBuiltIn - disable it manually in the desktop app (Settings -> Daemon) to avoid two daemons (desktop + headless CLI)"
  }

  $firewall6767 = Get-FirewallAllow -Port $PaseoPort
  if ($null -eq $firewall6767) {
    Add-Warn "Paseo" "Firewall allows 6767" "could not determine (run elevated to check)"
  } elseif ($firewall6767) {
    Add-Check "Paseo" "Firewall allows 6767" $true "inbound allow rule present"
  } else {
    Add-Check "Paseo" "Firewall allows 6767" $false "no inbound allow rule found"
  }
}

function Get-IssueCount {
  return @($script:Checks | Where-Object { -not $_.Ok }).Count
}

# ---------- ensure (idempotent: running + autostart + config) ----------
function Invoke-Ensure {
  # openchamber: not running -> start
  if (-not (Get-ListeningPid -Port $OpenChamberPort)) {
    Write-Host "Starting OpenChamber..." -ForegroundColor Yellow
    Safe-Invoke -What "Starting OpenChamber" -Body { & (Join-Path $PSScriptRoot "openchamber.ps1") start }
  }
  # openchamber autostart -> configure re-registers Run key + wrappers
  if (-not (Get-RunKeyValue -Name $OpenChamberRunKey)) {
    Write-Host "Registering OpenChamber autostart..." -ForegroundColor Yellow
    Safe-Invoke -What "Registering OpenChamber autostart" -Body { & (Join-Path $PSScriptRoot "openchamber.ps1") configure }
  }
  # openchamber settings host -> 0.0.0.0 (targeted edit, prompted unless -Force)
  $settingsPath = Join-Path $env:USERPROFILE ".config\openchamber\settings.json"
  if (Test-Path -LiteralPath $settingsPath) {
    $raw = Get-Content -LiteralPath $settingsPath -Raw
    if ($raw -match '"host"\s*:\s*"[^"]*"' -and $raw -notmatch '"host"\s*:\s*"0\.0\.0\.0"') {
      if (-not $Force) {
        $choice = Read-Choice -Prompt "OpenChamber settings host is not 0.0.0.0. Fix it? [Y]es, [N]o?" -ValidChoices @("Y", "N")
        if ($choice -eq "N") { return }
      }
      $fixed = $raw -replace '"host"\s*:\s*"[^"]*"', '"host": "0.0.0.0"'
      Set-Content -LiteralPath $settingsPath -Value $fixed -Encoding UTF8 -NoNewline
      Write-Host "Set openchamber host to 0.0.0.0. Re-running configure..." -ForegroundColor Yellow
      Safe-Invoke -What "Re-running OpenChamber configure" -Body { & (Join-Path $PSScriptRoot "openchamber.ps1") configure }
    }
  }
  # openchamber UI password reminder
  $ocPwdEnv = [Environment]::GetEnvironmentVariable("OPENCHAMBER_UI_PASSWORD", "User")
  $ocPwdSettings = ""
  if (Test-Path -LiteralPath $settingsPath) {
    try { $ocPwdSettings = "$((Get-Content -LiteralPath $settingsPath -Raw | ConvertFrom-Json).password)" } catch { }
  }
  if ([string]::IsNullOrEmpty($ocPwdEnv) -and [string]::IsNullOrEmpty($ocPwdSettings)) {
    Write-Host "OpenChamber has no UI password yet - set one manually (UI is exposed without auth on 0.0.0.0):" -ForegroundColor Yellow
    Write-Host "  [Environment]::SetEnvironmentVariable('OPENCHAMBER_UI_PASSWORD', 'yourpassword', 'User')" -ForegroundColor Cyan
  }

  # paseo: daemon not running -> start
  if (-not (Get-ListeningPid -Port $PaseoPort)) {
    Write-Host "Starting Paseo daemon..." -ForegroundColor Yellow
    Safe-Invoke -What "Starting Paseo daemon" -Body { Invoke-PaseoDaemon start }
  }
  # paseo autostart -> register scheduled task
  $task = Get-ScheduledTask -TaskName $PaseoTaskName -ErrorAction SilentlyContinue
  if (-not $task) {
    Write-Host "Registering PaseoDaemon scheduled task..." -ForegroundColor Yellow
    $nodePath = (Get-Command node).Source
    $paseoBin = Join-Path $env:APPDATA "npm\node_modules\@getpaseo\cli\bin\paseo"
    if (Test-Path -LiteralPath $paseoBin) {
      $action = New-ScheduledTaskAction -Execute $nodePath -Argument "--disable-warning=DEP0040 `"$paseoBin`" daemon start"
      $trigger = New-ScheduledTaskTrigger -AtLogOn -User $env:USERNAME
      $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries
      Safe-Invoke -What "Registering PaseoDaemon scheduled task" -Body {
        Register-ScheduledTask -TaskName $PaseoTaskName -Action $action -Trigger $trigger -Settings $settings -RunLevel Highest -Force | Out-Null
        Write-Host "Registered $PaseoTaskName." -ForegroundColor Green
      }
    } else {
      Write-Host "paseo bin not found at $paseoBin - cannot register task. Run 'install' first." -ForegroundColor Red
    }
  }
  # paseo config listen -> 0.0.0.0 (targeted edit, prompted unless -Force)
  $paseoCfg = Join-Path $env:USERPROFILE ".paseo\config.json"
  if (Test-Path -LiteralPath $paseoCfg) {
    $raw = Get-Content -LiteralPath $paseoCfg -Raw
    $changed = $false
    if ($raw -match '"listen"\s*:\s*"[^"]*"' -and $raw -notmatch '"listen"\s*:\s*"0\.0\.0\.0:6767"') {
      if (-not $Force) {
        $choice = Read-Choice -Prompt "Paseo daemon.listen is not 0.0.0.0:6767. Fix it? [Y]es, [N]o?" -ValidChoices @("Y", "N")
        if ($choice -eq "N") { return }
      }
      $raw = $raw -replace '"listen"\s*:\s*"[^"]*"', '"listen": "0.0.0.0:6767"'
      $changed = $true
    }
    if ($raw -match '"webUi"\s*:\s*\{\s*"enabled"\s*:\s*false') {
      if (-not $Force) {
        $choice = Read-Choice -Prompt "Paseo webUi is disabled. Enable it? [Y]es, [N]o?" -ValidChoices @("Y", "N")
        if ($choice -eq "N") { return }
      }
      $raw = $raw -replace '"webUi"\s*:\s*\{\s*"enabled"\s*:\s*false', '"webUi": { "enabled": true'
      $changed = $true
    }
    if ($changed) {
      Set-Content -LiteralPath $paseoCfg -Value $raw -Encoding UTF8 -NoNewline
      Write-Host "Updated paseo config.json. Restarting daemon..." -ForegroundColor Yellow
      Safe-Invoke -What "Restarting Paseo daemon" -Body { Invoke-PaseoDaemon restart }
    }
  }
  # paseo password reminder (interactive step, cannot be automated)
  if (Test-Path -LiteralPath $paseoCfg) {
    try {
      $cfg = Get-Content -LiteralPath $paseoCfg -Raw | ConvertFrom-Json
      $cfgPwdOk = -not [string]::IsNullOrEmpty("$($cfg.daemon.auth.password)")
    } catch { $cfgPwdOk = $false }
    if (-not $cfgPwdOk) {
      Write-Host "Paseo has no auth password yet - set one manually (required when listening on 0.0.0.0):" -ForegroundColor Yellow
      Write-Host "  paseo daemon set-password" -ForegroundColor Cyan
    }
  }
  # paseo desktop app: advisory only - never modify the desktop app's own
  # settings. If it manages a built-in daemon, warn so the user can disable
  # it manually (two daemons must not run side by side).
  $paseoDesktopExe = Join-Path $env:LOCALAPPDATA "Programs\Paseo\Paseo.exe"
  $paseoDesktopSettings = Join-Path $env:APPDATA "Paseo\desktop-settings.json"
  if (Test-Path -LiteralPath $paseoDesktopExe) {
    if (-not (Test-Path -LiteralPath $paseoDesktopSettings)) {
      Write-Host "Paseo desktop is installed but desktop-settings.json was not found." -ForegroundColor Yellow
      Write-Host "Recommendation: disable 'Manage built-in daemon' in the desktop app (Settings -> Daemon) so only the CLI daemon runs." -ForegroundColor Yellow
    } else {
      $manageBuiltIn = $null
      try {
        $manageBuiltIn = (Get-Content -LiteralPath $paseoDesktopSettings -Raw | ConvertFrom-Json).settings.daemon.manageBuiltInDaemon
      } catch { }
      if ($manageBuiltIn -ne $false) {
        Write-Host "Recommendation: Paseo desktop is set to manage its own built-in daemon (manageBuiltInDaemon is $manageBuiltIn)." -ForegroundColor Yellow
        Write-Host "Disable it manually in the desktop app (Settings -> Daemon) to avoid two daemons running side by side (desktop + headless CLI)." -ForegroundColor Yellow
      }
    }
  }
}

# ---------- install (explicit: install latest + configure everything) ----------
function Invoke-Install {
  $paseoLatest = Get-LatestVersion -Package $PkgPaseo
  $paseoBeta   = Get-DistTagVersion -Package $PkgPaseo -Tag "beta"
  $latest = @{
    opencode    = Get-LatestVersion -Package $PkgOpenCode
    openchamber = Get-LatestVersion -Package $PkgOpenChamber
    paseo       = Select-NewestVersion -A $paseoLatest -B $paseoBeta
  }
  if (-not $latest.opencode -or -not $latest.openchamber -or -not $latest.paseo) {
    Write-Host "Could not reach npm registry - install aborted." -ForegroundColor Red
    exit 2
  }

  $toUpdate = @()
  $ocVer = Get-Version -Name "opencode"
  $ocShimVer = Get-Version -Name "openchamber"
  $paseoVer = Get-Version -Name "paseo"

  if (-not $ocVer -or (Test-VersionOutdated -Installed $ocVer -Latest $latest.opencode)) {
    $toUpdate += "opencode"; Write-Host "OpenCode: $(if ($ocVer) { "$ocVer -> $($latest.opencode)" } else { "NOT INSTALLED -> installing $($latest.opencode)" })" -ForegroundColor Yellow
  } else {
    Write-Host "OpenCode: up to date ($ocVer)" -ForegroundColor Green
  }
  if (-not $ocShimVer -or (Test-VersionOutdated -Installed $ocShimVer -Latest $latest.openchamber)) {
    $toUpdate += "openchamber"; Write-Host "OpenChamber: $(if ($ocShimVer) { "$ocShimVer -> $($latest.openchamber)" } else { "NOT INSTALLED -> installing $($latest.openchamber)" })" -ForegroundColor Yellow
  } else {
    Write-Host "OpenChamber: up to date ($ocShimVer)" -ForegroundColor Green
  }
  if (-not $paseoVer -or (Test-VersionOutdated -Installed $paseoVer -Latest $latest.paseo)) {
    $paseoTag = if ($latest.paseo -eq $paseoBeta) { "beta" } else { "latest" }
    $toUpdate += "paseo"; Write-Host "Paseo: $(if ($paseoVer) { "$paseoVer -> $($latest.paseo) ($paseoTag)" } else { "NOT INSTALLED -> installing $($latest.paseo) ($paseoTag)" })" -ForegroundColor Yellow
  } else {
    Write-Host "Paseo: up to date ($paseoVer)" -ForegroundColor Green
  }

  if ($toUpdate.Count -gt 0) {
    Write-Host ""
    if (-not $Force) {
      $choice = Read-Choice -Prompt "Install/update $($toUpdate -join ', ')? [Y]es, [N]o?" -ValidChoices @("Y", "N")
      if ($choice -eq "N") { exit 0 }
    }

    $scripts = @{
      opencode    = "install-opencode-cli.ps1"
      openchamber = "install-openchamber.ps1"
      paseo       = "install-paseo-cli.ps1"
    }
    foreach ($tool in $toUpdate) {
      Write-Host ""
      Write-Host "=== Updating $tool ===" -ForegroundColor Cyan
      $scriptPath = Join-Path $PSScriptRoot $scripts[$tool]
      if (Test-Path -LiteralPath $scriptPath) {
        & $scriptPath
      } else {
        Write-Host "Installer not found: $scriptPath - update $tool manually." -ForegroundColor Red
      }
    }

    # installers stop daemons; bring them back up
    Write-Host ""
    if ($toUpdate -contains "openchamber") {
      Write-Host "Restarting OpenChamber..." -ForegroundColor Cyan
      Safe-Invoke -What "Restarting OpenChamber" -Body { & (Join-Path $PSScriptRoot "openchamber.ps1") start }
    }
    if ($toUpdate -contains "paseo") {
      Write-Host "Restarting Paseo daemon..." -ForegroundColor Cyan
      Safe-Invoke -What "Restarting Paseo daemon" -Body { Invoke-PaseoDaemon start }
    }
  } else {
    Write-Host ""
    Write-Host "Everything is already up to date." -ForegroundColor Green
  }

  # always: ensure autostarts + config are in place (idempotent)
  Write-Host ""
  Write-Host "Ensuring autostart + config..." -ForegroundColor Cyan
  Invoke-Ensure

  Write-Host ""
  Write-Host "Install finished. Verifying..." -ForegroundColor Cyan
  Collect-Status
  Write-StatusReport
}

# ---------- fix ----------
function Invoke-Fix {
  Collect-Status
  $issues = @($script:Checks | Where-Object { -not $_.Ok -and $_.Service -ne "OpenCode" })
  if ($issues.Count -eq 0) {
    Write-Host "No runtime issues to fix." -ForegroundColor Green
    exit 0
  }

  Write-Host "Fixing runtime state..." -ForegroundColor Cyan
  Invoke-Ensure

  Write-Host ""
  Write-Host "Fix finished. Verifying..." -ForegroundColor Cyan
  Collect-Status
  Write-StatusReport
}

# ---------- start / stop ----------
function Invoke-Start {
  if (-not (Get-ListeningPid -Port $OpenChamberPort)) {
    Write-Host "Starting OpenChamber..." -ForegroundColor Cyan
    Safe-Invoke -What "Starting OpenChamber" -Body { & (Join-Path $PSScriptRoot "openchamber.ps1") start }
  } else {
    Write-Host "OpenChamber already running." -ForegroundColor Green
  }
  if (-not (Get-ListeningPid -Port $PaseoPort)) {
    Write-Host "Starting Paseo daemon..." -ForegroundColor Cyan
    Safe-Invoke -What "Starting Paseo daemon" -Body { Invoke-PaseoDaemon start }
  } else {
    Write-Host "Paseo daemon already running." -ForegroundColor Green
  }
}

function Invoke-Stop {
  Write-Host "Stopping OpenChamber..." -ForegroundColor Cyan
  Safe-Invoke -What "Stopping OpenChamber" -Body { & (Join-Path $PSScriptRoot "openchamber.ps1") stop }
  Write-Host "Stopping Paseo daemon..." -ForegroundColor Cyan
  Safe-Invoke -What "Stopping Paseo daemon" -Body { & paseo daemon stop }
}

# ---------- help ----------
function Show-Help {
  $exe = "check-dev-stack.ps1"
  Write-Host "Usage: .\$exe [command] [options]" -ForegroundColor Cyan
  Write-Host ""
  Write-Host "Supervisor for the dev stack (OpenCode, OpenChamber, Paseo):" -ForegroundColor White
  Write-Host "checks install state, runs services, keeps autostart + config healthy."
  Write-Host ""
  Write-Host "Commands:" -ForegroundColor Cyan
  Write-Host "  status   Check everything and report issues (default). Exits 1 if issues found."
  Write-Host "  install  Install or update all tools to latest, then configure autostart + config."
  Write-Host "  update   Alias for install."
  Write-Host "  fix      Auto-fix runtime issues (start services, register autostart, fix config)."
  Write-Host "  start    Start OpenChamber and the Paseo daemon (if not running)."
  Write-Host "  stop     Stop OpenChamber and the Paseo daemon."
  Write-Host "  help     Show this help."
  Write-Host ""
  Write-Host "Options:" -ForegroundColor Cyan
  Write-Host "  -Command <cmd>  Command to run (same as the positional argument)."
  Write-Host "  -Quiet          Skip the npm latest-version lookups in 'status'."
  Write-Host "  -Force          Apply config fixes without prompting."
  Write-Host ""
  Write-Host "Examples:" -ForegroundColor Cyan
  Write-Host "  .\$exe                  # quick health check"
  Write-Host "  .\$exe fix              # fix whatever is broken"
  Write-Host "  .\$exe install -Force   # install/update everything, no prompts"
  Write-Host "  .\$exe status -Quiet    # offline-friendly status check"
}

# ---------- dispatch ----------
switch ($Command) {
  "status" {
    Collect-Status
    Write-StatusReport
    $count = Get-IssueCount
    exit $(if ($count -eq 0) { 0 } else { 1 })
  }
  "install" { Invoke-Install }
  "update"  { Invoke-Install }
  "fix"     { Invoke-Fix }
  "start"   { Invoke-Start }
  "stop"    { Invoke-Stop }
  "help"    { Show-Help }
}

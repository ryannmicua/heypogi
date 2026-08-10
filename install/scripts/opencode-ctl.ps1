[CmdletBinding()]
param(
  [Parameter(Position = 0)]
  [string]$Command = "status",
  [switch]$Quiet,
  [switch]$Force,
  [switch]$WipeConfig,
  [Alias("h")]
  [switch]$Help
)

$ValidCommands = @("install", "update", "status", "uninstall", "help")

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

function Get-NpmRoot {
  return (& npm root -g 2>$null | Select-Object -Last 1)
}

# ---------- install / update ----------
function Invoke-Install {
  # ---------- prereqs ----------
  $hasNode = Get-Command "node" -ErrorAction SilentlyContinue
  $hasNpm  = Get-Command "npm"  -ErrorAction SilentlyContinue
  if (-not $hasNode -or -not $hasNpm) {
    Write-Host "Node.js / npm is required. Install from https://nodejs.org then re-run." -ForegroundColor Red
    exit 1
  }

  # ---------- require npm 12+ (for --allow-scripts) ----------
  $npmVersion = (& npm --version 2>$null | Select-Object -Last 1)
  if (-not $npmVersion -or [version]$npmVersion -lt [version]"12.0.0") {
    Write-Host "npm 12+ is required for the --allow-scripts flag. Current: $npmVersion" -ForegroundColor Red
    Write-Host "Update with: npm install -g npm@latest" -ForegroundColor Yellow
    exit 1
  }

  # ---------- kill running opencode ----------
  $procs = Get-Process "opencode" -ErrorAction SilentlyContinue
  if ($procs) {
    if (-not $Quiet) {
      Write-Host "OpenCode is currently running. It must be closed before updating." -ForegroundColor Yellow
      $choice = Read-Choice -Prompt "Close opencode processes and continue? [Y]es, [N]o?" -ValidChoices @("Y", "N")
      if ($choice -eq "N") { exit 0 }
    }
    $procs | Stop-Process -Force
    Write-Host "Stopped $($procs.Count) opencode process(es)." -ForegroundColor Cyan
  }

  # ---------- detect current version ----------
  $currentVersion = $null
  $currentPath = Get-Command "opencode" -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source
  if ($currentPath) {
    $currentVersion = & "opencode" "--version" 2>$null
    if (-not $currentVersion) { $currentVersion = $null }
  }

  if (-not $Quiet) {
    if ($currentVersion) {
      Write-Host "Current: opencode $currentVersion" -ForegroundColor Green
    } else {
      Write-Host "OpenCode not installed yet." -ForegroundColor Yellow
    }
  }

  $out = & {
    $ErrorActionPreference = "Continue"
    npm install -g opencode-ai@latest --allow-scripts=opencode-ai 2>&1
  }
  $exitCode = $LASTEXITCODE
  $outString = $out | Out-String

  if ($exitCode -ne 0) {
    Write-Host ""
    Write-Host $outString -ForegroundColor Red
    Write-Host "npm install failed (exit $exitCode)." -ForegroundColor Red
    exit $exitCode
  }

  # ---------- verify (self-heal if postinstall didn't run, e.g. older npm ignoring --allow-scripts) ----------
  $npmRoot = Get-NpmRoot
  $binPath = if ($npmRoot) { Join-Path $npmRoot "opencode-ai\bin\opencode.exe" } else { $null }
  if ($binPath -and (Test-Path $binPath)) {
    $header = [System.IO.File]::ReadAllBytes($binPath) | Select-Object -First 2
    $isPe = ($header.Count -eq 2 -and $header[0] -eq 0x4D -and $header[1] -eq 0x5A) # "MZ"
    if (-not $isPe) {
      if (-not $Quiet) {
        Write-Host "opencode.exe is a stub (postinstall didn't run) - running it manually..." -ForegroundColor Yellow
      }
      $postinstallDir = Join-Path $npmRoot "opencode-ai"
      Push-Location $postinstallDir
      try {
        node postinstall.mjs
      } finally {
        Pop-Location
      }
    }
  }

  $newVersion = & "opencode" "--version" 2>$null
  if (-not $newVersion) {
    Write-Host "Install succeeded but 'opencode --version' failed. Check your PATH." -ForegroundColor Yellow
    exit 1
  }

  if (-not $Quiet) {
    Write-Host ""
    Write-Host "OpenCode $newVersion installed." -ForegroundColor Green
    if ($currentVersion -and $currentVersion -ne $newVersion) {
      Write-Host "Updated: $currentVersion -> $newVersion" -ForegroundColor Cyan
    }
    Write-Host ""
    Write-Host "Verify with: opencode --version"
  }
}

# ---------- status ----------
function Invoke-Status {
  $cmd = Get-Command "opencode" -ErrorAction SilentlyContinue
  $version = & "opencode" "--version" 2>$null

  Write-Host "OpenCode status" -ForegroundColor Green
  Write-Host "  CLI path        : $(if ($cmd) { $cmd.Source } else { 'NOT INSTALLED - run opencode-ctl.ps1 install' })"
  Write-Host "  Version         : $(if ($version) { $version } else { 'unknown' })"
  $procs = Get-Process "opencode" -ErrorAction SilentlyContinue
  Write-Host "  Running         : $(if ($procs) { "YES ($($procs.Count) process(es))" } else { 'no (opencode has no standalone daemon - it runs as an OpenChamber sidecar or from a terminal)' })"
  Write-Host "  Autostart       : none - OpenCode has no autostart mechanism of its own."
}

# ---------- uninstall ----------
function Invoke-Uninstall {
  $procs = Get-Process "opencode" -ErrorAction SilentlyContinue
  if ($procs) {
    if (-not $Force) {
      Write-Host "OpenCode is currently running." -ForegroundColor Yellow
      $choice = Read-Choice -Prompt "Stop it and continue with uninstall? [Y]es, [N]o?" -ValidChoices @("Y", "N")
      if ($choice -eq "N") { exit 0 }
    }
    $procs | Stop-Process -Force
    Write-Host "Stopped $($procs.Count) opencode process(es)." -ForegroundColor Cyan
  }

  if ($WipeConfig) {
    if (-not $Force) {
      Write-Host "This will also delete OpenCode's own config directory (~/.config/opencode) if present." -ForegroundColor Yellow
      $choice = Read-Choice -Prompt "Are you sure? [Y]es, [N]o?" -ValidChoices @("Y", "N")
      if ($choice -eq "N") { exit 0 }
    }
    $cfgDir = Join-Path $env:USERPROFILE ".config\opencode"
    if (Test-Path -LiteralPath $cfgDir) {
      Remove-Item -LiteralPath $cfgDir -Recurse -Force
      Write-Host "Removed $cfgDir" -ForegroundColor Cyan
    }
  }

  npm uninstall -g opencode-ai 2>&1 | Out-Null
  Write-Host "Uninstalled npm package opencode-ai." -ForegroundColor Cyan
  Write-Host "OpenCode cleanup complete." -ForegroundColor Green
}

# ---------- help ----------
function Invoke-Help {
  Write-Host "opencode-ctl.ps1 - manage the OpenCode CLI install" -ForegroundColor Green
  Write-Host ""
  Write-Host "Usage: opencode-ctl.ps1 [command] [-Quiet] [-Force] [-WipeConfig]"
  Write-Host ""
  Write-Host "Commands:"
  Write-Host "  install    Install/update the opencode-ai npm package."
  Write-Host "  update     Alias for install."
  Write-Host "  status     Show install/running status. (default when no command given)"
  Write-Host "  uninstall  Stop any running opencode process and uninstall the npm package."
  Write-Host "  help       Show this message."
  Write-Host ""
  Write-Host "Flags:"
  Write-Host "  -Quiet       Suppress non-essential output / prompts."
  Write-Host "  -Force       Skip interactive confirmations."
  Write-Host "  -WipeConfig  On uninstall, also delete ~/.config/opencode. Off by default;"
  Write-Host "               always confirms unless -Force is also given."
  Write-Host ""
  Write-Host "OpenCode has no autostart mechanism or standalone daemon - it runs as an"
  Write-Host "OpenChamber sidecar or directly from a terminal, so there is no start/stop."
}

# ---------- dispatch ----------
if ($Command -eq "update") { $Command = "install" }
if ($Help) { $Command = "help" }
$Command = $Command.ToLowerInvariant()
if ($ValidCommands -notcontains $Command) {
  Write-Host "Unknown command '$Command'." -ForegroundColor Red
  Write-Host "Valid commands: $($ValidCommands -join ', ')" -ForegroundColor Yellow
  Write-Host ""
  Invoke-Help
  exit 1
}

switch ($Command) {
  "install"   { Invoke-Install }
  "status"    { Invoke-Status }
  "uninstall" { Invoke-Uninstall }
  "help"      { Invoke-Help }
}

[CmdletBinding()]
param(
  [switch]$Quiet
)

$ErrorActionPreference = "Stop"

# helpers
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

# ---------- prereqs ----------
$hasNode = Get-Command "node" -ErrorAction SilentlyContinue
$hasNpm  = Get-Command "npm"  -ErrorAction SilentlyContinue

if (-not $hasNode -or -not $hasNpm) {
  Write-Host "Node.js / npm is required. Install from https://nodejs.org then re-run." -ForegroundColor Red
  exit 1
}

# ---------- detect current version ----------
$currentVersion = $null
$paseoCmd = Get-Command "paseo" -ErrorAction SilentlyContinue
if ($paseoCmd) {
  $currentVersion = & "paseo" "--version" 2>$null
  if (-not $currentVersion) { $currentVersion = $null }
}

# ---------- daemon handling ----------
# The daemon runs from the installed npm package, so on Windows npm cannot
# replace the files while it is running (EBUSY). Stopping the daemon kills
# any running agents, so we always ask first (unless -Quiet).
$daemonRunning = $false
if ($paseoCmd) {
  & "paseo" "daemon" "status" *> $null
  $daemonRunning = ($LASTEXITCODE -eq 0)
}

$stopDaemon = $false
if ($daemonRunning) {
  if ($Quiet) {
    $agentCount = (& "paseo" "ls" 2>$null | Select-String -Pattern '^\S' | Measure-Object).Count
    if ($agentCount -gt 0) {
      Write-Host "Daemon is running with $agentCount agent(s). Skipping daemon stop; re-run without -Quiet or stop it manually ('paseo daemon stop') before upgrading." -ForegroundColor Yellow
    } else {
      $stopDaemon = $true
    }
  } else {
    Write-Host "The paseo daemon is currently running. Stopping it to upgrade will also stop any running agents." -ForegroundColor Yellow
    $choice = Read-Choice -Prompt "Stop the daemon and continue? [Y]es, [N]o?" -ValidChoices @("Y", "N")
    if ($choice -eq "Y") { $stopDaemon = $true }
  }
}

if ($stopDaemon) {
  & "paseo" "daemon" "stop" *> $null
  if ($LASTEXITCODE -ne 0) {
    Write-Host "Failed to stop the daemon. Stop it manually ('paseo daemon stop') and re-run." -ForegroundColor Red
    exit 1
  }
  Write-Host "Daemon stopped." -ForegroundColor Cyan
}

# ---------- install / update ----------
if (-not $Quiet) {
  if ($currentVersion) {
    Write-Host "Current: paseo $currentVersion" -ForegroundColor Green
  } else {
    Write-Host "Paseo not installed yet." -ForegroundColor Yellow
  }
}

$out = npm install -g @getpaseo/cli@latest 2>&1
$exitCode = $LASTEXITCODE
$outString = $out | Out-String

if ($exitCode -ne 0) {
  Write-Host ""
  Write-Host $outString -ForegroundColor Red
  Write-Host "npm install failed (exit $exitCode)." -ForegroundColor Red
  exit $exitCode
}

# ---------- verify ----------
$newVersion = & "paseo" "--version" 2>$null
if (-not $newVersion) {
  Write-Host "Install succeeded but 'paseo --version' failed. Check your PATH." -ForegroundColor Yellow
  exit 1
}

if (-not $Quiet) {
  Write-Host ""
  Write-Host "Paseo $newVersion installed." -ForegroundColor Green
  if ($currentVersion -and $currentVersion -ne $newVersion) {
    Write-Host "Updated: $currentVersion -> $newVersion" -ForegroundColor Cyan
  }
  if ($stopDaemon) {
    Write-Host ""
    Write-Host "Daemon was stopped for the upgrade. Start it again with: paseo daemon start"
  } elseif ($daemonRunning) {
    Write-Host ""
    Write-Host "Note: the daemon is still running the old version. Restart it to pick up the new one: paseo daemon restart"
  }
  Write-Host ""
  Write-Host "Verify with: paseo --version"
}

[CmdletBinding()]
param(
  [Parameter(Position = 0)]
  [ValidateSet("install", "update", "configure", "serve", "start", "stop", "status", "uninstall", "help")]
  [string]$Command = "install",
  [switch]$Quiet,
  [switch]$Force
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

# ---------- wrapper location ----------
$wrapper = Join-Path $PSScriptRoot "openchamber.ps1"
if (-not (Test-Path -LiteralPath $wrapper)) {
  Write-Host "openchamber.ps1 not found next to this script: $wrapper" -ForegroundColor Red
  exit 1
}

# ---------- non-install commands: pass straight through to openchamber.ps1 ----------
# This script only adds prereq checks and a version banner around install/update.
# For anything else (start, stop, status, ...) just delegate as-is.
if ($Command -ne "install" -and $Command -ne "update") {
  $delegateArgs = @($Command)
  if ($Quiet) { $delegateArgs += "-Quiet" }
  if ($Force) { $delegateArgs += "-Force" }
  & $wrapper @delegateArgs
  exit $LASTEXITCODE
}

# ---------- prereqs ----------
$hasNode = Get-Command "node" -ErrorAction SilentlyContinue
$hasNpm  = Get-Command "npm"  -ErrorAction SilentlyContinue

if (-not $hasNode -or -not $hasNpm) {
  Write-Host "Node.js / npm is required. Install from https://nodejs.org then re-run." -ForegroundColor Red
  exit 1
}

# ---------- detect current version ----------
$currentVersion = & "openchamber" "--version" 2>$null
if (-not $currentVersion) { $currentVersion = $null }

if (-not $Quiet) {
  if ($currentVersion) {
    Write-Host "Current: openchamber $currentVersion" -ForegroundColor Green
  } else {
    Write-Host "OpenChamber not installed yet." -ForegroundColor Yellow
  }
}

# ---------- delegate to the lifecycle wrapper ----------
# openchamber.ps1 handles: stopping a running instance (native modules lock on
# Windows), npm allow-scripts for better-sqlite3/node-pty, the global install,
# and re-running configure (settings file + startup wrappers + Run key).
$delegateArgs = @("install")
if ($Quiet) { $delegateArgs += "-Quiet" }
if ($Force) { $delegateArgs += "-Force" }

& $wrapper @delegateArgs
$exitCode = $LASTEXITCODE
if ($exitCode -ne 0) {
  Write-Host "openchamber.ps1 install failed (exit $exitCode)." -ForegroundColor Red
  exit $exitCode
}

# ---------- verify ----------
$newVersion = & "openchamber" "--version" 2>$null
if (-not $newVersion) {
  Write-Host "Install succeeded but 'openchamber --version' failed. Check your PATH." -ForegroundColor Yellow
  exit 1
}

if (-not $Quiet) {
  Write-Host ""
  Write-Host "OpenChamber $newVersion installed." -ForegroundColor Green
  if ($currentVersion -and $currentVersion -ne $newVersion) {
    Write-Host "Updated: $currentVersion -> $newVersion" -ForegroundColor Cyan
  }
  Write-Host ""
  Write-Host "Start with: $PSScriptRoot\openchamber.ps1 start"
  Write-Host "Verify with: openchamber --version"
}

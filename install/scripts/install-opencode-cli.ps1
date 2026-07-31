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

# ---------- allow postinstall script ----------
npm config set allow-scripts=opencode-ai --location=user 2>$null

# ---------- install / update ----------
if (-not $Quiet) {
  if ($currentVersion) {
    Write-Host "Current: opencode $currentVersion" -ForegroundColor Green
  } else {
    Write-Host "OpenCode not installed yet." -ForegroundColor Yellow
  }
}

$out = npm install -g opencode-ai@latest 2>&1
$exitCode = $LASTEXITCODE
$outString = $out | Out-String

if ($exitCode -ne 0) {
  Write-Host ""
  Write-Host $outString -ForegroundColor Red
  Write-Host "npm install failed (exit $exitCode)." -ForegroundColor Red
  exit $exitCode
}

# ---------- verify ----------
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

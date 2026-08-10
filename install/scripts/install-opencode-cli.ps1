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

# ---------- install / update ----------
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
$npmRoot = (& npm root -g 2>$null | Select-Object -Last 1)
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

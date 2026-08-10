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

# Query a specific npm dist-tag (e.g. "latest", "beta") - $null when it does not exist
function Get-DistTagVersion {
  param([string]$Package, [string]$Tag)
  try {
    $v = (& npm view $Package "dist-tags.$Tag" 2>$null | Select-Object -Last 1)
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
  if ($pa.Suffix -eq $pb.Suffix) { return 0 }
  if ($pa.Suffix -eq "") { return 1 }
  if ($pb.Suffix -eq "") { return -1 }
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

# Start/restart the daemon with session-scoped env vars stripped. The daemon is
# long-lived and captures the environment it inherits at spawn time. When this
# script runs inside an opencode/OpenChamber session, that environment carries
# OPENCODE_SERVER_PASSWORD (and friends), which makes every opencode server the
# daemon later spawns require Basic auth that Paseo never sends - the provider
# then fails with "Failed to fetch OpenCode providers: {}". Strip those vars
# for the duration of the call only, then restore them (the script continues
# running after the call).
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
# Prefer the newest of the stable (latest) and beta dist-tags.
$pkgPaseo = "@getpaseo/cli"
$paseoLatest = Get-DistTagVersion -Package $pkgPaseo -Tag "latest"
$paseoBeta   = Get-DistTagVersion -Package $pkgPaseo -Tag "beta"
$target      = Select-NewestVersion -A $paseoLatest -B $paseoBeta

if (-not $target) {
  Write-Host "Could not determine the latest @getpaseo/cli version from npm. Check your connection and re-run." -ForegroundColor Red
  exit 1
}

if (-not $Quiet) {
  if ($currentVersion) {
    Write-Host "Current: paseo $currentVersion" -ForegroundColor Green
  } else {
    Write-Host "Paseo not installed yet." -ForegroundColor Yellow
  }
  $tag = if ($target -eq $paseoBeta -and $target -ne $paseoLatest) { "beta" } else { "latest" }
  Write-Host "Target: $target ($tag tag; latest $paseoLatest, beta $paseoBeta)" -ForegroundColor Cyan
}

$installSpec = if ($target -eq $paseoBeta -and $target -ne $paseoLatest) { "@getpaseo/cli@beta" } else { "@getpaseo/cli@latest" }
$out = & {
  $ErrorActionPreference = "Continue"
  npm install -g $installSpec 2>&1
}
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
}

# Auto-restart the daemon if this script stopped it for the upgrade (this also
# covers -Quiet runs where the daemon was stopped with no agents running).
# If the daemon was left running (e.g. -Quiet with agents, where the script
# refuses to stop it), the user must restart it manually to pick up the new version.
if ($stopDaemon) {
  if (-not $Quiet) {
    Write-Host ""
    Write-Host "Restarting the daemon..." -ForegroundColor Cyan
  }
  Invoke-PaseoDaemon start
  if (-not $Quiet) {
    Write-Host "Daemon restarted. Verify with: paseo daemon status" -ForegroundColor Green
  }
} elseif ($daemonRunning -and -not $Quiet) {
  Write-Host ""
  Write-Host "Note: the daemon is still running the old version. Restart it to pick up the new one: paseo daemon restart" -ForegroundColor Yellow
}

if (-not $Quiet) {
  Write-Host ""
  Write-Host "Verify with: paseo --version"
}

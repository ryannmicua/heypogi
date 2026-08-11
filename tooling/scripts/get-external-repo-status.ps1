[CmdletBinding()]
param(
  [int]$MaxAgeDays = 7,
  [Alias("h")]
  [switch]$Help
)

$ErrorActionPreference = "Stop"

function Show-Help {
  Write-Host "get-external-repo-status.ps1 - report staleness of external repo clones" -ForegroundColor Green
  Write-Host ""
  Write-Host "Usage: get-external-repo-status.ps1 [-MaxAgeDays <1-3650>]"
  Write-Host ""
  Write-Host "Checks compound-engineering, compound-knowledge, and opencode against"
  Write-Host "external/.repo-update-status.json. Exits 1 if any is missing a record or"
  Write-Host "older than -MaxAgeDays (default 7)."
  Write-Host ""
  Write-Host "Flags:"
  Write-Host "  -MaxAgeDays  Days before a repo is considered stale. Default 7."
  Write-Host "  -Help, -h    Show this message."
}

if ($Help) { Show-Help; exit 0 }

if ($MaxAgeDays -lt 1 -or $MaxAgeDays -gt 3650) {
  Write-Host "Invalid -MaxAgeDays '$MaxAgeDays' - must be between 1 and 3650." -ForegroundColor Red
  Write-Host ""
  Show-Help
  exit 1
}

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\\..")).Path
$statusPath = Join-Path $repoRoot "external\\.repo-update-status.json"
$repositories = @("compound-engineering", "compound-knowledge", "opencode")

if (-not (Test-Path -LiteralPath $statusPath -PathType Leaf)) {
  Write-Host "No external-repository update record exists. Run the update scripts before relying on this status." -ForegroundColor Yellow
  exit 1
}

$status = Get-Content -Raw -LiteralPath $statusPath | ConvertFrom-Json -AsHashtable
$now = (Get-Date).ToUniversalTime()
$checkDue = $false

foreach ($repository in $repositories) {
  $entry = $status[$repository]
  if ($null -eq $entry) {
    Write-Host "CHECK DUE  $repository (no update record)" -ForegroundColor Yellow
    $checkDue = $true
    continue
  }

  $updatedAt = [DateTime]::Parse($entry.lastUpdatedAtUtc).ToUniversalTime()
  $age = [Math]::Floor(($now - $updatedAt).TotalDays)
  $due = $age -ge $MaxAgeDays
  $label = if ($due) { "CHECK DUE" } else { "CURRENT" }
  $color = if ($due) { "Yellow" } else { "Green" }

  Write-Host ("{0,-10} {1,-22} updated {2:yyyy-MM-dd HH:mm} UTC ({3}d ago) {4}" -f $label, $repository, $updatedAt, $age, $entry.commit.Substring(0, 8)) -ForegroundColor $color
  $checkDue = $checkDue -or $due
}

if ($checkDue) { exit 1 }

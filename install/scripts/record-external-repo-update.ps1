[CmdletBinding()]
param(
  [string]$Name,
  [string]$RepositoryPath,
  [Alias("h")]
  [switch]$Help
)

$ErrorActionPreference = "Stop"

function Show-Help {
  Write-Host "record-external-repo-update.ps1 - record a repo's branch/commit/remote" -ForegroundColor Green
  Write-Host ""
  Write-Host "Usage: record-external-repo-update.ps1 -Name <name> -RepositoryPath <path>"
  Write-Host ""
  Write-Host "Internal helper called by the clone-*-source.ps1 scripts after a"
  Write-Host "successful clone/pull. Writes/updates an entry in"
  Write-Host "<repo-parent>/.repo-update-status.json, which get-external-repo-status.ps1"
  Write-Host "reads to report staleness."
  Write-Host ""
  Write-Host "Flags:"
  Write-Host "  -Name            Key to record under (e.g. 'opencode'). Required."
  Write-Host "  -RepositoryPath  Path to the local git clone. Required."
  Write-Host "  -Help, -h        Show this message."
}

if ($Help) { Show-Help; exit 0 }

if ([string]::IsNullOrWhiteSpace($Name) -or [string]::IsNullOrWhiteSpace($RepositoryPath)) {
  Write-Host "Both -Name and -RepositoryPath are required." -ForegroundColor Red
  Write-Host ""
  Show-Help
  exit 1
}

$externalDir = Split-Path -Parent $RepositoryPath
$statusPath = Join-Path $externalDir ".repo-update-status.json"
$branch = (& git -C $RepositoryPath branch --show-current).Trim()
$commit = (& git -C $RepositoryPath rev-parse HEAD).Trim()
$remote = (& git -C $RepositoryPath remote get-url origin).Trim()

if ($LASTEXITCODE -ne 0) {
  throw "Could not collect update status for $Name."
}

$status = @{}
if (Test-Path -LiteralPath $statusPath -PathType Leaf) {
  $existing = Get-Content -Raw -LiteralPath $statusPath | ConvertFrom-Json -AsHashtable
  foreach ($key in $existing.Keys) {
    $status[$key] = $existing[$key]
  }
}

$status[$Name] = [ordered]@{
  lastUpdatedAtUtc = (Get-Date).ToUniversalTime().ToString("o")
  branch = $branch
  commit = $commit
  remote = $remote
}

$status | ConvertTo-Json -Depth 3 | Set-Content -LiteralPath $statusPath -Encoding utf8

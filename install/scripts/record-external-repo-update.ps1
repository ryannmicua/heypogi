[CmdletBinding()]
param(
  [Parameter(Mandatory)]
  [string]$Name,

  [Parameter(Mandatory)]
  [string]$RepositoryPath
)

$ErrorActionPreference = "Stop"

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

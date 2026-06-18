[CmdletBinding()]
param(
  [switch]$Quiet
)

$ErrorActionPreference = "Stop"

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

function Get-RepoRootFromScriptLocation {
  param([string]$ScriptRoot)
  $repoRoot = Resolve-Path (Join-Path $ScriptRoot "..\..")
  return $repoRoot.Path
}

$repoRoot = Get-RepoRootFromScriptLocation -ScriptRoot $PSScriptRoot
$externalDir = Join-Path $repoRoot "external"
$targetDir = Join-Path $externalDir "opencode"
$cloneUrl = "https://github.com/anomalyco/opencode.git"

if (-not (Test-Path -LiteralPath $externalDir -PathType Container)) {
  New-Item -ItemType Directory -Path $externalDir | Out-Null
}

if (Test-Path -LiteralPath $targetDir -PathType Container) {
  $existing = Test-Path -LiteralPath (Join-Path $targetDir ".git") -PathType Container
  if (-not $existing) {
    throw "$targetDir exists but is not a git repository. Remove it manually and re-run."
  }
  if (-not $Quiet) {
    Write-Host "OpenCode source already cloned at: $targetDir" -ForegroundColor Green
    $choice = Read-Choice -Prompt "Pull latest? [Y]es, [N]o?" -ValidChoices @("Y", "N")
    if ($choice -eq "Y") {
      Write-Host "Pulling latest..." -ForegroundColor Cyan
      & "git" "-C" $targetDir "pull"
    }
  }
} else {
  Write-Host "Cloning opencode source into $targetDir ..." -ForegroundColor Cyan
  & "git" "clone" $cloneUrl $targetDir
  if ($LASTEXITCODE -ne 0) {
    throw "Clone failed. Check network access to $cloneUrl"
  }
}

if (-not $Quiet) {
  Write-Host ""
  Write-Host "OpenCode source: $targetDir" -ForegroundColor Green
  Write-Host "  Branch: $(git -C $targetDir branch --show-current)"
  Write-Host "  Remote: $(git -C $targetDir remote get-url origin)"
  Write-Host ""
  Write-Host "Verify with:"
  Write-Host "  ls $targetDir"
  Write-Host "  git -C $targetDir log --oneline -3"
}

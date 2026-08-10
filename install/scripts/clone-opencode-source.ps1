[CmdletBinding()]
param(
  [switch]$Quiet,
  [Alias("h")]
  [switch]$Help
)

$ErrorActionPreference = "Stop"

if ($Help) {
  Write-Host "clone-opencode-source.ps1 - clone/update the OpenCode source" -ForegroundColor Green
  Write-Host ""
  Write-Host "Usage: clone-opencode-source.ps1 [-Quiet]"
  Write-Host ""
  Write-Host "Clones external/opencode if missing, or pulls latest if it already"
  Write-Host "exists (prompts unless -Quiet)."
  Write-Host ""
  Write-Host "Flags:"
  Write-Host "  -Quiet     Pull without prompting."
  Write-Host "  -Help, -h  Show this message."
  exit 0
}

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
$statusRecorder = Join-Path $PSScriptRoot "record-external-repo-update.ps1"
$didUpdate = $false

if (-not (Test-Path -LiteralPath $externalDir -PathType Container)) {
  New-Item -ItemType Directory -Path $externalDir | Out-Null
}

if (Test-Path -LiteralPath $targetDir -PathType Container) {
  $existing = Test-Path -LiteralPath (Join-Path $targetDir ".git") -PathType Container
  if (-not $existing) {
    throw "$targetDir exists but is not a git repository. Remove it manually and re-run."
  }
  if ($Quiet) {
    & "git" "-C" $targetDir "pull"
    if ($LASTEXITCODE -ne 0) { throw "Pull failed. Check network access to $cloneUrl" }
    $didUpdate = $true
  } else {
    Write-Host "OpenCode source already cloned at: $targetDir" -ForegroundColor Green
    $choice = Read-Choice -Prompt "Pull latest? [Y]es, [N]o?" -ValidChoices @("Y", "N")
    if ($choice -eq "Y") {
      Write-Host "Pulling latest..." -ForegroundColor Cyan
      & "git" "-C" $targetDir "pull"
      if ($LASTEXITCODE -ne 0) { throw "Pull failed. Check network access to $cloneUrl" }
      $didUpdate = $true
    }
  }
} else {
  Write-Host "Cloning opencode source into $targetDir ..." -ForegroundColor Cyan
  & "git" "clone" $cloneUrl $targetDir
  if ($LASTEXITCODE -ne 0) {
    throw "Clone failed. Check network access to $cloneUrl"
  }
  $didUpdate = $true
}

if ($didUpdate) {
  & $statusRecorder -Name "opencode" -RepositoryPath $targetDir
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

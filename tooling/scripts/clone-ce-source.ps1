[CmdletBinding()]
param(
  [switch]$Quiet,
  [Alias("h")]
  [switch]$Help
)

$ErrorActionPreference = "Stop"

if ($Help) {
  Write-Host "clone-ce-source.ps1 - clone/update the Compound Engineering plugin source" -ForegroundColor Green
  Write-Host ""
  Write-Host "Usage: clone-ce-source.ps1 [-Quiet]"
  Write-Host ""
  Write-Host "Clones external/compound-engineering if missing, or pulls latest if it"
  Write-Host "already exists (prompts unless -Quiet)."
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
$targetDir = Join-Path $externalDir "compound-engineering"
$cloneUrl = "https://github.com/EveryInc/compound-engineering-plugin.git"
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
    Write-Host "Compound Engineering source already cloned at: $targetDir" -ForegroundColor Green
    $choice = Read-Choice -Prompt "Pull latest? [Y]es, [N]o?" -ValidChoices @("Y", "N")
    if ($choice -eq "Y") {
      Write-Host "Pulling latest..." -ForegroundColor Cyan
      & "git" "-C" $targetDir "pull"
      if ($LASTEXITCODE -ne 0) { throw "Pull failed. Check network access to $cloneUrl" }
      $didUpdate = $true
    }
  }
} else {
  Write-Host "Cloning compound-engineering source into $targetDir ..." -ForegroundColor Cyan
  & "git" "clone" "--depth" "1" $cloneUrl $targetDir
  if ($LASTEXITCODE -ne 0) {
    throw "Clone failed. Check network access to $cloneUrl"
  }
  $didUpdate = $true
}

if ($didUpdate) {
  & $statusRecorder -Name "compound-engineering" -RepositoryPath $targetDir
}

if (-not $Quiet) {
  Write-Host ""
  Write-Host "Compound Engineering source: $targetDir" -ForegroundColor Green
  Write-Host "  Branch: $(git -C $targetDir branch --show-current)"
  Write-Host "  Remote: $(git -C $targetDir remote get-url origin)"
  Write-Host ""
  Write-Host "Verify with:"
  Write-Host "  ls $targetDir"
  Write-Host "  git -C $targetDir log --oneline -3"
}

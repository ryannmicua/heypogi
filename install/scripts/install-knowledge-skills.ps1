[CmdletBinding()]
param(
  [switch]$CreateDest
)

$ErrorActionPreference = "Stop"

function Read-Choice {
  param(
    [string]$Prompt,
    [string[]]$ValidChoices
  )

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

function Ensure-Directory {
  param(
    [string]$Path,
    [switch]$AllowCreate
  )

  if (Test-Path -LiteralPath $Path -PathType Container) {
    return
  }

  if (-not $AllowCreate) {
    throw "Destination folder does not exist: $Path`nRe-run with -CreateDest only after user approval to create it."
  }

  New-Item -ItemType Directory -Path $Path -Force | Out-Null
}

function Resolve-ItemTargetPath {
  param([string]$LinkPath)

  $item = Get-Item -LiteralPath $LinkPath -Force
  if (-not ($item.Attributes -band [IO.FileAttributes]::ReparsePoint)) {
    return $null
  }

  if ($null -ne $item.Target -and $item.Target.Count -gt 0) {
    try { return (Resolve-Path -LiteralPath $item.Target[0]).Path } catch { return $item.Target[0] }
  }

  return $null
}

$repoRoot = Get-RepoRootFromScriptLocation -ScriptRoot $PSScriptRoot
$skillsRoot = Resolve-Path (Join-Path $repoRoot "external\compound-knowledge\plugins\compound-knowledge\skills")
$destDir = Join-Path $HOME ".agents\skills"
$destPath = Join-Path $destDir "compound-knowledge"

if (-not (Test-Path -LiteralPath $skillsRoot -PathType Container)) {
  throw "Could not find CK plugin skills folder at: $skillsRoot"
}

Ensure-Directory -Path $destDir -AllowCreate:$CreateDest

$expected = $skillsRoot.Path
$installed = 0
$skipped = 0

if (Test-Path -LiteralPath $destPath) {
  $target = Resolve-ItemTargetPath -LinkPath $destPath

  Write-Host "Blocker: $destPath already exists." -ForegroundColor Yellow
  if ($null -ne $target) {
    Write-Host "Existing target: $target"
  }
  Write-Host "Expected target: $expected"

  $choice = Read-Choice -Prompt "Choose: [O]verwrite, [S]kip, [Q]uit?" -ValidChoices @("O","S","Q")
  if ($choice -eq "Q") { throw "Aborted by user." }
  if ($choice -eq "S") {
    $skipped = 1
    Write-Host ""
    Write-Host "Done."
    Write-Host "Installed: $installed"
    Write-Host "Skipped:   $skipped"
    exit 0
  }

  if ($null -ne $target) {
    Remove-Item -LiteralPath $destPath -Force
  } else {
    Remove-Item -LiteralPath $destPath -Recurse -Force
  }
}

New-Item -ItemType Junction -Path $destPath -Target $skillsRoot | Out-Null
Write-Host "LINK: $destPath -> $skillsRoot"
$installed = 1

Write-Host ""
Write-Host "Done."
Write-Host "Installed: $installed"
Write-Host "Skipped:   $skipped"

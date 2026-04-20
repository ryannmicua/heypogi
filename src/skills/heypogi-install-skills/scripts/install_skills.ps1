[CmdletBinding()]
param(
  [switch]$CreateDest,
  [switch]$Force
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

  # This script lives at: <repo>/src/skills/heypogi-install-skills/scripts
  $repoRoot = Resolve-Path (Join-Path $ScriptRoot "..\..\..\..")
  return $repoRoot.Path
}

function Test-ValidSkillFrontmatter {
  param([string]$SkillMdPath)

  if (-not (Test-Path -LiteralPath $SkillMdPath -PathType Leaf)) {
    return $false
  }

  $lines = Get-Content -LiteralPath $SkillMdPath -TotalCount 80
  if ($lines.Count -lt 3) { return $false }
  if ($lines[0].Trim() -ne "---") { return $false }

  $endIndex = -1
  for ($i = 1; $i -lt $lines.Count; $i++) {
    if ($lines[$i].Trim() -eq "---") { $endIndex = $i; break }
  }
  if ($endIndex -lt 0) { return $false }

  $frontmatter = ($lines[1..($endIndex - 1)] -join "`n")
  if ($frontmatter -notmatch "(?m)^\s*name\s*:\s*\S+") { return $false }
  if ($frontmatter -notmatch "(?m)^\s*description\s*:\s*\S+") { return $false }

  return $true
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

  # For junctions/symlinks, PowerShell exposes Target as string[].
  if ($null -ne $item.Target -and $item.Target.Count -gt 0) {
    try { return (Resolve-Path -LiteralPath $item.Target[0]).Path } catch { return $item.Target[0] }
  }

  return $null
}

$repoRoot = Get-RepoRootFromScriptLocation -ScriptRoot $PSScriptRoot
$skillsRoot = Join-Path $repoRoot "src\skills"
$destRoot = Join-Path $HOME ".agents\skills"

if (-not (Test-Path -LiteralPath $skillsRoot -PathType Container)) {
  throw "Could not find repo skills folder at: $skillsRoot"
}

Ensure-Directory -Path $destRoot -AllowCreate:$CreateDest

$skillDirs = Get-ChildItem -LiteralPath $skillsRoot -Directory
$installed = 0
$skipped = 0
$warnings = 0
$forceAll = [bool]$Force

foreach ($skillDir in $skillDirs) {
  $skillMd = Join-Path $skillDir.FullName "SKILL.md"
  if (-not (Test-ValidSkillFrontmatter -SkillMdPath $skillMd)) {
    continue
  }

  $destPath = Join-Path $destRoot $skillDir.Name

  if (Test-Path -LiteralPath $destPath) {
    $target = Resolve-ItemTargetPath -LinkPath $destPath
    $expected = (Resolve-Path -LiteralPath $skillDir.FullName).Path

    if ($null -ne $target) {
      if ($target -eq $expected) {
        Write-Host "OK: $destPath -> $target"
        $skipped++
        continue
      }

      if (-not $forceAll) {
        $choice = Read-Choice -Prompt "Exists (link): $destPath -> $target. [O]verwrite, [S]kip, overwrite [A]ll, [Q]uit?" -ValidChoices @("O","S","A","Q")
        if ($choice -eq "Q") { throw "Aborted by user." }
        if ($choice -eq "S") { $skipped++; continue }
        if ($choice -eq "A") { $forceAll = $true }
      }

      Remove-Item -LiteralPath $destPath -Force
    } else {
      if (-not $forceAll) {
        $choice = Read-Choice -Prompt "Exists (not a link): $destPath. [O]verwrite, [S]kip, overwrite [A]ll, [Q]uit?" -ValidChoices @("O","S","A","Q")
        if ($choice -eq "Q") { throw "Aborted by user." }
        if ($choice -eq "S") { $skipped++; continue }
        if ($choice -eq "A") { $forceAll = $true }
      }

      Remove-Item -LiteralPath $destPath -Recurse -Force
    }
  }

  New-Item -ItemType Junction -Path $destPath -Target $skillDir.FullName | Out-Null
  Write-Host "LINK: $destPath -> $($skillDir.FullName)"
  $installed++
}

Write-Host ""
Write-Host "Done."
Write-Host "Installed: $installed"
Write-Host "Skipped:   $skipped"
Write-Host "Warnings:  $warnings"

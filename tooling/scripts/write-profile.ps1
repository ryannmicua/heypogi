[CmdletBinding()]
param(
  [Alias("h")]
  [switch]$Help
)

$ErrorActionPreference = "Stop"

if ($Help) {
  Write-Host "write-profile.ps1 - write HEYPOGI_ROOT / OPENCODE_CONFIG_DIR into PowerShell profiles" -ForegroundColor Green
  Write-Host ""
  Write-Host "Usage: write-profile.ps1"
  Write-Host ""
  Write-Host "Reads HEYPOGI_ROOT / OPENCODE_CONFIG_DIR from the user registry (set by"
  Write-Host "setup-environment.ps1) and writes/updates a marked block in every"
  Write-Host "PowerShell profile.ps1 found (PowerShell 7, Windows PowerShell, and"
  Write-Host "their OneDrive-redirected Documents variants). Fails if HEYPOGI_ROOT"
  Write-Host "isn't set yet - run setup-environment.ps1 first."
  Write-Host ""
  Write-Host "Flags:"
  Write-Host "  -Help, -h  Show this message."
  exit 0
}

function Get-ProfilePaths {
  $docs = [Environment]::GetFolderPath("MyDocuments")
  if (-not $docs) { $docs = Join-Path $HOME "Documents" }

  $candidates = @(
    (Join-Path $docs "PowerShell\profile.ps1"),
    (Join-Path $docs "WindowsPowerShell\profile.ps1")
  )

  $knownFolders = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders"
  if (Test-Path $knownFolders) {
    $onedriveDocs = (Get-ItemProperty -Path $knownFolders -Name Personal -ErrorAction SilentlyContinue).Personal
    if ($onedriveDocs -and $onedriveDocs -ne $docs) {
      $candidates += @(
        (Join-Path $onedriveDocs "PowerShell\profile.ps1"),
        (Join-Path $onedriveDocs "WindowsPowerShell\profile.ps1")
      )
    }
  }

  $unique = @{}
  $result = @()
  foreach ($p in $candidates) {
    $parent = Split-Path -Parent $p
    if (-not $unique.ContainsKey($p) -and (Test-Path -LiteralPath $parent -PathType Container -ErrorAction SilentlyContinue)) {
      $result += $p
      $unique[$p] = $true
    }
  }
  return $result
}

function Find-MarkerRange {
  param([string[]]$Lines, [string]$Start, [string]$End)
  $s = -1; $e = -1
  for ($i = 0; $i -lt $Lines.Count; $i++) {
    if ($Lines[$i] -eq $Start) { $s = $i; break }
  }
  if ($s -ge 0) {
    for ($i = $s + 1; $i -lt $Lines.Count; $i++) {
      if ($Lines[$i] -eq $End) { $e = $i; break }
    }
  }
  return @{ Start = $s; End = $e }
}

$heypogiRoot = [Environment]::GetEnvironmentVariable("HEYPOGI_ROOT", "User")
$configDir = [Environment]::GetEnvironmentVariable("OPENCODE_CONFIG_DIR", "User")

if (-not $heypogiRoot) {
  Write-Host "HEYPOGI_ROOT not set in registry. Run setup-environment first." -ForegroundColor Yellow
  exit 1
}

$markerStart = "# >>> heypogi env vars >>>"
$markerEnd = "# <<< heypogi env vars <<<"

$lines = @(
  "`$env:HEYPOGI_ROOT = `"$heypogiRoot`""
  "`$env:OPENCODE_CONFIG_DIR = `"$configDir`""
)

$newBlock = @($markerStart) + $lines + @($markerEnd)
$targets = Get-ProfilePaths

if ($targets.Count -eq 0) {
  Write-Host "No PowerShell profile directories found." -ForegroundColor Yellow
  $defaultPath = Join-Path ([Environment]::GetFolderPath("MyDocuments")) "PowerShell\profile.ps1"
  $parent = Split-Path -Parent $defaultPath
  New-Item -ItemType Directory -Path $parent -Force | Out-Null
  $targets = @($defaultPath)
}

foreach ($profilePath in $targets) {
  if (Test-Path -LiteralPath $profilePath) {
    $content = Get-Content -LiteralPath $profilePath
    $range = Find-MarkerRange -Lines $content -Start $markerStart -End $markerEnd

    if ($range.Start -ge 0 -and $range.End -gt $range.Start) {
      $before = if ($range.Start -gt 0) { $content[0..($range.Start - 1)] } else { @() }
      $after = if ($range.End -lt ($content.Count - 1)) { $content[($range.End + 1)..($content.Count - 1)] } else { @() }
      $newContent = $before + $newBlock + $after
      $newContent | Set-Content -LiteralPath $profilePath -Encoding UTF8
      Write-Host "  Updated $profilePath"
    } else {
      $content + @("") + $newBlock | Set-Content -LiteralPath $profilePath -Encoding UTF8
      Write-Host "  Appended to $profilePath"
    }
  } else {
    $newBlock | Set-Content -LiteralPath $profilePath -Encoding UTF8
    Write-Host "  Created $profilePath"
  }
}

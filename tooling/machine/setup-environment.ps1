[CmdletBinding()]
param(
  [switch]$Quiet,
  [Alias("h")]
  [switch]$Help
)

$ErrorActionPreference = "Stop"

if ($Help) {
  Write-Host "setup-environment.ps1 - set HEYPOGI_ROOT / OPENCODE_CONFIG_DIR" -ForegroundColor Green
  Write-Host ""
  Write-Host "Usage: setup-environment.ps1 [-Quiet]"
  Write-Host ""
  Write-Host "Sets the HEYPOGI_ROOT and OPENCODE_CONFIG_DIR user environment variables"
  Write-Host "to this repo's location, then calls write-profile.ps1 to make them"
  Write-Host "available in PowerShell profiles too (for shells that don't inherit a"
  Write-Host "fresh registry read, e.g. IntelliJ terminals)."
  Write-Host ""
  Write-Host "Also adds tooling/bin to the user PATH, so scripts wrapped there"
  Write-Host "(e.g. dev-stack) can be run by name from any shell, without typing"
  Write-Host "the tooling/ path or the .ps1 extension."
  Write-Host ""
  Write-Host "Flags:"
  Write-Host "  -Quiet     Overwrite an existing differing value without asking."
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

$repoRoot = (Get-RepoRootFromScriptLocation -ScriptRoot $PSScriptRoot) -replace '\\', '/'
$configDir = Join-Path $repoRoot "dotfiles\opencode"

function Set-EnvVar {
  param([string]$Name, [string]$Value)
  $current = [Environment]::GetEnvironmentVariable($Name, "User")
  if ($null -ne $current -and $current -eq $Value) {
    if (-not $Quiet) {
      Write-Host "Registry ${Name} already set correctly." -ForegroundColor Green
    }
  } else {
    if (-not $Quiet -and $null -ne $current -and $current -ne "") {
      Write-Host "Current registry ${Name}: $current" -ForegroundColor Yellow
      $choice = Read-Choice -Prompt "Overwrite? [Y]es, [N]o?" -ValidChoices @("Y", "N")
      if ($choice -eq "N") { throw "Aborted by user." }
    }
    [Environment]::SetEnvironmentVariable($Name, $Value, "User")
  }
}

function Add-UserPathEntry {
  param([string]$Entry)
  $current = [Environment]::GetEnvironmentVariable("Path", "User")
  $parts = @()
  if ($current) { $parts = $current -split ";" | Where-Object { $_ -ne "" } }
  if ($parts -contains $Entry) {
    if (-not $Quiet) {
      Write-Host "User PATH already contains $Entry." -ForegroundColor Green
    }
    return
  }
  $newPath = if ($current) { "$current;$Entry" } else { $Entry }
  [Environment]::SetEnvironmentVariable("Path", $newPath, "User")
  if (-not $Quiet) {
    Write-Host "Added $Entry to user PATH." -ForegroundColor Green
  }
}

Set-EnvVar -Name "HEYPOGI_ROOT" -Value $repoRoot
Set-EnvVar -Name "OPENCODE_CONFIG_DIR" -Value $configDir
Add-UserPathEntry -Entry (Join-Path ($repoRoot -replace '/', '\') "tooling\bin")

& "$PSScriptRoot\write-profile.ps1"

if (-not $Quiet) {
  Write-Host ""
  Write-Host "HEYPOGI_ROOT:" -ForegroundColor Green
  Write-Host "  Registry: $([Environment]::GetEnvironmentVariable('HEYPOGI_ROOT', 'User'))"
  Write-Host "OPENCODE_CONFIG_DIR:" -ForegroundColor Green
  Write-Host "  Registry: $([Environment]::GetEnvironmentVariable('OPENCODE_CONFIG_DIR', 'User'))"
  Write-Host "  Profile:  written"
  Write-Host ""
  Write-Host "New terminals pick up registry. IntelliJ terminals pick up profile."
  Write-Host "Verify with:  `$env:HEYPOGI_ROOT  and  `$env:OPENCODE_CONFIG_DIR"
}

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
$configDir = Join-Path $repoRoot "dotfiles\opencode"

if (-not (Test-Path -LiteralPath $configDir -PathType Container)) {
  throw "Config directory not found at: $configDir`nRun this script from the heypogi repo root."
}

# Ensure HEYPOGI_ROOT is set (needed by opencode.json references)
if ($Quiet) { & "$PSScriptRoot\install-envvars.ps1" -Quiet }
else        { & "$PSScriptRoot\install-envvars.ps1" }

$varName = "OPENCODE_CONFIG_DIR"
$current = [Environment]::GetEnvironmentVariable($varName, "User")

if ($null -ne $current -and $current -eq $configDir) {
  if (-not $Quiet) {
    Write-Host "Registry ${varName} already set correctly." -ForegroundColor Green
  }
} else {
  if (-not $Quiet -and $null -ne $current -and $current -ne "") {
    Write-Host "Current registry ${varName}: $current" -ForegroundColor Yellow
    $choice = Read-Choice -Prompt "Overwrite? [Y]es, [N]o?" -ValidChoices @("Y", "N")
    if ($choice -eq "N") { throw "Aborted by user." }
  }
  [Environment]::SetEnvironmentVariable($varName, $configDir, "User")
}

& "$PSScriptRoot\write-profile.ps1"

if (-not $Quiet) {
  Write-Host ""
  Write-Host "${varName}:" -ForegroundColor Green
  Write-Host "  Registry: $([Environment]::GetEnvironmentVariable($varName, 'User'))"
  Write-Host "  Profile:  written"
  Write-Host ""
  Write-Host "New terminals pick up registry. IntelliJ terminals pick up profile."
  Write-Host "Verify with:  `$env:$varName"
  Write-Host "Or run:       opencode debug config"
}

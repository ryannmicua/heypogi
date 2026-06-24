#!/usr/bin/env pwsh
<#
.SYNOPSIS
  Registers opencode-learn as a plugin in the global OpenCode config.

.DESCRIPTION
  Adds the opencode-learn plugin directory to the "plugin" array in
  ~/.config/opencode/opencode.json. The script auto-detects its own
  location so it works regardless of where the plugin directory lives.

  Backs up the existing config before modifying it.

.EXAMPLE
  # Install from the plugin's install/ directory:
  ./install.ps1

  # Install from anywhere by passing the plugin path:
  ./install.ps1 -PluginDir "C:/Users/rmicua/myrepo/heypogi/src/plugins/opencode-learn"
#>

param(
  # Explicit plugin directory path. If omitted, derives from script location.
  [string]$PluginDir = ""
)

# ── Paths ────────────────────────────────────────────────────────

# Resolve the opencode-learn root (parent of the install/ folder)
$ScriptRoot = $PSScriptRoot
if (-not $ScriptRoot) { $ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path }

if ($PluginDir) {
  $PluginPath = $PluginDir
} else {
  # Assume script lives at install/install.ps1, so plugin root is ..
  $PluginPath = Split-Path -Parent $ScriptRoot
}

# Normalize to absolute, forward-slash path (OpenCode prefers / on all platforms)
$PluginPath = (Resolve-Path -LiteralPath $PluginPath).Path -replace '\\', '/'

# Verify the plugin directory looks right
$PluginIndex = Join-Path $PluginPath "src/index.ts"
if (-not (Test-Path -LiteralPath $PluginIndex)) {
  Write-Error "Could not find opencode-learn plugin at: $PluginPath`nExpected to see: $PluginIndex"
  exit 1
}

$ConfigDir = Join-Path $HOME ".config" "opencode"
$ConfigFile = Join-Path $ConfigDir "opencode.json"

Write-Host "📍 Plugin directory: $PluginPath"
Write-Host "📄 Config file:      $ConfigFile"

# ── Ensure config directory exists ───────────────────────────────

if (-not (Test-Path -LiteralPath $ConfigDir)) {
  New-Item -ItemType Directory -Path $ConfigDir -Force | Out-Null
  Write-Host "➕ Created config directory: $ConfigDir"
}

# ── Read or initialize config ────────────────────────────────────

$config = $null
if (Test-Path -LiteralPath $ConfigFile) {
  $raw = Get-Content -LiteralPath $ConfigFile -Raw -Encoding UTF8
  try { $config = $raw | ConvertFrom-Json } catch {
    Write-Warning "Failed to parse existing config; backing up and creating fresh."
    $backup = "$ConfigFile.bak.$(Get-Date -Format 'yyyy-MM-ddTHH-mm-ss')"
    Copy-Item -LiteralPath $ConfigFile -Destination $backup
    Write-Host "💾 Backed up to: $backup"
    $config = $null
  }
}

if (-not $config) {
  $config = [PSCustomObject]@{ plugin = @() }
}

# ── Ensure "plugin" field exists and is an array ─────────────────

if (-not $config.plugin) {
  $config | Add-Member -MemberType NoteProperty -Name "plugin" -Value @()
}

# Convert to mutable list if needed
$plugins = [System.Collections.ArrayList]@($config.plugin)

# ── Check if already registered ──────────────────────────────────

# Normalize existing entries for comparison (forward slashes, lowercase)
$normalizedExisting = $plugins | ForEach-Object {
  $_.ToString().Trim().ToLowerInvariant().Replace('\', '/').TrimEnd('/')
}
$normalizedNew = $PluginPath.ToLowerInvariant().TrimEnd('/')

if ($normalizedExisting -contains $normalizedNew) {
  Write-Host "✅ Plugin already registered at: $PluginPath"
  exit 0
}

# ── Backup original config ───────────────────────────────────────

$backupFile = "$ConfigFile.bak.$(Get-Date -Format 'yyyy-MM-ddTHH-mm-ss')"
Copy-Item -LiteralPath $ConfigFile -Destination $backupFile -ErrorAction SilentlyContinue
Write-Host "💾 Config backed up to: $backupFile"

# ── Add the plugin ───────────────────────────────────────────────

$null = $plugins.Add($PluginPath)
$config.plugin = @($plugins)

# Write back preserving JSON structure
$json = $config | ConvertTo-Json -Depth 10
Set-Content -LiteralPath $ConfigFile -Value $json -Encoding UTF8

Write-Host "✅ Registered opencode-learn plugin in: $ConfigFile"
Write-Host ""
Write-Host "📌 Plugin path added:"
Write-Host "   $PluginPath"
Write-Host ""
Write-Host "▶  Restart OpenCode for the change to take effect."
Write-Host ""
Write-Host "🔍 Verify after restart with:"
Write-Host "   sqlite3 `"$env:LOCALAPPDATA\..\Local\share\opencode-learn\learn.db`" `".tables`""


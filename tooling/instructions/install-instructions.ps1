[CmdletBinding()]
param(
  [string]$Source,
  [switch]$Status,
  [switch]$DryRun,
  [switch]$Remove,
  [switch]$Auto,
  [switch]$Json,
  [switch]$CreateDest,
  [switch]$Force,
  [switch]$ForceCodex,
  [switch]$ForceClaude,
  [switch]$ForceAgy,
  [switch]$ForceOpenCode,
  [Alias("h")]
  [switch]$Help
)

$ErrorActionPreference = "Stop"
$script:Version = "1.0.0"

# ── Resolve paths ────────────────────────────────────────────────────────────
$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..")
$defaultSource = Join-Path $repoRoot "dotfiles\instructions\RULES.md"

if (-not $Source) {
  $Source = $defaultSource
}

# ── Usage ────────────────────────────────────────────────────────────────────
function Show-Usage {
  Write-Host "Install global instructions (RULES.md) to each AI coding agent's expected location." -ForegroundColor Green
  Write-Host ""
  Write-Host "Usage:"
  Write-Host "  pwsh -File tooling/instructions/install-instructions.ps1 [options]"
  Write-Host ""
  Write-Host "Modes:"
  Write-Host "  (default)       Interactive scan-then-select, then install"
  Write-Host "  -Status         Read-only overview of agent state (no changes)"
  Write-Host "  -DryRun         Preview actions without modifying files"
  Write-Host "  -Remove         Uninstall instructions from detected agents"
  Write-Host "  -Auto           Non-interactive install to all detected agents"
  Write-Host ""
  Write-Host "Options:"
  Write-Host "  -Source PATH    Override default source file"
  Write-Host "  -CreateDest     Create missing parent directories before copying"
  Write-Host "  -Json           Emit machine-readable JSON (incompatible with default interactive mode)"
  Write-Host "  -Force          Skip confirmation prompts (use with -Remove)"
  Write-Host "  -ForceCodex     Force-target Codex even if not detected"
  Write-Host "  -ForceClaude    Force-target Claude Code even if not detected"
  Write-Host "  -ForceAgy       Force-target agy even if not detected"
  Write-Host "  -ForceOpenCode  Force-target OpenCode even if not detected"
  Write-Host "  -Help, -h       Show this help message"
  Write-Host ""
  Write-Host "Exit codes:"
  Write-Host "  0  Success"
  Write-Host "  1  Error"
  Write-Host "  2  User abort"
}

if ($Help) {
  Show-Usage
  exit 0
}

# ── Validate mutual exclusivity ─────────────────────────────────────────────
if ($Json -and (-not $Status -and -not $DryRun -and -not $Remove -and -not $Auto)) {
  Write-Host "Error: -Json is incompatible with default interactive mode. Use -Json -Auto." -ForegroundColor Red
  exit 1
}

# ── Source validation (R31) ─────────────────────────────────────────────────
if (-not (Test-Path $Source -PathType Leaf)) {
  Write-Host "Error: Source file does not exist: $Source" -ForegroundColor Red
  exit 1
}
if ((Get-Item $Source).Length -eq 0) {
  Write-Host "Error: Source file is empty: $Source" -ForegroundColor Red
  exit 1
}

# ── Agent table ──────────────────────────────────────────────────────────────
$Agents = @(
  @{ Name = "codex";    Binary = "codex";    Dest = (Join-Path $HOME ".agents\AGENTS.md") }
  @{ Name = "claude";   Binary = "claude";   Dest = (Join-Path $HOME ".claude\CLAUDE.md") }
  @{ Name = "agy";      Binary = "agy";      Dest = (Join-Path $HOME ".gemini\GEMINI.md") }
  @{ Name = "opencode"; Binary = "opencode"; Dest = "opencode-config" }
)

# ── Agent helpers ────────────────────────────────────────────────────────────
function Test-AgentDetected {
  param([string]$Binary)
  $null -ne (Get-Command $Binary -ErrorAction SilentlyContinue)
}

function Get-AgentVersion {
  param([string]$Binary)
  if (Test-AgentDetected -Binary $Binary) {
    try {
      $ver = & $Binary --version 2>$null | Select-Object -First 1
      return $ver.Trim()
    } catch {
      return "unknown"
    }
  }
  return "unknown"
}

function Test-AgentForced {
  param([string]$Name)
  switch ($Name) {
    "codex"   { return $ForceCodex }
    "claude"  { return $ForceClaude }
    "agy"     { return $ForceAgy }
    "opencode" { return $ForceOpenCode }
    default   { return $false }
  }
}

function Get-StateDisplay {
  param([string]$State)
  switch ($State) {
    "missing"   { return @{ Text = "missing";    Color = "Yellow" } }
    "identical" { return @{ Text = "identical";  Color = "Green" } }
    "differs"   { return @{ Text = "differs";    Color = "Yellow" } }
    "opencode"  { return @{ Text = "config ref"; Color = "Cyan" } }
    default     { return @{ Text = "unknown";    Color = "White" } }
  }
}

function Get-StateStatusLabel {
  param([string]$State)
  switch ($State) {
    "missing"   { return @{ Text = "missing";    Color = "Yellow" } }
    "identical" { return @{ Text = "up to date"; Color = "Green" } }
    "differs"   { return @{ Text = "differs";    Color = "Yellow" } }
    "opencode"  { return @{ Text = "config ref"; Color = "Cyan" } }
    default     { return @{ Text = "unknown";    Color = "White" } }
  }
}

$script:SourceHash = $null

function Get-FileState {
  param([string]$Dest)
  if (-not (Test-Path $Dest -PathType Leaf)) {
    return "missing"
  }
  if ($null -eq $script:SourceHash) {
    $script:SourceHash = (Get-FileHash $Source -Algorithm MD5).Hash
  }
  $dstHash = (Get-FileHash $Dest -Algorithm MD5).Hash
  if ($script:SourceHash -eq $dstHash) {
    return "identical"
  }
  return "differs"
}

function Show-Diff {
  param([string]$Src, [string]$Dst)
  if (-not (Test-Path $Dst)) { return }
  try {
    $srcLines = Get-Content $Src
    $dstLines = Get-Content $Dst
    $diff = Compare-Object $dstLines $srcLines -IncludeEqual
    $changed = $diff | Where-Object { $_.SideIndicator -ne "==" }
    if ($changed) {
      $count = 0
      foreach ($d in $diff) {
        if ($count -ge 50) {
          Write-Host "... (diff truncated at 50 lines)" -ForegroundColor Yellow
          break
        }
        $prefix = switch ($d.SideIndicator) {
          "==" { "  " }
          "<=" { "-" }
          "=>" { "+" }
        }
        Write-Host "$prefix $($d.InputObject)"
        $count++
      }
    }
  } catch {
    Write-Host "  (diff unavailable)" -ForegroundColor Yellow
  }
}

function Copy-WithBackup {
  param([string]$Src, [string]$Dest, [switch]$DryRunMode)
  $destDir = Split-Path $Dest -Parent
  if (-not (Test-Path $destDir)) {
    if ($CreateDest) {
      if (-not $DryRunMode) {
        New-Item -ItemType Directory -Path $destDir -Force | Out-Null
      } else {
        Write-Host "[dry-run] Would create directory: $destDir" -ForegroundColor Cyan
      }
    } else {
      Write-Host "Destination directory does not exist: $destDir" -ForegroundColor Red
      Write-Host "Re-run with -CreateDest to create it." -ForegroundColor Red
      return $false
    }
  }
  if (Test-Path $Dest) {
    if (-not $DryRunMode) {
      Copy-Item $Dest "$Dest.bak" -Force
    } else {
      Write-Host "[dry-run] Would backup: $Dest -> $Dest.bak" -ForegroundColor Cyan
    }
  }
  if ($DryRunMode) {
    Write-Host "[dry-run] Would copy: $Src -> $Dest" -ForegroundColor Cyan
  } else {
    Copy-Item $Src $Dest -Force
  }
  return $true
}

# ── JSON results ─────────────────────────────────────────────────────────────
$script:JsonResults = [System.Collections.Generic.List[hashtable]]::new()

function Add-JsonResult {
  param([string]$Name, [bool]$Detected, [string]$Version, [string]$Action, [string]$Destination)
  $script:JsonResults.Add(@{
    name = $Name
    detected = $Detected
    version = $Version
    action = $Action
    destination = $Destination
  })
}

function Emit-Json {
  $obj = @{ agents = $script:JsonResults }
  $obj | ConvertTo-Json -Depth 5
}

# ── Scan agents ──────────────────────────────────────────────────────────────
$script:AgentState = @{}

function Scan-Agents {
  foreach ($agent in $Agents) {
    $detected = Test-AgentDetected -Binary $agent.Binary
    $version = "unknown"
    $state = "missing"
    if ($agent.Name -eq "opencode") {
      $state = "opencode"
    }
    if ($detected) {
      $version = Get-AgentVersion -Binary $agent.Binary
      if ($agent.Name -ne "opencode") {
        $state = Get-FileState -Dest $agent.Dest
      }
    }
    $script:AgentState[$agent.Name] = @{
      detected = $detected
      version = $version
      state = $state
    }
  }
}

# ── Interactive selection (R16-R19) ──────────────────────────────────────────
function Invoke-InteractiveSelect {
  $selected = @()

  Write-Host ""
  Write-Host "═══ Agent Scan ═══" -ForegroundColor Cyan
  Write-Host ""

  $index = 1
  $targets = @()
  foreach ($agent in $Agents) {
    $astate = $script:AgentState[$agent.Name]
    $defaultSel = $astate.detected -or (Test-AgentForced -Name $agent.Name)
    $targets += @{ name = $agent.Name; selected = $defaultSel }

    $detStr = if ($astate.detected) { "installed" } else { "not found" }
    $detColor = if ($astate.detected) { "Green" } else { "Red" }
    $stateDisplay = Get-StateStatusLabel -State $astate.state
    $selMark = if ($defaultSel) { "[x]" } else { "   " }

    Write-Host ("  {0} {1,-12} {2,-16} {3,-12} " -f $selMark, $agent.Name, $detStr, $astate.version) -NoNewline
    Write-Host $stateDisplay.Text -ForegroundColor $stateDisplay.Color
    $index++
  }

  Write-Host ""
  Write-Host "  Toggle agents by number, or press Enter to accept defaults."
  Write-Host "  Example: '1 3' toggles codex and agy. Empty = accept."
  Write-Host ""

  while ($true) {
    $input = Read-Host "  Selection (Enter to confirm)"
    if ([string]::IsNullOrWhiteSpace($input)) { break }

    foreach ($num in ($input -split '\s+')) {
      $idx = [int]$num - 1
      if ($idx -ge 0 -and $idx -lt $targets.Count) {
        $targets[$idx].selected = -not $targets[$idx].selected
      }
    }

    Write-Host ""
    Write-Host "═══ Updated Selection ═══" -ForegroundColor Cyan
    foreach ($t in $targets) {
      $astate = $script:AgentState[$t.name]
      $detStr = if ($astate.detected) { "installed" } else { "not found" }
      $stateDisplay = Get-StateStatusLabel -State $astate.state
      $selMark = if ($t.selected) { "[x]" } else { "   " }
      Write-Host ("  {0} {1,-12} {2,-16} {3,-12} " -f $selMark, $t.name, $detStr, $astate.version) -NoNewline
      Write-Host $stateDisplay.Text -ForegroundColor $stateDisplay.Color
    }
    Write-Host ""
  }

  foreach ($t in $targets) {
    if ($t.selected) { $selected += $t.name }
  }
  return $selected
}

# ── Install logic ────────────────────────────────────────────────────────────
function Invoke-InstallMode {
  $targets = @()
  $applyAll = $null

  if (-not $Status -and -not $DryRun -and -not $Remove -and -not $Auto -and -not $Json) {
    # Interactive mode
    $selected = Invoke-InteractiveSelect
    $targets = $selected
  } else {
    # auto or dry-run: target all detected or force-flagged
    foreach ($agent in $Agents) {
      $astate = $script:AgentState[$agent.Name]
      if ($astate.detected -or (Test-AgentForced -Name $agent.Name)) {
        $targets += $agent.Name
      }
    }
  }

  if ($targets.Count -eq 0) {
    if ($Json) {
      Emit-Json
    } else {
      Write-Host "No agents selected."
    }
    return
  }

  $installed = 0; $skipped = 0; $updated = 0

  foreach ($name in $targets) {
    $agent = $Agents | Where-Object { $_.Name -eq $name }
    $astate = $script:AgentState[$name]

    if ($name -eq "opencode") {
      if (-not $Json) {
        Write-Host "  ${name}: config reference (no copy needed)" -ForegroundColor Cyan
      }
      Add-JsonResult -Name $name -Detected $astate.detected -Version $astate.version -Action "config-ref" -Destination $agent.Dest
      continue
    }

    if ($astate.state -eq "missing") {
      $ok = Copy-WithBackup -Src $Source -Dest $agent.Dest -DryRunMode:$DryRun
      if ($ok) {
        if (-not $Json) {
          Write-Host "  ${name}: installed" -ForegroundColor Green
        }
        Add-JsonResult -Name $name -Detected $astate.detected -Version $astate.version -Action "installed" -Destination $agent.Dest
        $installed++
      } else {
        Add-JsonResult -Name $name -Detected $astate.detected -Version $astate.version -Action "error" -Destination $agent.Dest
        $skipped++
      }
    } elseif ($astate.state -eq "identical") {
      if (-not $Json) {
        Write-Host "  ${name}: up to date" -ForegroundColor Green
      }
      Add-JsonResult -Name $name -Detected $astate.detected -Version $astate.version -Action "up-to-date" -Destination $agent.Dest
      $skipped++
    } elseif ($astate.state -eq "differs") {
      if ($Json) {
        try {
          Copy-WithBackup -Src $Source -Dest $agent.Dest -DryRunMode:$DryRun
          Add-JsonResult -Name $name -Detected $astate.detected -Version $astate.version -Action "overwritten" -Destination $agent.Dest
          $updated++
        } catch {
          Add-JsonResult -Name $name -Detected $astate.detected -Version $astate.version -Action "error" -Destination $agent.Dest
          $skipped++
        }
      } elseif ($DryRun) {
        Show-Diff -Src $Source -Dst $agent.Dest
        Write-Host "  ${name}: would overwrite" -ForegroundColor Yellow
        Add-JsonResult -Name $name -Detected $astate.detected -Version $astate.version -Action "would-overwrite" -Destination $agent.Dest
      } else {
        if ($null -ne $applyAll) {
          if ($applyAll -eq "overwrite") {
            Copy-WithBackup -Src $Source -Dest $agent.Dest
            Write-Host "  ${name}: overwritten (apply-to-all)" -ForegroundColor Green
            Add-JsonResult -Name $name -Detected $astate.detected -Version $astate.version -Action "overwritten" -Destination $agent.Dest
            $updated++
          } else {
            Write-Host "  ${name}: skipped (apply-to-all)" -ForegroundColor Yellow
            Add-JsonResult -Name $name -Detected $astate.detected -Version $astate.version -Action "skipped" -Destination $agent.Dest
            $skipped++
          }
          continue
        }

        Write-Host ""
        Write-Host "  ${name}: destination differs" -ForegroundColor Yellow
        Show-Diff -Src $Source -Dst $agent.Dest
        Write-Host ""

        while ($true) {
          $choice = Read-Host "  [a]pply to all, [o]verwrite, [s]kip, [q]uit?"
          $choice = $choice.Trim().ToLower()
          switch ($choice) {
            "a" {
              $sub = Read-Host "  Apply [o]verwrite or [s]kip to all remaining?"
              $sub = $sub.Trim().ToLower()
              $applyAll = if ($sub -eq "o") { "overwrite" } else { "skip" }
              break
            }
            "o" {
              Copy-WithBackup -Src $Source -Dest $agent.Dest
              Write-Host "  ${name}: overwritten" -ForegroundColor Green
              Add-JsonResult -Name $name -Detected $astate.detected -Version $astate.version -Action "overwritten" -Destination $agent.Dest
              $updated++
              break
            }
            "s" {
              Write-Host "  ${name}: skipped" -ForegroundColor Yellow
              Add-JsonResult -Name $name -Detected $astate.detected -Version $astate.version -Action "skipped" -Destination $agent.Dest
              $skipped++
              break
            }
            "q" {
              Write-Host "Aborted by user." -ForegroundColor Red
              exit 2
            }
            default {
              Write-Host "Invalid choice." -ForegroundColor Yellow
            }
          }
        }
      }
    }
  }

  if ($Json) {
    Emit-Json
  } else {
    Write-Host ""
    Write-Host "Done."
    Write-Host "Installed: $installed"
    Write-Host "Skipped:   $skipped"
    Write-Host "Updated:   $updated"
  }
}

# ── Status mode (R21, R35) ──────────────────────────────────────────────────
function Invoke-StatusMode {
  Write-Host ""
  Write-Host "═══ Agent Status ═══" -ForegroundColor Cyan
  Write-Host ""
  Write-Host ("  {0,-14} {1,-18} {2,-16} {3}" -f "AGENT", "DETECTED", "VERSION", "STATE")

  foreach ($agent in $Agents) {
    $astate = $script:AgentState[$agent.Name]
    $detStr = if ($astate.detected) { "yes" } else { "no" }
    $detColor = if ($astate.detected) { "Green" } else { "Red" }
    $verStr = $astate.version
    $stateDisplay = Get-StateDisplay -State $astate.state

    Write-Host ("  {0,-14} " -f $agent.Name) -NoNewline
    Write-Host $detStr -ForegroundColor $detColor -NoNewline
    Write-Host (" {0,-16} " -f $verStr) -NoNewline
    Write-Host $stateDisplay.Text -ForegroundColor $stateDisplay.Color
  }
  Write-Host ""
}

# ── Remove mode (R27-R29) ──────────────────────────────────────────────────
function Invoke-RemoveMode {
  $targets = @()
  foreach ($agent in $Agents) {
    $astate = $script:AgentState[$agent.Name]
    if (($astate.detected -or (Test-AgentForced -Name $agent.Name)) -and $agent.Name -ne "opencode" -and $astate.state -ne "missing") {
      $targets += $agent.Name
    }
  }

  if ($targets.Count -eq 0) {
    if ($Json) {
      Emit-Json
    } else {
      Write-Host "No installed instructions found to remove."
    }
    return
  }

  foreach ($name in $targets) {
    $agent = $Agents | Where-Object { $_.Name -eq $name }
    $astate = $script:AgentState[$name]

    if (-not $Force -and -not $Json) {
      $confirm = Read-Host "  Remove ${name} instructions from $($agent.Dest)? [y/N]"
      if ($confirm.Trim().ToLower() -ne "y") {
        Write-Host "  ${name}: skipped" -ForegroundColor Yellow
        Add-JsonResult -Name $name -Detected $astate.detected -Version $astate.version -Action "skipped" -Destination $agent.Dest
        continue
      }
    }

    if (Test-Path $agent.Dest) {
      if (-not $DryRun) {
        Remove-Item $agent.Dest -Force
        if (-not $Json) { Write-Host "  ${name}: removed" -ForegroundColor Green }
        Add-JsonResult -Name $name -Detected $astate.detected -Version $astate.version -Action "removed" -Destination $agent.Dest
      } else {
        if (-not $Json) { Write-Host "  ${name}: would remove" -ForegroundColor Yellow }
        Add-JsonResult -Name $name -Detected $astate.detected -Version $astate.version -Action "would-remove" -Destination $agent.Dest
      }
    } else {
      if (-not $Json) { Write-Host "  ${name}: removed" -ForegroundColor Green }
      Add-JsonResult -Name $name -Detected $astate.detected -Version $astate.version -Action "removed" -Destination $agent.Dest
    }
  }

  if ($Json) {
    Emit-Json
  }
}

# ── Main ─────────────────────────────────────────────────────────────────────
Scan-Agents

if ($Status) {
  Invoke-StatusMode
} elseif ($Remove) {
  Invoke-RemoveMode
} else {
  Invoke-InstallMode
}

exit 0

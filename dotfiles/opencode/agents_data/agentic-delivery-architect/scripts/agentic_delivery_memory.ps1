param(
    [ValidateSet("ResolveHome", "Propose", "AutoAcceptLowRisk", "RecordDecision")]
    [string]$Action = "ResolveHome",

    [string]$Title,
    [ValidateSet("User delivery preference", "Project archetype", "Failure pattern", "Successful pattern", "Risk rule", "Tooling preference", "Mode decision")]
    [string]$Category = "User delivery preference",
    [string]$Memory,
    [string]$Evidence,
    [string]$Scope = "Global",
    [ValidateSet("Low", "Medium", "High", "Prohibited")]
    [string]$SensitivityClass = "Low",
    [string]$Rationale,
    [string]$Reviewer = "agentic-delivery-architect",
    [string]$ProposalPath,
    [ValidateSet("Accepted", "Edited", "Rejected")]
    [string]$Decision = "Accepted",

    [bool]$ContainsSecrets = $false,
    [bool]$ContainsProductionData = $false,
    [bool]$ContainsSensitivePersonalData = $false,
    [bool]$ContainsFullSourceFiles = $false,
    [bool]$ContainsExcessProprietaryDetails = $false,
    [bool]$ChangesOperatingMode = $false,
    [bool]$ChangesApprovalBoundaries = $false,
    [bool]$CreatesProjectCommitment = $false
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Find-SystemHome {
    if ($env:AGENTIC_DELIVERY_SYSTEM_HOME) {
        $candidate = Resolve-Path -LiteralPath $env:AGENTIC_DELIVERY_SYSTEM_HOME -ErrorAction Stop
        if (Test-Path -LiteralPath (Join-Path $candidate "memory/schema.md")) {
            return $candidate.Path
        }
        throw "AGENTIC_DELIVERY_SYSTEM_HOME is set but does not contain memory/schema.md: $($candidate.Path)"
    }

    $current = (Get-Location).Path
    while ($current) {
        $configPath = Join-Path $current ".agentic-delivery/config.json"
        if (Test-Path -LiteralPath $configPath) {
            $config = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json
            if ($config.system_home) {
                if ([System.IO.Path]::IsPathRooted($config.system_home)) {
                    $candidate = Resolve-Path -LiteralPath $config.system_home -ErrorAction Stop
                } else {
                    $candidate = Resolve-Path -LiteralPath (Join-Path $current $config.system_home) -ErrorAction Stop
                }
                if (Test-Path -LiteralPath (Join-Path $candidate "memory/schema.md")) {
                    return $candidate.Path
                }
                throw "Configured system_home does not contain memory/schema.md: $($candidate.Path)"
            }
        }

        if (Test-Path -LiteralPath (Join-Path $current "memory/schema.md")) {
            return $current
        }

        $parent = Split-Path -Parent $current
        if ($parent -eq $current) { break }
        $current = $parent
    }

    throw "Could not resolve Agentic Delivery System home. Set AGENTIC_DELIVERY_SYSTEM_HOME or .agentic-delivery/config.json."
}

function Convert-ToSlug([string]$Text) {
    if (-not $Text) { throw "Title is required." }
    $lower = $Text.ToLowerInvariant()
    $slug = $lower -replace "[^a-z0-9]+", "_"
    $slug = $slug.Trim("_")
    if (-not $slug) { throw "Title must contain letters or numbers." }
    if ($slug.Length -gt 64) { $slug = $slug.Substring(0, 64).Trim("_") }
    return $slug
}

function Ensure-MemoryDirs([string]$SystemRoot) {
    foreach ($dir in @("memory/proposed", "memory/approved", "memory/rejected")) {
        $path = Join-Path $SystemRoot $dir
        if (-not (Test-Path -LiteralPath $path)) {
            New-Item -ItemType Directory -Path $path | Out-Null
        }
    }
    $logPath = Join-Path $SystemRoot "memory/review_log.md"
    if (-not (Test-Path -LiteralPath $logPath)) {
        @(
            "# Memory Review Log",
            "",
            "| Date | Memory record | Category | Scope | Sensitivity | Decision | Reviewer or rule | Rationale |",
            "|---|---|---|---|---|---|---|---|"
        ) | Set-Content -LiteralPath $logPath -Encoding utf8
    }
}

function Test-ProhibitedSignals {
    return ($ContainsSecrets -or $ContainsProductionData -or $ContainsSensitivePersonalData -or $ContainsFullSourceFiles -or $ContainsExcessProprietaryDetails)
}

function Test-HighRiskSignals {
    return ($ChangesOperatingMode -or $ChangesApprovalBoundaries -or $CreatesProjectCommitment)
}

function New-MemoryDocument([string]$Decision) {
    if (-not $Title) { throw "Title is required." }
    if (-not $Memory) { throw "Memory is required." }
    if (-not $Evidence) { throw "Evidence is required." }

    $approvalRequired = "No"
    if ($SensitivityClass -ne "Low" -or (Test-ProhibitedSignals) -or (Test-HighRiskSignals)) {
        $approvalRequired = "Yes"
    }

    return @"
# Memory Proposal

## Title

$Title

## Date

$(Get-Date -Format "yyyy-MM-dd")

## Memory Category

$Category

## Proposed Memory

$Memory

## Evidence

$Evidence

## Scope

$Scope

## Sensitivity Check

| Question | Answer |
|---|---|
| Contains secrets, credentials, tokens, or private keys? | $ContainsSecrets |
| Contains production data? | $ContainsProductionData |
| Contains sensitive personal data? | $ContainsSensitivePersonalData |
| Contains full source files? | $ContainsFullSourceFiles |
| Contains proprietary details beyond reusable learning? | $ContainsExcessProprietaryDetails |
| Changes operating mode guidance? | $ChangesOperatingMode |
| Changes approval boundaries or permissions? | $ChangesApprovalBoundaries |
| Creates a project commitment? | $CreatesProjectCommitment |

## Sensitivity Class

$SensitivityClass

## Approval Requirement

$approvalRequired

## Reviewer or Auto-Accept Rule

$Reviewer

## Recommended Action

$Decision

## Rationale

$Rationale

## Decision

$Decision
"@
}

function Add-ReviewLogEntry([string]$SystemRoot, [string]$Record, [string]$Decision) {
    if (-not $Rationale) { throw "Rationale is required for review log entries." }
    $safeRationale = $Rationale -replace "\|", "/"
    $safeRecord = $Record -replace "\|", "/"
    $line = "| $(Get-Date -Format "yyyy-MM-dd") | $safeRecord | $Category | $Scope | $SensitivityClass | $Decision | $Reviewer | $safeRationale |"
    Add-Content -LiteralPath (Join-Path $SystemRoot "memory/review_log.md") -Value $line
}

$systemHome = Find-SystemHome
if ($Action -eq "ResolveHome") {
    $systemHome
    exit 0
}

Ensure-MemoryDirs $systemHome

if ($Action -eq "Propose") {
    $slug = Convert-ToSlug $Title
    $path = Join-Path $systemHome ("memory/proposed/{0}-{1}.md" -f (Get-Date -Format "yyyy-MM-dd"), $slug)
    New-MemoryDocument "Pending" | Set-Content -LiteralPath $path -Encoding utf8
    $path
    exit 0
}

if ($Action -eq "AutoAcceptLowRisk") {
    if ($SensitivityClass -ne "Low") { throw "Auto-accept requires Low sensitivity." }
    if (Test-ProhibitedSignals) { throw "Auto-accept blocked by prohibited-content signal." }
    if (Test-HighRiskSignals) { throw "Auto-accept blocked by mode, approval, or project-commitment signal." }
    if ($Category -eq "Risk rule" -or $Category -eq "Mode decision") { throw "Auto-accept blocked for Risk rule or Mode decision." }

    $slug = Convert-ToSlug $Title
    $path = Join-Path $systemHome ("memory/approved/{0}-{1}.md" -f (Get-Date -Format "yyyy-MM-dd"), $slug)
    New-MemoryDocument "Auto-Accepted" | Set-Content -LiteralPath $path -Encoding utf8
    Add-ReviewLogEntry $systemHome $path "Auto-Accepted"
    $path
    exit 0
}

if ($Action -eq "RecordDecision") {
    if (-not $ProposalPath) { throw "ProposalPath is required for RecordDecision." }
    $resolvedProposal = Resolve-Path -LiteralPath $ProposalPath -ErrorAction Stop
    Add-ReviewLogEntry $systemHome $resolvedProposal.Path $Decision
    $resolvedProposal.Path
    exit 0
}

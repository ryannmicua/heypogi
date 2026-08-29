---
title: "setup-environment.md only covers Windows — Linux users must set env vars manually"
date: 2026-08-29
category: setup
module: "tooling/machine (environment setup)"
problem_type: documentation_gap
component: development_workflow
symptoms:
  - "opencode debug config returns a bare config, ignoring dotfiles/opencode/opencode.json"
  - "HEYPOGI_ROOT and OPENCODE_CONFIG_DIR are empty in the current shell"
  - "setup-environment.md references a PowerShell script that cannot run on Linux"
root_cause: documentation_gap
resolution_type: documentation
severity: low
related_components: [tooling, development_workflow]
tags: [environment-variables, linux, powershell, setup, opencode-config, cross-platform]
---

# setup-environment.md only covers Windows — Linux users must set env vars manually

## Problem

`tooling/machine/setup-environment.md` documents a Windows-only PowerShell workflow (`setup-environment.ps1`) that sets `HEYPOGI_ROOT` and `OPENCODE_CONFIG_DIR` via the Windows registry and PowerShell profile. On Linux, the script cannot run (no PowerShell, no registry), and the doc provides no Linux equivalent. A user following the doc on Linux gets no guidance and must figure out the equivalent manually.

## Symptoms

- `opencode debug config` returns a bare config (no agents, no references, no permissions) — the custom `dotfiles/opencode/opencode.json` is not loaded.
- `$HEYPOGI_ROOT` and `$OPENCODE_CONFIG_DIR` print empty in the current shell session.
- The only setup doc (`tooling/machine/setup-environment.md`) points at a `.ps1` file with no Linux fallback.

## What Didn't Work

Running the PowerShell script directly was not possible — `pwsh` is not installed on this Linux machine, and even if it were, the script uses Windows-specific APIs (`[Environment]::SetEnvironmentVariable(..., "User")` for registry writes, `;`-delimited PATH manipulation, and `write-profile.ps1` for PowerShell profile management). These have no Linux equivalent in the script.

## Solution

The environment variables were **already present** in `~/.bashrc` (lines 123-127), added by a previous session or manual edit:

```bash
# === Heypogi Environment ===
export HEYPOGI_ROOT="/home/rgm/repo/heypogi"
export OPENCODE_CONFIG_DIR="/home/rgm/repo/heypogi/dotfiles/opencode"
export PATH="$HEYPOGI_ROOT/tooling/bin:$PATH"
# === End Heypogi ===
```

The issue was that the current shell session had not sourced these variables (started before they were added, or not reloaded). Setting them inline confirmed opencode picks up the full config:

```bash
export HEYPOGI_ROOT="/home/rgm/repo/heypogi"
export OPENCODE_CONFIG_DIR="/home/rgm/repo/heypogi/dotfiles/opencode"
opencode debug config  # now shows all agents, references, permissions
```

No file changes were needed — the fix is operational (source your profile or start a new terminal).

## Why This Works

OpenCode reads `OPENCODE_CONFIG_DIR` at startup to locate its config directory. When the variable is unset, it falls back to defaults and does not load `dotfiles/opencode/opencode.json`. The `~/.bashrc` entries ensure new bash sessions get the variables automatically; existing sessions must either `source ~/.bashrc` or export them manually.

## Prevention

**New terminal sessions** pick up the variables automatically from `~/.bashrc`.

**Existing sessions** that were started before the variables were added:

```bash
source ~/.bashrc
# or inline:
export HEYPOGI_ROOT="/home/rgm/repo/heypogi"
export OPENCODE_CONFIG_DIR="/home/rgm/repo/heypogi/dotfiles/opencode"
```

**Verify** with:

```bash
echo "HEYPOGI_ROOT=$HEYPOGI_ROOT"
echo "OPENCODE_CONFIG_DIR=$OPENCODE_CONFIG_DIR"
opencode debug config
```

The config output should show agents (`explore`, `free`, `thinker`, `ce`, `paseo-orchestrator`), references, permissions, and the `wrapup` command — not a bare skeleton.

**Documentation note:** `tooling/machine/setup-environment.md` should be updated to document the Linux equivalent (env vars in `~/.bashrc` or `~/.profile`) alongside the Windows PowerShell workflow, so cross-platform users are not left to discover the gap.

## Related Issues

- `tooling/machine/setup-environment.md` — the doc that should be updated with Linux instructions.
- `dotfiles/opencode/opencode.json` — the config file that depends on `OPENCODE_CONFIG_DIR` being set.

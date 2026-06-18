# Install Repo Environment Variables

Sets `HEYPOGI_ROOT` to the repo root directory. This variable is used by config
files (e.g. `dotfiles/opencode/opencode.json`) to reference paths via `{env:HEYPOGI_ROOT}`.

## Install

Run from the repo root:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File install/scripts/install-envvars.ps1
```

To suppress prompts (e.g. for scripting):

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File install/scripts/install-envvars.ps1 -Quiet
```

## What it sets

| Variable | Value | Purpose |
|---|---|---|
| `HEYPOGI_ROOT` | `<repo_root>` | Base path for config file references |

## What it modifies

| Target | Details |
|---|---|
| Registry | `HKCU\Environment\HEYPOGI_ROOT` |
| PowerShell profile | `$PROFILE.CurrentUserAllHosts` |

The profile entry is wrapped in a marker block (`# >>> heypogi env vars >>>`) so
it can be updated safely on re-run.

## Verify

Open a **new** terminal:

```powershell
$env:HEYPOGI_ROOT
```

Or reload your profile in the current terminal:

```powershell
. $PROFILE
$env:HEYPOGI_ROOT
```

## Manual setup

```powershell
# Registry (all processes)
[Environment]::SetEnvironmentVariable("HEYPOGI_ROOT", "<repo_root>", "User")

# PowerShell profile (IntelliJ terminals, immediate reload)
"`$env:HEYPOGI_ROOT = `"<repo_root>`"" | Add-Content $PROFILE.CurrentUserAllHosts
```

Replace `<repo_root>` with the actual path (e.g. `C:\Users\you\myrepo\heypogi`).

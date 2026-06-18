# Setup Environment Variables

Sets `HEYPOGI_ROOT` and `OPENCODE_CONFIG_DIR` in the Windows registry (User scope)
and PowerShell profile, and points OpenCode at this repo's config directory.

## Install

Run from the repo root:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File install/scripts/setup-environment.ps1
```

To suppress prompts (e.g. for scripting):

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File install/scripts/setup-environment.ps1 -Quiet
```

## What it sets

| Variable | Value | Purpose |
|---|---|---|
| `HEYPOGI_ROOT` | `<repo_root>` | Repo root for tooling and scripts |
| `OPENCODE_CONFIG_DIR` | `<repo_root>\dotfiles\opencode` | OpenCode custom config directory |

## What it modifies

| Target | Details |
|---|---|
| Registry | `HKCU\Environment\HEYPOGI_ROOT`, `HKCU\Environment\OPENCODE_CONFIG_DIR` |
| PowerShell profile | `$PROFILE.CurrentUserAllHosts` |

The profile entry is wrapped in a marker block (`# >>> heypogi env vars >>>`) so
it can be updated safely on re-run.

## Verify

Open a **new** terminal:

```powershell
$env:HEYPOGI_ROOT
$env:OPENCODE_CONFIG_DIR
```

Or reload your profile in the current terminal:

```powershell
. $PROFILE
$env:HEYPOGI_ROOT
$env:OPENCODE_CONFIG_DIR
```

Or check that OpenCode picks up the config:

```powershell
opencode debug config
```

You should see `dotfiles\opencode` listed among the loaded config sources.

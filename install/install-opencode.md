# Install OpenCode Config

Points OpenCode to use the config directory in this repo via `OPENCODE_CONFIG_DIR`.

## Prerequisites

Run `install-envvars` first to set `HEYPOGI_ROOT` (required by opencode.json references).

## What this does

Sets `OPENCODE_CONFIG_DIR` to `<repo_root>\dotfiles\opencode`, then calls
`install-envvars` to ensure `HEYPOGI_ROOT` is set.

OpenCode loads this directory on top of your global config (`~/.config/opencode/`),
merging settings. The config references use `{env:HEYPOGI_ROOT}` so paths are
portable across machines.

## Install

Run from the repo root:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File install/scripts/install-opencode.ps1
```

To suppress prompts (e.g. for scripting):

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File install/scripts/install-opencode.ps1 -Quiet
```

## Verify

Restart your terminal, then:

```powershell
$env:OPENCODE_CONFIG_DIR
```

Or check that OpenCode picks it up:

```powershell
opencode debug config
```

You should see `dotfiles\opencode` listed among the loaded config sources.

## Manual setup

```powershell
[Environment]::SetEnvironmentVariable(
  "OPENCODE_CONFIG_DIR",
  "<repo_root>\dotfiles\opencode",
  "User"
)
```

Replace `<repo_root>` with the actual path.

## What it modifies

| Target | Details |
|---|---|
| Registry | `HKCU\Environment\OPENCODE_CONFIG_DIR` |
| PowerShell profile | `$PROFILE.CurrentUserAllHosts` (same marker block as envvars) |

## Notes

- The installer calls `install-envvars` first, so both variables are set.
- The profile entry is wrapped in a marker block — safe to re-run.
- For `HEYPOGI_ROOT` only, see `install-envvars.md`.

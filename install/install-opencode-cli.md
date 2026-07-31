# Install / Update OpenCode CLI

Installs or updates the `opencode` CLI via npm. Handles the Windows-specific
pitfalls: stops running processes (avoids `EBUSY`), sets `allow-scripts` so the
postinstall runs, and verifies the result.

## Install (fresh machine)

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File install/scripts/install-opencode-cli.ps1
```

## Update (already installed)

Same command — it detects the current version and upgrades if a newer one is
available.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File install/scripts/install-opencode-cli.ps1
```

## Silent mode

Suppresses prompts (auto-kills running opencode, no version banner):

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File install/scripts/install-opencode-cli.ps1 -Quiet
```

## Prerequisites

- Node.js (and npm) — install from https://nodejs.org first if missing.

## What it does

| Step | Detail |
|---|---|
| Check prereqs | Verifies `node` and `npm` are on PATH. |
| Kill running opencode | Stops any running `opencode.exe` to avoid `EBUSY` file lock. |
| Set allow-scripts | `npm config set allow-scripts=opencode-ai --location=user` so the `postinstall` script runs. |
| npm install | `npm install -g opencode-ai@latest` |
| Verify | Runs `opencode --version` and prints result. |

## Verify

```powershell
opencode --version
```

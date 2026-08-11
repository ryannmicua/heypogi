# Manage OpenCode CLI — `opencode-ctl.ps1`

Full lifecycle control for the `opencode-ai` npm package: install/update,
status, and uninstall. Handles the Windows-specific pitfalls: stops running
processes (avoids `EBUSY`), sets `allow-scripts` so the postinstall runs
(self-healing if it didn't, e.g. an older npm ignoring the flag leaves a
stub `opencode.exe`), and verifies the result.

OpenCode has no autostart mechanism or standalone daemon of its own — it
runs as an OpenChamber sidecar or directly from a terminal — so there is no
`start`/`stop`/`configure`, unlike `openchamber-ctl.ps1` or `paseo-ctl.ps1`.

## Usage

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tooling/scripts/opencode-ctl.ps1 [command]
```

| Command | What it does |
|---------|--------------|
| `status` (default) | Show CLI path, version, and whether it's currently running. |
| `install` | Install/update the `opencode-ai` npm package. |
| `update` | Alias for `install`. |
| `uninstall` | Stop any running `opencode` process and `npm uninstall -g opencode-ai`. |
| `help` | Show usage. |

## Install / update (fresh machine or upgrade)

```powershell
tooling/scripts/opencode-ctl.ps1 install
```

Detects the current version and upgrades if a newer one is available. If
OpenCode is running, it asks to close it first (unless `-Quiet`).

## Silent mode

Suppresses prompts (auto-kills running opencode, no version banner):

```powershell
tooling/scripts/opencode-ctl.ps1 install -Quiet
```

## Uninstall

```powershell
tooling/scripts/opencode-ctl.ps1 uninstall
```

Stops any running `opencode` process and removes the npm package. Config
(`~/.config/opencode`, if present) is **kept by default** — pass
`-WipeConfig` to also delete it; this always asks for confirmation unless
`-Force` is given too.

```powershell
tooling/scripts/opencode-ctl.ps1 uninstall -WipeConfig
```

## Prerequisites

- Node.js (and npm 12+, for `--allow-scripts`) — install from
  https://nodejs.org first if missing.

## What `install` does

| Step | Detail |
|---|---|
| Check prereqs | Verifies `node` and `npm` (12+) are on PATH. |
| Kill running opencode | Stops any running `opencode.exe` to avoid `EBUSY` file lock. |
| npm install | `npm install -g opencode-ai@latest --allow-scripts=opencode-ai`. |
| Self-heal | If the installed `opencode.exe` is a stub (postinstall didn't run — happens with older npm ignoring `--allow-scripts`), runs `postinstall.mjs` manually. |
| Verify | Runs `opencode --version` and prints result. |

## Verify

```powershell
opencode --version
```

See [dev-stack.md](dev-stack.md) for the cross-tool supervisor
(`dev-stack.ps1`) that wraps this script alongside OpenChamber and Paseo.

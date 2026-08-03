# Install / Update OpenChamber

Installs or updates the `@openchamber/web` package (OpenChamber web UI + its
OpenCode sidecar). Thin wrapper that delegates to `scripts/openchamber.ps1
install`, which handles the Windows-specific pitfalls: stops a running
instance first (native modules lock — `EPERM`/`EBUSY`), sets `allow-scripts`
for `better-sqlite3`/`node-pty`, installs the global npm package, and re-runs
`configure` (settings file + startup wrappers + Run key).

## Install (fresh machine)

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File install/scripts/install-openchamber.ps1
```

## Update (already installed)

Same command — it detects the current version and upgrades if a newer one is
available. If a server is running, the delegate stops it (asks first unless
`-Quiet`/`-Force`), because npm cannot replace `better-sqlite3.node` while the
server holds it:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File install/scripts/install-openchamber.ps1
```

## Silent mode

Suppresses prompts (no version banner, stops a running instance without
asking, no final instructions):

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File install/scripts/install-openchamber.ps1 -Quiet
```

Add `-Force` to skip confirmation prompts interactively (e.g. overwrite
prompts in `configure`).

## Prerequisites

- Node.js (and npm) — install from https://nodejs.org first if missing.
- The lifecycle script `install/scripts/openchamber.ps1` must sit next to this
  wrapper — it does the actual work.

## What it does

| Step | Detail |
|---|---|
| Check prereqs | Verifies `node` and `npm` are on PATH. |
| Detect version | Runs `openchamber --version` and shows current vs. new. |
| Delegate | Calls `openchamber.ps1 install` (passes through `-Quiet` / `-Force`), which stops a running instance, sets `npm config set allow-scripts=better-sqlite3,node-pty`, runs `npm install -g @openchamber/web@latest`, and re-runs `configure`. |
| Verify | Re-runs `openchamber --version` and prints result; exits 1 if it fails. |

## Verify

```powershell
openchamber --version
```

See [openchamber-startup-setup.md](./openchamber-startup-setup.md) for the
full lifecycle (start/stop/status/uninstall) and settings documentation.

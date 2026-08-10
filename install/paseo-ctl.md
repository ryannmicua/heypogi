# Manage Paseo Server / CLI — `paseo-ctl.ps1`

Full lifecycle control for the `@getpaseo/cli` package (headless Paseo daemon
+ CLI): install/update, status, start/stop, and uninstall. Handles the
Windows-specific pitfall: the daemon runs from the installed npm package, so
npm cannot replace the files while it is running (`EBUSY`) — install stops
the daemon first (after asking, since that also stops any running agents),
then restarts it afterward.

## Usage

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File install/scripts/paseo-ctl.ps1 [command]
```

| Command | What it does |
|---------|--------------|
| `status` (default) | Show CLI path, version, daemon running state, autostart task, and config (listen address, web UI, password set). |
| `install` | Install/update `@getpaseo/cli` (newest of the `latest`/`beta` dist-tags). |
| `update` | Alias for `install`. |
| `start` | Start the daemon (no-op if already running). |
| `stop` | Stop the daemon. |
| `uninstall` | Stop the daemon, unregister the `PaseoDaemon` scheduled task, and `npm uninstall -g @getpaseo/cli`. |
| `help` | Show usage. |

## Install / update (fresh machine or upgrade)

```powershell
install/scripts/paseo-ctl.ps1 install
```

Detects the current version and upgrades if a newer one is available. If the
daemon is running, it asks before stopping it (unless `-Quiet`), restarts it
automatically afterward with session env vars stripped
(`OPENCODE_SERVER_PASSWORD` etc.) so spawned opencode servers don't require
Basic auth.

## Silent mode

Suppresses prompts. Stops the daemon automatically only if no agents are
running; otherwise skips the stop and warns that it must be stopped manually
before upgrading:

```powershell
install/scripts/paseo-ctl.ps1 install -Quiet
```

## Stable vs beta

`install` checks both npm dist-tags and installs the newest of them:

- `latest` — stable (e.g. `0.2.5`)
- `beta` — prerelease (e.g. `0.3.0-beta.2`)

If the beta is newer than the stable release it installs `@getpaseo/cli@beta`,
otherwise `@getpaseo/cli@latest`. The chosen target and both available
versions are printed before installing.

## Uninstall

```powershell
install/scripts/paseo-ctl.ps1 uninstall
```

Stops the daemon, unregisters the `PaseoDaemon` scheduled task (requires an
elevated shell — it runs with `RunLevel Highest`), and removes the npm
package. Config (`~/.paseo`, including any provider API keys) is **kept by
default** — pass `-WipeConfig` to also delete it; this always asks for
confirmation unless `-Force` is given too.

```powershell
install/scripts/paseo-ctl.ps1 uninstall -WipeConfig
```

## Prerequisites

- Node.js (and npm) — install from https://nodejs.org first if missing.
- At least one provider CLI (Claude Code, Codex, OpenCode, Copilot) and the
  GitHub CLI (`gh`) — Paseo manages agents, it doesn't ship one. See
  https://paseo.sh/docs.

## What `install` does

| Step | Detail |
|---|---|
| Check prereqs | Verifies `node` and `npm` are on PATH. |
| Detect version | Runs `paseo --version` (skipped if not installed). |
| Handle daemon | If `paseo daemon status` reports running, asks to stop it (kills running agents — prompts unless `-Quiet` with no agents). |
| npm install | `npm install -g @getpaseo/cli@beta` or `@latest` — newest of the `latest` and `beta` dist-tags. |
| Restart daemon | If the script stopped the daemon for the upgrade, it restarts it automatically with session env vars stripped. |
| Verify | Runs `paseo --version` and prints result. |

## After an upgrade

The daemon is restarted automatically when the script stopped it for the
upgrade. You only need to restart manually if the script could not stop the
daemon (e.g. `-Quiet` with running agents, which it refuses to stop):

```powershell
paseo daemon start
```

Note: `paseo daemon restart` also works but stops any currently running
agents.

## Verify

```powershell
paseo --version
paseo daemon status
```

## References

- Docs: https://paseo.sh/docs
- Headless setup (web UI, password, auto-start): [paseo-headless-setup.md](paseo-headless-setup.md)
- Cross-tool supervisor that wraps this script: [dev-stack.md](dev-stack.md)

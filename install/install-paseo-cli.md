# Install / Update Paseo Server / CLI

Installs or updates the `@getpaseo/cli` package (headless Paseo daemon + CLI)
via npm. Handles the Windows-specific pitfall: the daemon runs from the
installed npm package, so npm cannot replace the files while it is running
(`EBUSY`). The script stops the daemon first (after asking, since that also
stops any running agents), then verifies the result.

## Install (fresh machine)

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File install/scripts/install-paseo-cli.ps1
```

## Update (already installed)

Same command — it detects the current version and upgrades if a newer one is
available. If the daemon is running, it asks before stopping it:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File install/scripts/install-paseo-cli.ps1
```

## Silent mode

Suppresses prompts. Stops the daemon automatically only if no agents are
running; otherwise skips the stop and warns that the daemon must be stopped
manually before upgrading:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File install/scripts/install-paseo-cli.ps1 -Quiet
```

## Stable vs beta

The script checks both npm dist-tags and installs the newest of them:

- `latest` — stable (e.g. `0.2.5`)
- `beta` — prerelease (e.g. `0.3.0-beta.2`)

If the beta is newer than the stable release it installs `@getpaseo/cli@beta`,
otherwise `@getpaseo/cli@latest`. The chosen target and both available versions
are printed before installing.

## Prerequisites

- Node.js (and npm) — install from https://nodejs.org first if missing.
- At least one provider CLI (Claude Code, Codex, OpenCode, Copilot) and the
  GitHub CLI (`gh`) — Paseo manages agents, it doesn't ship one. See
  https://paseo.sh/docs.

## What it does

| Step | Detail |
|---|---|
| Check prereqs | Verifies `node` and `npm` are on PATH. |
| Detect version | Runs `paseo --version` (skipped if not installed). |
| Handle daemon | If `paseo daemon status` reports running, asks to stop it (kills running agents — prompts unless `-Quiet` with no agents). |
| npm install | `npm install -g @getpaseo/cli@beta` or `@latest` — newest of the `latest` and `beta` dist-tags. |
| Restart daemon | If the script stopped the daemon for the upgrade, it restarts it automatically with session env vars stripped (`OPENCODE_SERVER_PASSWORD` etc.) so spawned opencode servers don't require Basic auth. |
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
- Headless setup (web UI, password, auto-start): `install/paseo-headless-setup.md`

# Heypogi Bootstrap

Thin orchestrator that converges a machine into an AI Agentic
Development VM by delegating to `tooling/`. Bootstrap owns ordering,
flag mapping, target context, run history, and status aggregation only
- all install logic lives in the leaves.

Scripts in `bootstrap/` follow the repository's [general script standard](../docs/standards/scripts.md). Bash scripts additionally follow the [Bash script standard](../docs/standards/bash-scripts.md).
Contract details live in the `script-contract` + `bash-script-contract`
skills (`src/skills/`).

## Ownership map

| Area | Owner |
|------|-------|
| Env files + marker block | `tooling/env/setup-env.sh` (gated by `tooling/env/require-env.sh`) |
| System checks (node/npm/curl/git/docker/uv/AVX) | `tooling/machine/check-prereqs.sh` |
| Claude / Codex / gh installers | `tooling/machine/install-{claude,codex,gh}-cli.sh` |
| External checkouts (acquired before skills) | `tooling/sources/clone-*.sh` via `update-external-repos.sh` |
| Skill links | `tooling/skills/install-*.sh` |
| Userspace PATH layout (before the unit install) | `tooling/bin/userspace-shims.sh` |
| Paseo config seed/merge, user unit, legacy migration, linger, fail-closed bind, secrets allowlist | `tooling/dev-stack/dev-stack.sh` |

## What This Does

Running `bootstrap.sh` executes, in env-first order:

1. **Environment** — `setup-env.sh install` (creates the env; the single
   pre-guard phase)
2. **Prerequisites** — `check-prereqs.sh install` (apt-installs
   curl/git/bubblewrap/uv; Node.js, Docker, AVX are fail-closed blockers)
3. **Userspace shims** — `userspace-shims.sh install` (node-bin link, npm
   prefix, CLI shims for the rootless unit)
4. **AI agent CLIs** — `install-{claude,codex,gh}-cli.sh install`
5. **External sources** — `update-external-repos.sh -f` (before skills)
6. **Dev Stack** — `dev-stack.sh install` (incl. additive Paseo seed)
7. **Skills** — `install-{skills,ce-skills,knowledge-skills}.sh install --create-dest`
8. **Startup + start** — `dev-stack.sh startup install -a paseo` (legacy
   migration, linger, allowlist) then `start -a paseo`
9. **Marker** — appends `ISO8601-ts | user | repo-root | git-sha | args | exit-code`
   to `~/.config/heypogi/.bootstrap-runs.log` (+ atomic last-run file),
   trap-finalized and `flock`-serialized. Skipped under `--dry-run`;
   marker-write failure is a WARN, never the run's exit code.

After bootstrapping, the machine will have:
- `claude` — Anthropic's coding agent
- `codex` — OpenAI's coding agent
- `opencode` — Open-source multi-provider coding agent
- `paseo` — Agent orchestrator daemon (runs as systemd service)
- `openchamber` — Web UI for agent management
- `dev-stack` — CLI to manage services

## Prerequisites

The machine must have:

| Requirement | Why | How to install if missing |
|-------------|-----|---------------------------|
| **Ubuntu 22.04+** or **Debian 12+** | Target OS | Use cloud-init template |
| **Guest CPU exposes AVX** (`grep avx /proc/cpuinfo`) | OpenCode's Bun-compiled binary requires AVX (its "baseline" build still needs SSE4.2+) and segfaults without it | On Proxmox, set the VM's `cpu:` type to `x86-64-v3` or newer (not the `kvm64`/default type) — requires a full `qm shutdown` + `qm start`, not just an in-guest reboot |
| **Node.js 22+** | Required by all agent CLIs | `curl -fsSL https://deb.nodesource.com/setup_22.x \| sudo -E bash - && sudo apt install -y nodejs` |
| **npm** | Package manager for agent CLIs | Comes with Node.js |
| **git** | Clone repos, version control | `sudo apt install -y git` |
| **curl** | Download installers | `sudo apt install -y curl` |
| **Docker** | Fail-closed blocker (checked, never provisioned) | Install via Docker's official repo |
| **uv** | Installed via official script when missing | `curl -LsSf https://astral.sh/uv/install.sh \| sh` |
| **Internet access** | Download tools | Required |
| **sudo privileges** | Install packages, systemd | Required |

### Quick check

```bash
# Verify prerequisites
node --version   # Should be v22.x.x
npm --version    # Should be 10.x.x
git --version    # Any recent version
curl --version   # Any recent version
docker --version # Required (blocker with remediation when missing)
uv --version     # Optional but recommended
grep avx /proc/cpuinfo || echo "NO AVX - OpenCode will crash, fix the VM's CPU type first"
```

## Usage

### Basic (interactive)

```bash
git clone <repo-url> ~/repo/heypogi
cd ~/repo/heypogi
./bootstrap/bootstrap.sh
```

### Automated (no prompts)

```bash
./bootstrap/bootstrap.sh --force
```

### Skip specific components (exhaustive flag mapping)

| Flag | Skips | Notes |
|------|-------|-------|
| `--skip-agents` | `install-{claude,codex,gh}` only | dev-stack CLIs unaffected |
| `--skip-paseo` | dev-stack Paseo install + Paseo seed + user-unit startup/start | opencode/openchamber still installed |
| `--skip-dotfiles` | `setup-env install` | Requires pre-existing env (exit 3 otherwise - a precondition, not a pass) |
| `--skip-services` | `startup install` + `start` only | packages + seed still converge |

```bash
./bootstrap/bootstrap.sh --skip-agents     # Skip Claude/Codex/gh
./bootstrap/bootstrap.sh --skip-paseo      # Skip Paseo entirely
./bootstrap/bootstrap.sh --skip-dotfiles   # Skip heypogi env (needs existing env)
./bootstrap/bootstrap.sh --skip-services   # Skip systemd setup + start
```

### Target different user

```bash
./bootstrap/bootstrap.sh --user ssdadmin
```

`--user TARGET` runs every leaf as TARGET (`sudo -u` down-switch when
privileged): user-scoped state lands in `~TARGET` with `XDG_RUNTIME_DIR=/run/user/<uid>`,
a userspace-first PATH, and the systemd user bus for TARGET. Only apt,
linger, and legacy-unit removal use sudo (logged, dry-run aware). Root
without `--user` is rejected - leaves are never run wholesale as root.

### Preflight (things only you can do, checked first)

Before any mutation - and before the confirmation prompt - bootstrap
verifies three preconditions and stops with the exact remediation
(exit 3) on the first failure. `--force` never skips these:

1. **Env files exist** for TARGET (`~/.config/heypogi/.env-common` +
   `.env-secrets`). First-time setup is yours:
   ```bash
   bash tooling/env/setup-env.sh install   # as TARGET
   # then fill in secrets in ~/.config/heypogi/.env-secrets
   ```
2. **`PASEO_PASSWORD` is set** (env var or secrets file) whenever the
   run will start Paseo (i.e. unless `--skip-paseo`/`--skip-services`).
3. **Linger is enabled** for TARGET whenever the user unit will start:
   ```bash
   sudo loginctl enable-linger TARGET   # once, requires sudo
   ```

### Dry run (zero writes, incl. marker/logs/children)

```bash
./bootstrap/bootstrap.sh --dry-run
./bootstrap/bootstrap.sh --force --dry-run   # plan the full converge
```

### Status (last run + downstream convergence)

```bash
./bootstrap/bootstrap.sh status
```

Reports the last recorded run and aggregates every leaf `status`
(0 converged / 1 drift / 3 blocked).

## After Bootstrapping

The following steps require manual authentication (browser/credentials):

```bash
# Open a new terminal (or source ~/.bashrc)

# 1. Authenticate with Anthropic
claude
# Follow browser prompt

# 2. Authenticate with OpenAI
codex
# Select "Sign in with ChatGPT"

# 3. Authenticate with OpenCode provider
opencode
# Run /connect inside TUI

# 4. Set Paseo auth password (required for remote access)
paseo daemon set-password

# 5. Get pairing URL for mobile/desktop access
paseo daemon pair --json
```

## Service Management

After bootstrapping, use `dev-stack` to manage services:

```bash
dev-stack status      # Check all services
dev-stack start       # Start all services
dev-stack stop        # Stop all services
dev-stack restart     # Restart all
dev-stack install     # Update tools to latest
```

Or manage directly via systemd (user units, no sudo):

```bash
systemctl --user status paseo.service
systemctl --user start paseo.service
systemctl --user stop paseo.service
journalctl --user -u paseo.service -f    # Tail logs
```

One-time (requires sudo, owned by `startup install`): `sudo loginctl enable-linger <user>`.

## Files

```
bootstrap/
├── README.md          # This file
├── OPENITEMS.md       # Residual work + resolved decisions
└── bootstrap.sh       # Orchestrator (delegates to tooling/)

tooling/
├── env/               # Env owner (setup-env) + require-env guard
├── machine/           # check-prereqs + install-{claude,codex,gh}-cli
├── sources/           # External checkouts (acquired before skills)
├── skills/            # Skill-link reconcilers
├── bin/               # userspace-shims + PATH entry points
└── dev-stack/         # Paseo/config/systemd owner + user unit template
```

## Troubleshooting

**Node.js not found**
```bash
curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash -
sudo apt-get install -y nodejs
```

**Agent CLI not found after install**
```bash
# Add to PATH
echo 'export PATH="$HOME/.local/bin:$HOME/.opencode/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
```

**Claude Code install didn't finish (bootstrap printed a warning about it)**

Its installer's last step is an interactive TUI that needs a real terminal — it can't run over
a plain non-interactive SSH command. Finish it yourself from an actual interactive session:
```bash
curl -fsSL https://claude.ai/install.sh | bash
```

**Paseo daemon won't start / `systemctl --user status` shows a high, climbing restart count**
```bash
journalctl --user -u paseo.service -n 50
cat ~/.paseo/config.json
systemctl --user restart paseo.service
```
A high `NRestarts` count usually means `ExecStart` is missing `--foreground` — without it,
`paseo daemon start` forks and exits immediately, and a `Type=simple` unit treats that as the
service crashing, restarting it forever. Check `systemctl cat paseo.service` for the flag.

**OpenCode crashes with "CPU lacks AVX support" / segfault**

The VM's CPU type doesn't expose AVX to the guest — see the prerequisites table above. This is a
host-level (Proxmox) fix, not something installable in-guest.

**OpenChamber not running**
```bash
dev-stack start openchamber
# or
openchamber serve --host 0.0.0.0 --port 7777
```

# Heypogi Bootstrap

One-shot script to set up a machine as an AI Agentic Development VM.

## What This Does

Running `bootstrap.sh` on a machine will:

1. **Verify prerequisites** — checks for Node.js 22+, npm, git, curl, Docker, uv
2. **Install AI agent CLIs** — Claude Code (Anthropic), Codex CLI (OpenAI), GitHub CLI
3. **Install the Dev Stack** — delegates to `tooling/scripts/dev-stack.sh install -a all`
   to install/update OpenCode, Paseo, and OpenChamber, so bootstrap never duplicates
   dev-stack's install logic
4. **Configure heypogi environment** — sets `HEYPOGI_ROOT`, `OPENCODE_CONFIG_DIR`, installs skills
5. **Configure Paseo** — daemon config, orchestration preferences, systemd service
6. **Install dev-stack** — management script for services; also starts Paseo via
   `dev-stack.sh start -a paseo` once the systemd service is enabled

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
| **Docker** (optional) | Container workloads | Install via Docker's official repo |
| **uv** (optional) | Python package manager | `curl -LsSf https://astral.sh/uv/install.sh \| sh` |
| **Internet access** | Download tools | Required |
| **sudo privileges** | Install packages, systemd | Required |

### Quick check

```bash
# Verify prerequisites
node --version   # Should be v22.x.x
npm --version    # Should be 10.x.x
git --version    # Any recent version
curl --version   # Any recent version
docker --version # Optional but recommended
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

### Skip specific components

```bash
./bootstrap/bootstrap.sh --skip-agents     # Skip Claude/Codex/OpenCode
./bootstrap/bootstrap.sh --skip-paseo      # Skip Paseo/OpenChamber
./bootstrap/bootstrap.sh --skip-dotfiles   # Skip heypogi env vars
./bootstrap/bootstrap.sh --skip-services   # Skip systemd setup
```

### Target different user

```bash
./bootstrap/bootstrap.sh --user ssdadmin
```

### Dry run

```bash
./bootstrap/bootstrap.sh --dry-run
```

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

Or manage directly via systemd:

```bash
sudo systemctl status paseo.service
sudo systemctl start paseo.service
sudo systemctl stop paseo.service
journalctl -u paseo.service -f    # Tail logs
```

## Files

```
bootstrap/
├── README.md          # This file
└── bootstrap.sh       # Main bootstrap script

tooling/scripts/
└── dev-stack.sh       # Service management (installed by bootstrap.sh)
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

**Paseo daemon won't start / `systemctl status` shows a high, climbing restart count**
```bash
journalctl -u paseo.service -n 50
cat ~/.paseo/config.json
sudo systemctl restart paseo.service
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

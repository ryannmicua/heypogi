#!/usr/bin/env bash
#=======================================================================
# Script:    bootstrap.sh
# Purpose:   Bootstrap a machine as an AI Agentic Development VM.
#            Sets up Claude Code, Codex, OpenCode, Paseo, and dev tools.
# Usage:     ./bootstrap/bootstrap.sh [options]
#
# Options:
#   --user USER        Target user (default: current user)
#   --skip-agents      Skip AI agent CLI installation (Claude, Codex, OpenCode)
#   --skip-paseo       Skip Paseo/OpenChamber installation
#   --skip-dotfiles    Skip heypogi dotfiles setup
#   --skip-services    Skip systemd service setup
#   --force            Skip confirmation prompts
#   --dry-run          Preview without making changes
#   --help             Show this help
#
# This script:
#   1. Verifies base environment (Node.js, npm, curl, git, Docker)
#   2. Installs AI agent CLIs (Claude Code, Codex CLI, OpenCode)
#   3. Installs orchestration tools (Paseo, OpenChamber)
#   4. Configures heypogi dotfiles and environment
#   5. Sets up systemd services for always-on daemons
#
# Prereqs:
#   - Ubuntu 22.04+ / Debian 12+
#   - Internet access
#   - sudo privileges
#   - heypogi repo cloned (this repo)
#
# Author:    Ops Team
# Created:   2026-08-21
#=======================================================================
set -euo pipefail

# --- Constants ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HEYPOGI_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# --- Defaults ---
TARGET_USER="${TARGET_USER:-$(whoami)}"
SKIP_AGENTS=false
SKIP_PASEO=false
SKIP_DOTFILES=false
SKIP_SERVICES=false
FORCE=false
DRY_RUN=false

# --- Colors ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# --- Helpers ---
echo_info()    { echo -e "${BLUE}INFO:${NC} $*"; }
echo_success() { echo -e "${GREEN}OK:${NC} $*"; }
echo_warn()    { echo -e "${YELLOW}WARN:${NC} $*"; }
echo_err()     { echo -e "${RED}ERROR:${NC} $*" >&2; }

run() {
    if [[ "$DRY_RUN" == true ]]; then
        echo -e "${CYAN}[DRY-RUN]${NC} $*"
        return 0
    fi
    "$@"
}

run_as_user() {
    if [[ "$DRY_RUN" == true ]]; then
        echo -e "${CYAN}[DRY-RUN]${NC} (as $TARGET_USER) $*"
    else
        sudo -u "$TARGET_USER" "$@"
    fi
}

confirm() {
    local prompt="$1"
    if [[ "$FORCE" == true ]]; then
        return 0
    fi
    echo -n "$prompt [Y/n] "
    read -r choice
    [[ "$choice" =~ ^[Nn] ]] && return 1
    return 0
}

# --- Help ---
show_help() {
    sed -n '3,/^$/ s/^# //p' "$0"
    exit 0
}

# --- Parse args ---
while [[ $# -gt 0 ]]; do
    case "$1" in
        --user)           TARGET_USER="$2"; shift 2 ;;
        --skip-agents)    SKIP_AGENTS=true; shift ;;
        --skip-paseo)     SKIP_PASEO=true; shift ;;
        --skip-dotfiles)  SKIP_DOTFILES=true; shift ;;
        --skip-services)  SKIP_SERVICES=true; shift ;;
        --force)          FORCE=true; shift ;;
        --dry-run)        DRY_RUN=true; shift ;;
        --help)           show_help ;;
        *)                echo_err "Unknown argument: $1"; show_help ;;
    esac
done

# --- Validate ---
if ! id "$TARGET_USER" &>/dev/null; then
    echo_err "User '$TARGET_USER' does not exist."
    exit 1
fi

TARGET_HOME=$(eval echo "~$TARGET_USER")

echo -e "${BLUE}========================================================================${NC}"
echo -e "${BLUE}  AI Agentic Dev VM Bootstrap${NC}"
echo -e "${BLUE}========================================================================${NC}"
echo -e "  Target user:      ${GREEN}$TARGET_USER${NC}"
echo -e "  Home directory:   ${GREEN}$TARGET_HOME${NC}"
echo -e "  Heypogi root:     ${GREEN}$HEYPOGI_ROOT${NC}"
echo -e "  Skip agents:      ${YELLOW}$SKIP_AGENTS${NC}"
echo -e "  Skip Paseo:       ${YELLOW}$SKIP_PASEO${NC}"
echo -e "  Skip dotfiles:    ${YELLOW}$SKIP_DOTFILES${NC}"
echo -e "  Skip services:    ${YELLOW}$SKIP_SERVICES${NC}"
echo -e "${BLUE}========================================================================${NC}"
echo ""

if ! confirm "Proceed with bootstrapping?"; then
    echo_info "Aborted."
    exit 0
fi

# ======================================================================
# Step 1: Verify base environment
# ======================================================================
echo ""
echo_info "Step 1: Verifying base environment..."

# Node.js
if ! command -v node &>/dev/null; then
    echo_err "Node.js not found. Run cloud-init first or install manually:"
    echo_err "  curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash -"
    echo_err "  sudo apt-get install -y nodejs"
    exit 1
fi
echo_success "Node.js $(node --version)"

# npm
if ! command -v npm &>/dev/null; then
    echo_err "npm not found."
    exit 1
fi
echo_success "npm $(npm --version)"

# curl
if ! command -v curl &>/dev/null; then
    echo_warn "curl not found. Installing..."
    run apt-get update -qq
    run apt-get install -y -qq curl
fi
echo_success "curl"

# git
if ! command -v git &>/dev/null; then
    echo_warn "git not found. Installing..."
    run apt-get update -qq
    run apt-get install -y -qq git
fi
echo_success "git $(git --version | awk '{print $3}')"

# Docker
if ! command -v docker &>/dev/null; then
    echo_warn "Docker not found. Install manually or use cloud-init template."
fi

# uv
if ! command -v uv &>/dev/null; then
    echo_warn "uv not found. Installing..."
    run bash -c 'curl -LsSf https://astral.sh/uv/install.sh | sh'
    export PATH="$HOME/.local/bin:$PATH"
fi
echo_success "uv $(uv --version 2>/dev/null || echo 'installed')"

# ======================================================================
# Step 2: Install AI Agent CLIs
# ======================================================================
if [[ "$SKIP_AGENTS" == false ]]; then
    echo ""
    echo_info "Step 2: Installing AI Agent CLIs..."
    
    # Claude Code
    # NOTE: claude's installer runs an interactive TUI ("claude install") as
    # its last step to set up the launcher/shell integration. Over a
    # non-interactive session (e.g. `ssh host 'bootstrap.sh --force'` with no
    # pty) that TUI hangs indefinitely instead of failing - there is no
    # documented non-interactive/CI flag for it. Bound it with `timeout` so
    # bootstrap can't hang forever, and tell the operator to finish it by hand.
    echo_info "Installing Claude Code..."
    if ! sudo -u "$TARGET_USER" bash -c 'PATH="$HOME/.local/bin:$HOME/.opencode/bin:$PATH"; command -v claude' &>/dev/null; then
        if run_as_user timeout 90 bash -c 'curl -fsSL https://claude.ai/install.sh | bash'; then
            run_as_user bash -c 'echo "export PATH=\"\$HOME/.local/bin:\$PATH\"" >> ~/.bashrc'
        else
            echo_warn "Claude Code install did not finish automatically (its installer needs a real interactive terminal)."
            echo_warn "Finish it yourself: SSH in interactively and run: curl -fsSL https://claude.ai/install.sh | bash"
        fi
    fi
    sudo -u "$TARGET_USER" bash -c 'PATH="$HOME/.local/bin:$HOME/.opencode/bin:$PATH"; command -v claude' &>/dev/null && echo_success "Claude Code" || echo_warn "Claude Code - needs manual interactive install (see above)"

    # Codex CLI
    echo_info "Installing Codex CLI..."
    if ! sudo -u "$TARGET_USER" bash -c 'PATH="$HOME/.local/bin:$HOME/.opencode/bin:$PATH"; command -v codex' &>/dev/null; then
        run_as_user bash -c 'curl -fsSL https://chatgpt.com/codex/install.sh | sh'
    fi
    sudo -u "$TARGET_USER" bash -c 'PATH="$HOME/.local/bin:$HOME/.opencode/bin:$PATH"; command -v codex' &>/dev/null && echo_success "Codex CLI" || echo_warn "Codex CLI - may need manual PATH setup"

    # GitHub CLI
    echo_info "Installing GitHub CLI..."
    if ! command -v gh &>/dev/null; then
        run bash -c 'curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg 2>/dev/null'
        run bash -c 'echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | tee /etc/apt/sources.list.d/github-cli.list > /dev/null'
        run apt-get update -qq
        run apt-get install -y -qq gh
    fi
    command -v gh &>/dev/null && echo_success "GitHub CLI" || echo_warn "GitHub CLI - may need manual install"
else
    echo ""
    echo_info "Step 2: Skipping AI Agent CLIs"
fi

# ======================================================================
# Step 3: Install the Dev Stack (OpenCode, OpenChamber, Paseo)
# ======================================================================
DEV_STACK_SRC="$HEYPOGI_ROOT/tooling/dev-stack/dev-stack.sh"

if [[ "$SKIP_PASEO" == false ]]; then
    echo ""
    echo_info "Step 3: Installing the Dev Stack (OpenCode, OpenChamber, Paseo)..."

    if [[ ! -f "$DEV_STACK_SRC" ]]; then
        echo_err "dev-stack.sh not found at $DEV_STACK_SRC"
        exit 1
    fi

    # Delegate install to dev-stack.sh so bootstrap and dev-stack never
    # drift into two different install code paths for the same tools.
    run bash "$DEV_STACK_SRC" install -a all -f -q
else
    echo ""
    echo_info "Step 3: Skipping Dev Stack install"
fi

# ======================================================================
# Step 4: Configure heypogi dotfiles
# ======================================================================
if [[ "$SKIP_DOTFILES" == false ]]; then
    echo ""
    echo_info "Step 4: Configuring heypogi dotfiles..."
    
    # Set environment variables in .bashrc
    bashrc="$TARGET_HOME/.bashrc"
    env_block="
# === Heypogi Environment ===
export HEYPOGI_ROOT=\"$HEYPOGI_ROOT\"
export OPENCODE_CONFIG_DIR=\"$HEYPOGI_ROOT/dotfiles/opencode\"
export PATH=\"\$HEYPOGI_ROOT/tooling/bin:\$PATH\"
# === End Heypogi ===
"
    
    if ! grep -q "HEYPOGI_ROOT" "$bashrc" 2>/dev/null; then
        echo_info "Adding environment variables to .bashrc..."
        run_as_user bash -c "echo '$env_block' >> ~/.bashrc"
        echo_success "Environment variables added"
    else
        echo_info "Environment variables already configured"
    fi
    
    # Install skills if available
    if [[ -f "$HEYPOGI_ROOT/tooling/skills/install-skills.sh" ]]; then
        echo_info "Installing skills..."
        run bash "$HEYPOGI_ROOT/tooling/skills/install-skills.sh"
    fi
    
    # Symlink (not copy) dev-stack.sh into tooling/bin if it exists, so future
    # edits to dev-stack.sh are picked up immediately instead of silently
    # drifting from a stale one-time copy.
    if [[ -f "$HEYPOGI_ROOT/tooling/dev-stack/dev-stack.sh" ]]; then
        mkdir -p "$HEYPOGI_ROOT/tooling/bin"
        ln -sf ../dev-stack/dev-stack.sh "$HEYPOGI_ROOT/tooling/bin/dev-stack"
        chmod +x "$HEYPOGI_ROOT/tooling/dev-stack/dev-stack.sh"
        echo_success "dev-stack script symlinked to tooling/bin"
    fi
    
    echo_success "Heypogi dotfiles configured"
else
    echo ""
    echo_info "Step 4: Skipping dotfiles"
fi

# ======================================================================
# Step 5: Configure Paseo
# ======================================================================
if [[ "$SKIP_PASEO" == false ]]; then
    echo ""
    echo_info "Step 5: Configuring Paseo..."
    
    PASEO_HOME="$TARGET_HOME/.paseo"
    run mkdir -p "$PASEO_HOME"
    PASEO_DOTFILES="$HEYPOGI_ROOT/dotfiles/paseo"

    # Config — seeded from the repo template (dotfiles/paseo/config.json),
    # never overwritten once present. That template deliberately has no
    # auth.password key: this repo is public, and Paseo stores the auth
    # password's bcrypt hash inline in this same file, so the live,
    # password-bearing config must never be the tracked one. Set the
    # password after provisioning with `paseo daemon set-password`.
    PASEO_CONFIG="$PASEO_HOME/config.json"
    if [[ ! -f "$PASEO_CONFIG" ]]; then
        if [[ -f "$PASEO_DOTFILES/config.json" ]]; then
            echo_info "Seeding Paseo config from dotfiles/paseo/config.json..."
            run cp "$PASEO_DOTFILES/config.json" "$PASEO_CONFIG"
        else
            echo_warn "dotfiles/paseo/config.json not found - Paseo will use its own defaults (localhost-only) until configured."
        fi
        echo_warn "Paseo auth password not set. Run 'paseo daemon set-password' after provisioning."
    fi

    # Orchestration preferences — no secrets, safe to seed as-is.
    ORCH_PREFS="$PASEO_HOME/orchestration-preferences.json"
    if [[ ! -f "$ORCH_PREFS" ]] && [[ -f "$PASEO_DOTFILES/orchestration-preferences.json" ]]; then
        echo_info "Seeding orchestration preferences from dotfiles/paseo/..."
        run cp "$PASEO_DOTFILES/orchestration-preferences.json" "$ORCH_PREFS"
    fi

    echo_success "Paseo configured"
fi

# ======================================================================
# Step 6: Setup systemd services
# ======================================================================
if [[ "$SKIP_SERVICES" == false ]] && [[ "$SKIP_PASEO" == false ]]; then
    echo ""
    echo_info "Step 6: Setting up systemd services..."
    
    PASEO_BIN=$(which paseo 2>/dev/null || echo "")
    NODE_BIN=$(which node 2>/dev/null || echo "/usr/bin/node")
    
    if [[ -n "$PASEO_BIN" ]]; then
        echo_info "Creating paseo.service..."
        cat > /etc/systemd/system/paseo.service << SVCEOF
[Unit]
Description=Paseo Agent Orchestrator Daemon
After=network.target docker.service
Wants=docker.service

[Service]
Type=simple
User=$TARGET_USER
WorkingDirectory=$TARGET_HOME
# --foreground is required: without it, "daemon start" forks a detached
# child and the launcher process exits 0 immediately, which a Type=simple
# unit reads as the service exiting and restarts forever (a real
# crash-loop, not just log noise).
ExecStart=$NODE_BIN --disable-warning=DEP0040 $PASEO_BIN daemon start --listen 0.0.0.0:6767 --web-ui --foreground
Restart=always
RestartSec=10
Environment=NODE_ENV=production
Environment=HOME=$TARGET_HOME
Environment=PASEO_HOME=$PASEO_HOME
Environment=PATH=$TARGET_HOME/.local/bin:$TARGET_HOME/.opencode/bin:/usr/local/bin:/usr/bin:/bin

[Install]
WantedBy=multi-user.target
SVCEOF
        
        run systemctl daemon-reload
        run systemctl enable paseo.service
        echo_success "paseo.service installed and enabled"

        echo_info "Starting Paseo via dev-stack..."
        run bash "$DEV_STACK_SRC" start -a paseo -q
    else
        echo_warn "Paseo binary not found, skipping systemd setup"
    fi
else
    echo ""
    echo_info "Step 6: Skipping systemd services"
fi

# ======================================================================
# Summary
# ======================================================================
echo ""
echo -e "${BLUE}========================================================================${NC}"
echo -e "${BLUE}  Provisioning Complete!${NC}"
echo -e "${BLUE}========================================================================${NC}"
echo ""
echo -e "${GREEN}Installed:${NC}"
[[ "$SKIP_AGENTS" == false ]] && {
    command -v claude &>/dev/null   && echo -e "  ✓ Claude Code"
    command -v codex &>/dev/null    && echo -e "  ✓ Codex CLI"
    command -v gh &>/dev/null       && echo -e "  ✓ GitHub CLI"
}
echo -e "  ✓ dev-stack.sh (tooling/bin/dev-stack)"
[[ "$SKIP_SERVICES" == false ]] && {
    systemctl list-unit-files paseo.service &>/dev/null 2>&1 && echo -e "  ✓ paseo.service (systemd)"
}
echo ""
if [[ "$SKIP_PASEO" == false ]] && [[ -f "$DEV_STACK_SRC" ]]; then
    echo -e "${GREEN}Dev Stack status:${NC}"
    bash "$DEV_STACK_SRC" status || true
fi
echo ""
echo -e "${YELLOW}Next Steps:${NC}"
echo -e "  1. Open a new terminal (or source ~/.bashrc)"
echo -e "  2. Authenticate AI agents:"
[[ "$SKIP_AGENTS" == false ]] && {
    echo -e "     ${CYAN}claude${NC}          # Anthropic account"
    echo -e "     ${CYAN}codex${NC}           # OpenAI account"
}
[[ "$SKIP_PASEO" == false ]] && {
    echo -e "     ${CYAN}opencode${NC}        # Run /connect inside TUI"
}
echo -e "  3. Configure Paseo:"
[[ "$SKIP_PASEO" == false ]] && {
    echo -e "     ${CYAN}paseo daemon set-password${NC}"
    echo -e "     ${CYAN}paseo daemon pair --json${NC}    # Get pairing URL"
}
echo -e "  4. Use dev-stack:"
echo -e "     ${CYAN}dev-stack status${NC}"
echo -e "     ${CYAN}dev-stack start${NC}"
echo -e ""
echo -e "${BLUE}========================================================================${NC}"

#!/usr/bin/env bash
#=======================================================================
# Script:    check-prereqs.sh
# Purpose:   Reconciler for machine-level prerequisites of the heypogi
#            dev VM (node/npm/curl/git/docker/uv/AVX). Verifies system
#            state (status) and converges installable prerequisites
#            (install). Owned by tooling/machine/; called by
#            bootstrap/bootstrap.sh. check-env.sh stays env-vars only.
# Usage:     check-prereqs.sh [status|install] [-f|--force] [-q|--quiet]
#                             [--dry-run] [-h|--help]
#
# Commands:
#   status   Read-only verification of all prerequisites (default).
#   install  apt-install curl/git/bubblewrap/uv where missing, then
#            verify. Never provisions Node.js or Docker itself.
#
# Managed state: system packages (curl, git, bubblewrap, uv) via apt.
# Network: apt registry + uv installer download (install only).
# Privilege: narrowly scoped `sudo` for apt commands only, logged
#   before execution and honored by --dry-run. User-scoped work is
#   never run as root: invoke this script as the target user.
# Exit codes: 0 converged, 1 drift/mutation failed, 2 usage error,
#   3 blocked (missing Node/npm/AVX/Docker, unreachable registry).
#=======================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

COMMAND="status"
FORCE=false
QUIET=false
DRY_RUN=false

COLOR_OUT=false
[[ -z "${NO_COLOR:-}" && -t 1 ]] && COLOR_OUT=true
COLOR_ERR=false
[[ -z "${NO_COLOR:-}" && -t 2 ]] && COLOR_ERR=true

log_info() {
    [[ "$QUIET" == true ]] && return 0
    if [[ "$COLOR_OUT" == true ]]; then printf '\033[0;34mINFO:\033[0m %s\n' "$*"; else printf 'INFO: %s\n' "$*"; fi
}
log_ok() {
    [[ "$QUIET" == true ]] && return 0
    if [[ "$COLOR_OUT" == true ]]; then printf '\033[0;32mOK:\033[0m %s\n' "$*"; else printf 'OK: %s\n' "$*"; fi
}
log_warn() {
    if [[ "$COLOR_ERR" == true ]]; then printf '\033[1;33mWARN:\033[0m %s\n' "$*" >&2; else printf 'WARN: %s\n' "$*" >&2; fi
}
log_err() {
    if [[ "$COLOR_ERR" == true ]]; then printf '\033[0;31mERROR:\033[0m %s\n' "$*" >&2; else printf 'ERROR: %s\n' "$*" >&2; fi
}
log_dry() { printf 'DRY-RUN: %s\n' "$*"; }

usage() {
    cat <<'EOF'
check-prereqs.sh - verify and converge machine prerequisites.

Usage:
  check-prereqs.sh [status] [-q|--quiet] [-h|--help]
  check-prereqs.sh install [-f|--force] [-q|--quiet] [--dry-run] [-h|--help]

Commands:
  status   Read-only check of node/npm/curl/git/docker/uv/AVX (default).
  install  Install curl, git, bubblewrap, uv via apt where missing;
           Node.js, Docker, and AVX are verified, never provisioned.

Options:
  -f, --force   Re-apply managed packages (curl/git/bubblewrap/uv)
                even when present (repair scope; declared targets only).
  -q, --quiet   Suppress INFO/OK chatter; WARN/ERROR still shown.
  --dry-run     Print the install plan without changing anything
                (status treats it as a documented no-op).
  -h, --help    Show this help (side-effect-free).

Exit codes: 0 converged, 1 drift/failed, 2 usage error, 3 blocked.
EOF
}

# --- Parse args (validate before any mutation) ---
positional=()
while [[ $# -gt 0 ]]; do
    case "$1" in
        status|install) positional+=("$1"); shift ;;
        -f|--force) FORCE=true; shift ;;
        -q|--quiet) QUIET=true; shift ;;
        --dry-run) DRY_RUN=true; shift ;;
        -h|--help) usage; exit 0 ;;
        --) shift; while [[ $# -gt 0 ]]; do positional+=("$1"); shift; done ;;
        -*) log_err "Unknown option: $1"; usage >&2; exit 2 ;;
        *) log_err "Unexpected argument: $1"; usage >&2; exit 2 ;;
    esac
done
if [[ "${#positional[@]}" -gt 1 ]]; then
    log_err "At most one command (status|install) is accepted."
    usage >&2
    exit 2
fi
[[ "${#positional[@]}" -eq 1 ]] && COMMAND="${positional[0]}"

# Guard: base env must exist (plan-only mode under --dry-run per KTD7).
# shellcheck disable=SC1091
source "$SCRIPT_DIR/../env/require-env.sh" || exit 3

NODE_MIN_MAJOR=22

node_major() {
    local v
    v="$(node --version 2>/dev/null || echo '')"
    v="${v#v}"
    printf '%s' "${v%%.*}"
}

# Results: DRIFT=1 (installable gap), BLOCKED=3 (unprovisionable gap).
DRIFT=0
BLOCKED=0
BLOCK_MSGS=()

check_node() {
    if ! command -v node >/dev/null 2>&1; then
        log_err "Node.js not found (blocker)."
        BLOCK_MSGS+=("Install Node.js 22+: curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash - && sudo apt-get install -y nodejs")
        BLOCKED=1
        return
    fi
    local major
    major="$(node_major)"
    if [[ ! "$major" =~ ^[0-9]+$ ]] || [[ "$major" -lt "$NODE_MIN_MAJOR" ]]; then
        log_err "Node.js major version ${major:-unknown} < ${NODE_MIN_MAJOR} (blocker)."
        BLOCK_MSGS+=("Upgrade Node.js to 22+: curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash - && sudo apt-get install -y nodejs")
        BLOCKED=1
        return
    fi
    log_ok "Node.js $(node --version)"
}

check_npm() {
    if ! command -v npm >/dev/null 2>&1; then
        log_err "npm not found (blocker)."
        BLOCK_MSGS+=("npm ships with Node.js 22+: reinstall Node.js per the NodeSource instructions above.")
        BLOCKED=1
        return
    fi
    log_ok "npm $(npm --version)"
}

check_bin_present() {
    # $1=name, $2=apt package (empty = not apt-installable)
    local name="$1" pkg="$2"
    if command -v "$name" >/dev/null 2>&1; then
        log_ok "$name present ($(command -v "$name"))"
        return 0
    fi
    if [[ -n "$pkg" ]]; then
        log_warn "$name missing (installable via apt: $pkg)."
        DRIFT=1
    else
        log_warn "$name missing."
        DRIFT=1
    fi
    return 1
}

check_avx() {
    if grep -qi '^flags.*\bavx\b' /proc/cpuinfo 2>/dev/null; then
        log_ok "CPU exposes AVX"
    else
        log_err "CPU does not expose AVX (blocker; OpenCode segfaults without it)."
        BLOCK_MSGS+=("On Proxmox set the VM cpu: type to x86-64-v3 or newer (not kvm64/default); requires full 'qm shutdown' + 'qm start', not just an in-guest reboot.")
        BLOCKED=1
    fi
}

check_docker() {
    if command -v docker >/dev/null 2>&1; then
        log_ok "Docker $(docker --version 2>/dev/null || echo present)"
    else
        log_err "Docker not found (blocker)."
        BLOCK_MSGS+=("Install Docker via Docker's official apt repo, or via the cloud-init template.")
        BLOCKED=1
    fi
}

run_priv() {
    # Narrowly scoped sudo wrapper: logs before execution, dry-run aware.
    # Never runs user-scoped installers; apt only.
    if [[ "$DRY_RUN" == true ]]; then
        log_dry "sudo $*"
        return 0
    fi
    log_info "Running with sudo: $*"
    sudo "$@"
}

apt_install_pkg() {
    local pkg="$1"
    if [[ "$DRY_RUN" == true ]]; then
        log_dry "sudo apt-get update && sudo apt-get install -y $pkg"
        return 0
    fi
    if ! run_priv apt-get update -qq; then
        log_err "apt registry unreachable (offline?). Failing without partial mutation."
        return 3
    fi
    run_priv apt-get install -y -qq "$pkg"
}

install_uv() {
    if [[ "$DRY_RUN" == true ]]; then
        log_dry "curl -LsSf https://astral.sh/uv/install.sh | sh (timeout 120)"
        return 0
    fi
    if ! command -v curl >/dev/null 2>&1; then
        log_err "curl is required to install uv; install curl first."
        return 3
    fi
    log_info "Installing uv via official installer (timeout 120)..."
    if command -v timeout >/dev/null 2>&1; then
        timeout 120 bash -c 'curl -fLsS https://astral.sh/uv/install.sh | sh'
    else
        bash -c 'curl -fLsS https://astral.sh/uv/install.sh | sh'
    fi
}

do_status() {
    DRIFT=0; BLOCKED=0; BLOCK_MSGS=()
    log_info "Checking machine prerequisites..."
    check_node
    check_npm
    check_bin_present "curl" "curl" || true
    check_bin_present "git" "git" || true
    check_docker
    if command -v uv >/dev/null 2>&1; then
        log_ok "uv $(uv --version 2>/dev/null || echo present)"
    else
        log_warn "uv missing (installable via official installer)."
        DRIFT=1
    fi
    if command -v bwrap >/dev/null 2>&1; then
        log_ok "bubblewrap present"
    else
        log_warn "bubblewrap missing (installable via apt: bubblewrap; required for Codex sandbox)."
        DRIFT=1
    fi
    check_avx
    if [[ "$BLOCKED" -ne 0 ]]; then
        for m in "${BLOCK_MSGS[@]}"; do log_err "Remediation: $m"; done
        return 3
    fi
    [[ "$DRIFT" -ne 0 ]] && return 1
    return 0
}

do_install() {
    if [[ "$DRY_RUN" == true ]]; then
        log_dry "Plan: apt-install missing curl/git/bubblewrap; install uv if missing; verify node/npm/docker/AVX (blockers, never provisioned)."
    fi
    # Blockers first: validate before mutating where the check is free.
    DRIFT=0; BLOCKED=0; BLOCK_MSGS=()
    check_node
    check_npm
    check_avx
    check_docker
    if [[ "$BLOCKED" -ne 0 ]]; then
        for m in "${BLOCK_MSGS[@]}"; do log_err "Remediation: $m"; done
        log_err "Blocked: resolve the above before install can converge."
        return 3
    fi
    local rc=0
    # -f/--force re-applies the managed packages even when their
    # binaries resolve (repair scope: declared apt targets only).
    if ! command -v curl >/dev/null 2>&1 || [[ "$FORCE" == true ]]; then
        apt_install_pkg "curl" || rc=$?
        [[ "$rc" -eq 3 ]] && return 3
        [[ "$rc" -ne 0 ]] && return 1
    fi
    if ! command -v git >/dev/null 2>&1 || [[ "$FORCE" == true ]]; then
        apt_install_pkg "git" || rc=$?
        [[ "$rc" -eq 3 ]] && return 3
        [[ "$rc" -ne 0 ]] && return 1
    fi
    if ! command -v bwrap >/dev/null 2>&1 || [[ "$FORCE" == true ]]; then
        apt_install_pkg "bubblewrap" || rc=$?
        [[ "$rc" -eq 3 ]] && return 3
        [[ "$rc" -ne 0 ]] && return 1
    fi
    if ! command -v uv >/dev/null 2>&1 || [[ "$FORCE" == true ]]; then
        install_uv || return 1
    fi
    if [[ "$DRY_RUN" == true ]]; then
        log_dry "Verify-only in dry-run; no writes performed."
        return 0
    fi
    hash -r 2>/dev/null || true
    do_status
}

case "$COMMAND" in
    status) do_status ;;
    install) do_install ;;
esac

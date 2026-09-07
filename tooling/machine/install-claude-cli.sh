#!/usr/bin/env bash
#=======================================================================
# Script:    install-claude-cli.sh
# Purpose:   Reconciler for the Claude Code CLI. Verifies presence
#            (status) and converges via the official installer with a
#            `timeout 90` bound on its interactive TUI tail (install).
# Usage:     install-claude-cli.sh [status|install] [-f|--force]
#                                  [-q|--quiet] [--dry-run] [-h|--help]
#
# Managed state: `claude` binary on the userspace PATH.
# Network: https://claude.ai/install.sh (install only, curl -f,
#   finite timeouts). Offline registry/installer reachability is a
#   blocker (exit 3), never suppressed.
# Privilege: none. Runs as the target user; never uses sudo.
# Exit codes: 0 converged, 1 drift/failed/incomplete, 2 usage error,
#   3 blocked (installer unreachable).
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
install-claude-cli.sh - verify and install the Claude Code CLI.

Usage:
  install-claude-cli.sh [status] [-q|--quiet] [-h|--help]
  install-claude-cli.sh install [-f|--force] [-q|--quiet] [--dry-run] [-h|--help]

Commands:
  status   Read-only check that `claude` resolves on PATH (default).
  install  Run the official installer (bounded by `timeout 90` because
           its last step needs a real interactive terminal).

Options:
  -f, --force   Re-run the installer even when `claude` is present.
  -q, --quiet   Suppress INFO/OK chatter; WARN/ERROR still shown.
  --dry-run     Print the install plan without network or writes.
  -h, --help    Show this help (side-effect-free).

Exit codes: 0 converged, 1 drift/failed/incomplete, 2 usage, 3 blocked.
EOF
}

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

claude_present() { command -v claude >/dev/null 2>&1; }

do_status() {
    if claude_present; then
        log_ok "Claude Code present ($(command -v claude))"
        return 0
    fi
    log_warn "Claude Code missing."
    return 1
}

do_install() {
    if claude_present && [[ "$FORCE" != true ]]; then
        log_ok "Claude Code already installed ($(command -v claude)); nothing to do."
        return 0
    fi
    if [[ "$DRY_RUN" == true ]]; then
        log_dry "timeout 90 bash -c 'curl -fsSL https://claude.ai/install.sh | bash' (as target user, no sudo)"
        log_dry "On TUI timeout: manual fallback 'curl -fsSL https://claude.ai/install.sh | bash' from an interactive shell."
        return 0
    fi
    if ! command -v curl >/dev/null 2>&1; then
        log_err "curl is required by the Claude installer and is missing."
        log_err "Remediation: run tooling/machine/check-prereqs.sh install first."
        return 3
    fi
    log_info "Installing Claude Code (timeout 90; installer tail needs a real terminal)..."
    local rc=0
    if command -v timeout >/dev/null 2>&1; then
        timeout 90 bash -c 'curl -fsSL --connect-timeout 15 --max-time 60 https://claude.ai/install.sh | bash' || rc=$?
    else
        bash -c 'curl -fsSL --connect-timeout 15 --max-time 60 https://claude.ai/install.sh | bash' || rc=$?
    fi
    if [[ "$rc" -ne 0 ]]; then
        if [[ "$rc" -eq 124 ]]; then
            log_warn "Claude Code install timed out (its installer needs a real interactive terminal)."
        else
            log_warn "Claude Code installer exited $rc (offline registry? exit 3 class)."
        fi
        log_warn "Finish it yourself: SSH in interactively and run: curl -fsSL https://claude.ai/install.sh | bash"
        # Distinguish unreachable-installer (blocked) from TUI hang (incomplete).
        hash -r 2>/dev/null || true
        if claude_present; then
            log_ok "Claude Code present after install attempt."
            return 0
        fi
        # Probe reachability to classify: reuse curl against the installer URL.
        if ! curl -fsSL --connect-timeout 10 --max-time 20 -o /dev/null https://claude.ai/install.sh 2>/dev/null; then
            log_err "Installer URL unreachable; treating as blocked (exit 3)."
            return 3
        fi
        return 1
    fi
    hash -r 2>/dev/null || true
    if claude_present; then
        log_ok "Claude Code installed ($(command -v claude))"
        return 0
    fi
    log_warn "Claude Code install finished but 'claude' is not on PATH; open a new shell and re-run status."
    log_warn "If needed, finish manually: curl -fsSL https://claude.ai/install.sh | bash"
    return 1
}

case "$COMMAND" in
    status) do_status ;;
    install) do_install ;;
esac

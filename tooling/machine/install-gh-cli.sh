#!/usr/bin/env bash
#=======================================================================
# Script:    install-gh-cli.sh
# Purpose:   Reconciler for the GitHub CLI (gh) on Debian/Ubuntu.
#            Verifies presence (status) and converges via the official
#            apt keyring/repo (install). Owned by tooling/machine/;
#            called by bootstrap/bootstrap.sh.
# Usage:     install-gh-cli.sh [status|install] [-f|--force]
#                              [-q|--quiet] [--dry-run] [-h|--help]
#
# Managed state: /usr/share/keyrings/githubcli-archive-keyring.gpg,
#   /etc/apt/sources.list.d/github-cli.list, `gh` package.
# Network: cli.github.com key + package repo (install only, curl -f,
#   finite timeouts). Unreachable registry is a blocker (exit 3).
# Privilege: narrowly scoped `sudo` for keyring/repo/apt commands
#   only, logged before execution and honored by --dry-run.
# Exit codes: 0 converged, 1 drift/failed, 2 usage error, 3 blocked.
#=======================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

COMMAND="status"
FORCE=false
QUIET=false
DRY_RUN=false

KEYRING="/usr/share/keyrings/githubcli-archive-keyring.gpg"
REPO_LIST="/etc/apt/sources.list.d/github-cli.list"

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
install-gh-cli.sh - verify and install the GitHub CLI (Debian/Ubuntu).

Usage:
  install-gh-cli.sh [status] [-q|--quiet] [-h|--help]
  install-gh-cli.sh install [-f|--force] [-q|--quiet] [--dry-run] [-h|--help]

Commands:
  status   Read-only check that `gh` resolves on PATH (default).
  install  Add the GitHub apt keyring/repo and install `gh`.

Options:
  -f, --force   Re-apply keyring/repo/package even when `gh` is present.
  -q, --quiet   Suppress INFO/OK chatter; WARN/ERROR still shown.
  --dry-run     Print the install plan without network or writes.
  -h, --help    Show this help (side-effect-free).

Exit codes: 0 converged, 1 drift/failed, 2 usage error, 3 blocked.
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

gh_present() { command -v gh >/dev/null 2>&1; }

do_status() {
    if gh_present; then
        log_ok "GitHub CLI present ($(command -v gh): $(gh --version 2>/dev/null | head -1 || echo gh))"
        return 0
    fi
    log_warn "GitHub CLI missing."
    return 1
}

run_priv() {
    if [[ "$DRY_RUN" == true ]]; then
        log_dry "sudo $*"
        return 0
    fi
    log_info "Running with sudo: $*"
    sudo "$@"
}

expected_repo_line() {
    local arch
    arch="$(dpkg --print-architecture 2>/dev/null || echo amd64)"
    printf 'deb [arch=%s signed-by=%s] https://cli.github.com/packages stable main' "$arch" "$KEYRING"
}

do_install() {
    if gh_present && [[ "$FORCE" != true ]]; then
        log_ok "GitHub CLI already installed ($(command -v gh)); nothing to do."
        return 0
    fi
    if [[ "$DRY_RUN" == true ]]; then
        log_dry "sudo curl -fsSL .../githubcli-archive-keyring.gpg -o $KEYRING"
        log_dry "sudo tee $REPO_LIST (compare-before-write)"
        log_dry "sudo apt-get update && sudo apt-get install -y gh"
        return 0
    fi
    if ! command -v curl >/dev/null 2>&1; then
        log_err "curl is required to fetch the keyring and is missing."
        log_err "Remediation: run tooling/machine/check-prereqs.sh install first."
        return 3
    fi
    local apt_rc=0
    if [[ ! -f "$KEYRING" || "$FORCE" == true ]]; then
        log_info "Installing GitHub CLI keyring..."
        if ! run_priv curl -fsSL --connect-timeout 15 --max-time 60 https://cli.github.com/packages/githubcli-archive-keyring.gpg -o "$KEYRING"; then
            log_err "Keyring download unreachable (offline?). Failing without partial mutation."
            return 3
        fi
    else
        log_info "Keyring already present; skipping."
    fi
    local want
    want="$(expected_repo_line)"
    if [[ ! -f "$REPO_LIST" ]] || ! grep -Fxq "$want" "$REPO_LIST" 2>/dev/null || [[ "$FORCE" == true ]]; then
        log_info "Writing $REPO_LIST ..."
        printf '%s\n' "$want" | run_priv tee "$REPO_LIST" >/dev/null
    else
        log_info "apt repo already configured; skipping."
    fi
    if ! run_priv apt-get update -qq; then
        log_err "apt registry unreachable (offline?). Failing without partial mutation."
        apt_rc=3
        return "$apt_rc"
    fi
    if ! run_priv apt-get install -y -qq gh; then
        log_err "apt install of gh failed."
        return 1
    fi
    hash -r 2>/dev/null || true
    if gh_present; then
        log_ok "GitHub CLI installed ($(command -v gh))"
        return 0
    fi
    log_err "gh install finished but 'gh' is not on PATH."
    return 1
}

case "$COMMAND" in
    status) do_status ;;
    install) do_install ;;
esac

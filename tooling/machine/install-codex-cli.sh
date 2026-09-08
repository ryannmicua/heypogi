#!/usr/bin/env bash
#=======================================================================
# Script:    install-codex-cli.sh
# Purpose:   Reconciler for the OpenAI Codex CLI on macOS, Linux, or
#            WSL2. Verifies Codex + Linux sandbox prerequisites
#            (status) and converges them (install). Owned by
#            tooling/machine/; called by bootstrap/bootstrap.sh.
# Usage:     install-codex-cli.sh [status|install] [-f|--force]
#                                  [-q|--quiet] [--dry-run] [-h|--help]
#
# Managed state: bubblewrap/AppArmor (Linux), `codex` binary on the
#   userspace PATH.
# Network: https://chatgpt.com/codex/install.sh (install only,
#   curl -f, finite timeouts). Unreachable installer is a blocker
#   (exit 3), never suppressed.
# Privilege: narrowly scoped `sudo` for bubblewrap/AppArmor package
#   and profile steps only, logged before execution and honored by
#   --dry-run. The Codex installer itself always runs as the target
#   user, never as root.
# Exit codes: 0 converged, 1 drift/failed/incomplete, 2 usage error,
#   3 blocked (missing curl, unsupported OS/distro, offline).
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
Install and verify OpenAI Codex CLI on macOS, Linux, or WSL2.

Usage:
  install-codex-cli.sh [status] [-q|--quiet] [-h|--help]
  install-codex-cli.sh install [-f|--force] [-q|--quiet] [--dry-run] [-h|--help]

Commands:
  status   Check Codex CLI and Linux sandbox prerequisites without changing the system (default).
  install  Install Linux sandbox prerequisites, install/update Codex CLI, and verify both.

Options:
  -f, --force   Re-run the Codex installer even when `codex` is present.
  -q, --quiet   Suppress INFO/OK chatter; WARN/ERROR still shown.
  --dry-run     Print the install plan without network, sudo, or writes.
  -h, --help    Show this help (side-effect-free).

Exit codes: 0 converged, 1 drift/failed, 2 usage error, 3 blocked.
EOF
}

# --- Parse args (validate before any probe with side effects) ---
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

platform="$(uname -s)"
os_id=""
os_version=""
if [[ "${platform}" == "Linux" && -r /etc/os-release ]]; then
  # shellcheck disable=SC1091
  . /etc/os-release
  os_id="${ID:-}"
  os_version="${VERSION_ID:-}"
fi

run_priv() {
    # Narrowly scoped sudo: bubblewrap/AppArmor steps only, logged
    # before execution, dry-run aware. Never wraps the Codex installer.
    if [[ "$DRY_RUN" == true ]]; then
        log_dry "sudo $*"
        return 0
    fi
    log_info "Running with sudo: $*"
    sudo "$@"
}

bwrap_smoke_test() {
  local -a command=(
    bwrap
    --ro-bind / /
    --dev /dev
    --proc /proc
    --unshare-user
    --unshare-pid
    --
    /bin/true
  )

  if command -v timeout >/dev/null 2>&1; then
    timeout 10 "${command[@]}"
  else
    "${command[@]}"
  fi
}

codex_present() { command -v codex >/dev/null 2>&1; }

show_status() {
  local failed=0

  if codex_present; then
    log_ok "Codex CLI: $(codex --version 2>/dev/null || echo present) ($(command -v codex))"
  else
    log_warn "Codex CLI: missing"
    failed=1
  fi

  if [[ "${platform}" == "Linux" ]]; then
    if command -v bwrap >/dev/null 2>&1; then
      log_ok "Bubblewrap: $(bwrap --version 2>/dev/null || echo present) ($(command -v bwrap))"
      if bwrap_smoke_test >/dev/null 2>&1; then
        log_ok "Sandbox: ready"
      else
        log_warn "Sandbox: bubblewrap cannot create the required user namespace"
        failed=1
      fi
    else
      log_warn "Bubblewrap: missing"
      log_warn "Sandbox: not ready"
      failed=1
    fi
  else
    log_info "Sandbox: uses the macOS built-in Seatbelt framework"
  fi

  return "${failed}"
}

install_bubblewrap() {
  if command -v bwrap >/dev/null 2>&1; then
    log_info "Bubblewrap is already installed: $(bwrap --version 2>/dev/null || echo present)"
    return 0
  fi

  case "${os_id}" in
    ubuntu|debian)
      run_priv timeout 180 apt-get update || return 3
      run_priv timeout 300 apt-get install -y bubblewrap || return 3
      ;;
    fedora)
      run_priv dnf install -y bubblewrap || return 3
      ;;
    *)
      log_err "Unsupported Linux distribution: ${os_id:-unknown}."
      log_err "Remediation: install the package that provides 'bwrap', then rerun this installer."
      return 3
      ;;
  esac
}

repair_ubuntu_2404_apparmor() {
  if [[ "${os_id}" != "ubuntu" || "${os_version}" != "24.04" ]]; then
    return 1
  fi

  log_info "Bubblewrap user namespaces are blocked; loading Ubuntu 24.04's AppArmor profile."
  run_priv timeout 180 apt-get update || return 3
  run_priv timeout 300 apt-get install -y apparmor-profiles apparmor-utils || return 3

  local source_profile="/usr/share/apparmor/extra-profiles/bwrap-userns-restrict"
  local target_profile="/etc/apparmor.d/bwrap-userns-restrict"
  if [[ ! -f "${source_profile}" ]]; then
    if [[ "$DRY_RUN" == true ]]; then
        log_dry "sudo install -m 0644 ${source_profile} ${target_profile} && sudo apparmor_parser -r ${target_profile}"
        return 0
    fi
    log_err "Expected AppArmor profile is unavailable: ${source_profile}"
    return 1
  fi

  run_priv install -m 0644 "${source_profile}" "${target_profile}"
  run_priv apparmor_parser -r "${target_profile}"
}

install_codex() {
  if codex_present && [[ "$FORCE" != true ]]; then
    log_info "Codex CLI already installed ($(command -v codex)); skipping vendor installer (use -f to re-run)."
    return 0
  fi
  if ! command -v curl >/dev/null 2>&1; then
    log_err "curl is required by the official Codex installer and is missing."
    log_err "Remediation: run tooling/machine/check-prereqs.sh install first."
    return 3
  fi

  if [[ "$DRY_RUN" == true ]]; then
    log_dry "curl -fsSL --connect-timeout 15 --max-time 60 https://chatgpt.com/codex/install.sh | sh (as target user, no sudo)"
    return 0
  fi
  log_info "Running the official OpenAI Codex installer (as target user, no sudo)."
  local rc=0
  if command -v timeout >/dev/null 2>&1; then
    timeout 180 bash -c 'curl -fsSL --connect-timeout 15 --max-time 120 https://chatgpt.com/codex/install.sh | sh' || rc=$?
  else
    bash -c 'curl -fsSL --connect-timeout 15 --max-time 120 https://chatgpt.com/codex/install.sh | sh' || rc=$?
  fi
  if [[ "$rc" -ne 0 ]]; then
    # Normalize vendor/timeout exits to the contract map: unreachable
    # installer is blocked (3), anything else is failed/incomplete (1).
    if ! curl -fsSL --connect-timeout 10 --max-time 20 -o /dev/null https://chatgpt.com/codex/install.sh 2>/dev/null; then
      log_err "Codex installer unreachable (offline?)."
      return 3
    fi
    log_err "Codex installer exited $rc."
    return 1
  fi
  hash -r 2>/dev/null || true
}

do_status() {
    show_status
}

do_install() {
    if [[ "$DRY_RUN" == true ]]; then
        log_dry "Plan: ensure bubblewrap (+AppArmor repair on Ubuntu 24.04) on Linux; run vendor Codex installer as target user; verify."
    fi
    case "${platform}" in
      Darwin) ;;
      Linux)
        install_bubblewrap || return $?
        if [[ "$DRY_RUN" != true ]] && ! bwrap_smoke_test; then
          if ! repair_ubuntu_2404_apparmor || ! bwrap_smoke_test; then
            log_err "Bubblewrap is installed but its user-namespace smoke test still fails."
            log_err "Do not disable AppArmor's restriction globally without reviewing the security tradeoff."
            return 1
          fi
        fi
        ;;
      *)
        log_err "Unsupported platform: ${platform}. Use the official Windows installation instructions."
        return 3
        ;;
    esac

    if ! install_codex; then
        local rc=$?
        if [[ "$rc" -eq 3 ]]; then
            log_err "Codex installer unreachable (offline?) or curl missing."
            return 3
        fi
        return "$rc"
    fi

    if [[ "$DRY_RUN" == true ]]; then
        log_dry "Verify-only in dry-run; no writes performed."
        return 0
    fi

    if ! codex_present; then
      log_warn "Codex installed, but 'codex' is not yet on PATH. Open a new terminal and run this script with 'status'."
      return 1
    fi

    show_status || return 1
    log_ok "Installation verified. Run 'codex' in a project directory to sign in."
}

case "$COMMAND" in
    status) do_status ;;
    install) do_install ;;
esac

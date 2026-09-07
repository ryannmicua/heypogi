#!/usr/bin/env bash
#=======================================================================
# Script:    clone-knowledge-source.sh
# Purpose:   Ensure the Compound Knowledge source checkout exists at external/compound-knowledge/
#            (clone on first run, pull latest only with -f/--force or
#            interactive approval). Called before the CE/knowledge skill
#            installers by bootstrap/bootstrap.sh (R26 ordering).
# Usage:     clone-knowledge-source.sh [-f|--force] [-q|--quiet] [--dry-run] [-h|--help]
#
# Managed state: external/compound-knowledge/ git checkout (+ freshness ledger via
#   record-external-repo-update.sh).
# Network: https://github.com/EveryInc/compound-knowledge-plugin.git (clone/pull only; HTTPS, finite timeouts).
#   Unreachable remote is a blocker (exit 3), never suppressed.
# Privilege: none. Exit codes: 0 present/converged, 1 failed,
#   2 usage error, 3 blocked (offline).
# NOTE: -q/--quiet controls output only; use -f/--force for
#   non-interactive pulls (quiet never implies consent).
#=======================================================================
set -euo pipefail

FORCE=false
QUIET=false
DRY_RUN=false

log_info() { [[ "$QUIET" == true ]] && return 0; printf 'INFO: %s\n' "$*"; }
log_ok() { [[ "$QUIET" == true ]] && return 0; printf 'OK: %s\n' "$*"; }
log_warn() { printf 'WARN: %s\n' "$*" >&2; }
log_err() { printf 'ERROR: %s\n' "$*" >&2; }
log_dry() { printf 'DRY-RUN: %s\n' "$*"; }

usage() {
  cat <<'EOF'
Clones the Compound Knowledge source repository into external/compound-knowledge/.

Usage:
  bash tooling/sources/clone-knowledge-source.sh [-f|--force] [-q|--quiet] [--dry-run] [-h|--help]

Options:
  -f, --force   Pull latest when already cloned (no prompt).
  -q, --quiet   Suppress INFO/OK chatter (never implies consent).
  --dry-run     Print the clone/pull plan without network or writes.
  -h, --help    Show this help (side-effect-free).

Exit codes: 0 present/converged, 1 failed, 2 usage error, 3 blocked.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -f|--force) FORCE=true; shift ;;
    -q|--quiet) QUIET=true; shift ;;
    --dry-run) DRY_RUN=true; shift ;;
    -h|--help) usage; exit 0 ;;
    --) shift; while [[ $# -gt 0 ]]; do log_err "Unexpected argument: $1"; usage >&2; exit 2; done ;;
    -*) log_err "Unknown option: $1"; usage >&2; exit 2 ;;
    *) log_err "Unexpected argument: $1"; usage >&2; exit 2 ;;
  esac
done

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
repo_root="$(cd "${script_dir}/../.." && pwd -P)"
external_dir="${repo_root}/external"
target_dir="${external_dir}/compound-knowledge"
clone_url="https://github.com/EveryInc/compound-knowledge-plugin.git"
clone_args="--depth 1"
status_recorder="${script_dir}/record-external-repo-update.sh"

remote_reachable() {
  curl -fsSI --connect-timeout 10 --max-time 15 https://github.com >/dev/null 2>&1
}

git_net() {
  # Finite-timeout git wrapper so offline runs fail fast, not hung.
  if command -v timeout >/dev/null 2>&1; then
    timeout 120 git "$@"
  else
    git "$@"
  fi
}

if [[ "$DRY_RUN" == true ]]; then
  if [[ -d "${target_dir}/.git" ]]; then
    log_dry "git -C ${target_dir} pull (+ record freshness)"
  else
    log_dry "git clone ${clone_args} ${clone_url} ${target_dir} (+ record freshness)"
  fi
  exit 0
fi

if [[ ! -d "${external_dir}" ]]; then
  mkdir -p "${external_dir}"
fi

did_update=0
if [[ -d "${target_dir}" ]]; then
  if [[ ! -d "${target_dir}/.git" ]]; then
    log_err "${target_dir} exists but is not a git repository. Remove it manually and re-run."
    exit 1
  fi
  pull=false
  if [[ "$FORCE" == true ]]; then
    pull=true
  elif [[ -t 0 ]]; then
    log_info "Compound Knowledge source already cloned at: ${target_dir}"
    printf "Pull latest? [y/N] " >&2
    IFS= read -r answer || answer=""
    answer="$(printf "%s" "${answer}" | tr '[:upper:]' '[:lower:]' | xargs || true)"
    [[ "${answer}" == "y" ]] && pull=true
  else
    log_info "Compound Knowledge source present at ${target_dir}; skipping pull (non-interactive without -f)."
  fi
  if [[ "$pull" == true ]]; then
    log_info "Pulling latest..."
    if ! git_net -C "${target_dir}" pull; then
      if ! remote_reachable; then
        log_err "Remote unreachable (offline?). No partial state changed."
        exit 3
      fi
      log_err "git pull failed for Compound Knowledge."
      exit 1
    fi
    did_update=1
  fi
else
  log_info "Cloning Compound Knowledge source into ${target_dir} ..."
  if ! git_net clone --depth 1 "${clone_url}" "${target_dir}"; then
    if ! remote_reachable; then
      log_err "Remote unreachable (offline?). Nothing cloned."
      exit 3
    fi
    log_err "git clone failed for Compound Knowledge."
    exit 1
  fi
  did_update=1
fi

if [[ "${did_update}" -eq 1 ]]; then
  bash "${status_recorder}" --name compound-knowledge --repository-path "${target_dir}"
fi

if [[ "$QUIET" != true ]]; then
  printf "\n"
  printf "Compound Knowledge source: %s\n" "${target_dir}"
  printf "  Branch: "
  git -C "${target_dir}" branch --show-current
  printf "  Remote: "
  git -C "${target_dir}" remote get-url origin
  printf "\nVerify with:\n"
  printf "  ls %s\n" "${target_dir}"
  printf "  git -C %s log --oneline -3\n" "${target_dir}"
fi
log_ok "Compound Knowledge source ensured."

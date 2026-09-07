#!/usr/bin/env bash
#=======================================================================
# Script:    install-ce-skills.sh
# Purpose:   Reconciler linking the Compound Engineering plugin skills (external checkout) into ~/.agents/skills/compound-engineering.
#            Verifies link state (status) and converges the symlink
#            (install). Owned by tooling/skills/; called by
#            bootstrap/bootstrap.sh after external sources are acquired
#            (R26 ordering: sources before skills).
# Usage:     install-ce-skills.sh [status|install] [--create-dest] [-f|--force]
#                                  [-q|--quiet] [--dry-run] [-h|--help]
#
# Managed state: ~/.agents/skills/compound-engineering symlink -> external/compound-engineering/skills.
# Idempotency: a correct symlink is a no-op (exit 0). A conflicting
#   real directory is never removed (not even with -f): exit 1 with
#   remediation. A conflicting symlink/file is replaced only with -f.
# Network: none (reads the local checkout). When the source checkout
#   is absent and unacquirable, WARN + exit 1 (never a silent pass).
# Privilege: none. Exit codes: 0 converged, 1 drift/failed,
#   2 usage error, 3 blocked.
#=======================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

COMMAND="status"
CREATE_DEST=false
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
Install Compound Engineering plugin skills by linking the external checkout into ~/.agents/skills/compound-engineering.

Usage:
  bash tooling/skills/install-ce-skills.sh [status] [-q|--quiet] [-h|--help]
  bash tooling/skills/install-ce-skills.sh install [--create-dest] [-f|--force] [-q|--quiet] [--dry-run] [-h|--help]

Commands:
  status   Read-only check of the install link (default).
  install  Converge the symlink (first install, update, repair).

Options:
  --create-dest  Create ${HOME}/.agents/skills when missing (explicit consent;
                 install fails without it when the parent is absent).
  -f, --force    Replace a conflicting symlink/file with the intended
                 link (declared target only; never removes directories,
                 secrets, or wider scope).
  -q, --quiet    Suppress INFO/OK chatter; WARN/ERROR still shown.
  --dry-run      Print the plan without creating or changing anything.
  -h, --help     Show this help (side-effect-free).

Exit codes: 0 converged, 1 drift/failed, 2 usage error, 3 blocked.
EOF
}

positional=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    status|install) positional+=("$1"); shift ;;
    --create-dest) CREATE_DEST=true; shift ;;
    -f|--force) FORCE=true; shift ;;
    -q|--quiet) QUIET=true; shift ;;
    --dry-run) DRY_RUN=true; shift ;;
    -h|--help) usage; exit 0 ;;
    --) shift; while [[ $# -gt 0 ]]; do log_err "Unexpected argument: $1"; usage >&2; exit 2; done ;;
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

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
repo_root="$(cd "${script_dir}/../.." && pwd -P)"
skills_root="${repo_root}/external/compound-engineering/skills"
dest_dir="${HOME}/.agents/skills"
dest_path="${dest_dir}/compound-engineering"

resolve() { cd "$1" 2>/dev/null && pwd -P || printf '%s' "$1"; }

# Preview first: show the plan even when sources are absent, then
# still fail fast below (R26: absent sources are never a silent pass).
if [[ "$DRY_RUN" == true && ! -d "${skills_root}" ]]; then
  log_dry "ensure ${dest_dir}/ exists (only with --create-dest)"
  log_dry "converge symlink (conflicting dirs never removed)"
fi
# Source checkout must exist (R26): bootstrap acquires external/
# checkouts before skills; a direct call with absent sources fails
# loudly, never silently.
if [[ ! -d "${skills_root}" ]]; then
  log_warn "Source checkout absent: ${skills_root}."
  log_warn "Remediation: run tooling/sources/update-external-repos.sh -f, or bootstrap/bootstrap.sh --force."
  if [[ "$COMMAND" == "status" ]]; then
    exit 1
  fi
  log_err "Cannot install compound-engineering skills without sources."
  exit 1
fi
expected_target="$(resolve "${skills_root}")"

link_state() {
  # Prints: ok | missing | wrong-link | conflict-file | conflict-dir
  if [[ -L "${dest_path}" ]]; then
    local cur
    cur="$(resolve "${dest_path}")"
    if [[ "$cur" == "$expected_target" ]]; then printf 'ok'; else printf 'wrong-link'; fi
  elif [[ -e "${dest_path}" ]]; then
    if [[ -d "${dest_path}" ]]; then printf 'conflict-dir'; else printf 'conflict-file'; fi
  else
    printf 'missing'
  fi
}

do_status() {
  local st
  st="$(link_state)"
  case "$st" in
    ok) log_ok "compound-engineering converged (${dest_path} -> ${expected_target})"; return 0 ;;
    missing) log_warn "compound-engineering link missing: ${dest_path}"; return 1 ;;
    wrong-link) log_warn "compound-engineering link points elsewhere: ${dest_path} -> $(readlink "${dest_path}") (want ${expected_target})"; return 1 ;;
    conflict-file|conflict-dir) log_warn "compound-engineering destination is a conflicting ${st#conflict-}: ${dest_path}"; return 1 ;;
  esac
}

do_install() {
  if [[ "$DRY_RUN" == true ]]; then
    log_dry "ensure ${HOME}/.agents/skills/ exists (only with --create-dest)"
    log_dry "converge symlink ${dest_path} -> ${expected_target} (conflicting dirs never removed)"
    return 0
  fi
  if [[ ! -d "${dest_dir}" ]]; then
    if [[ "$CREATE_DEST" != true ]]; then
      log_err "Destination folder does not exist: ${dest_dir}"
      log_err "Remediation: re-run with --create-dest (explicit consent to create it)."
      return 1
    fi
    mkdir -p "${dest_dir}"
    log_info "Created ${dest_dir} (--create-dest)."
  fi
  local st
  st="$(link_state)"
  case "$st" in
    ok)
      log_ok "compound-engineering already converged; nothing to do."
      printf 'Installed: 0\nSkipped:   1\n'
      return 0
      ;;
    missing)
      ln -s "${expected_target}" "${dest_path}"
      log_ok "LINK: ${dest_path} -> ${expected_target}"
      printf 'Installed: 1\nSkipped:   0\n'
      return 0
      ;;
    conflict-dir)
      log_err "Blocker: ${dest_path} is a real directory, not the managed link; refusing to remove it."
      log_err "Remediation: move it aside manually, then re-run with -f."
      return 1
      ;;
    wrong-link|conflict-file)
      if [[ "$FORCE" != true ]]; then
        if [[ -t 0 ]]; then
          log_warn "Blocker: ${dest_path} exists ($st; current: $(readlink "${dest_path}" 2>/dev/null || echo non-link))."
          printf 'Replace with the managed link? [y/N] ' >&2
          IFS= read -r ans || ans=""
          ans="$(printf "%s" "${ans}" | tr '[:upper:]' '[:lower:]' | xargs || true)"
          if [[ "$ans" != "y" ]]; then
            log_warn "Declined; leaving existing destination untouched."
            printf 'Installed: 0\nSkipped:   1\n'
            return 1
          fi
        else
          log_err "Blocker: ${dest_path} exists ($st). Non-interactive without -f: failing instead of overwriting."
          log_err "Remediation: re-run with -f to replace the declared link target."
          return 1
        fi
      fi
      # Targeted replacement of the declared link/file only (never -rf).
      rm -f "${dest_path}"
      ln -s "${expected_target}" "${dest_path}"
      log_ok "LINK: ${dest_path} -> ${expected_target} (replaced $st)"
      printf 'Installed: 1\nSkipped:   0\n'
      return 0
      ;;
  esac
}

case "$COMMAND" in
  status) do_status ;;
  install) do_install ;;
esac

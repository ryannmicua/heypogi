#!/usr/bin/env bash
#=======================================================================
# Script:    update-external-repos.sh
# Purpose:   Converge all external/ checkouts by delegating to the
#            clone-*.sh scripts, then propagate the aggregate result.
#            Repo root is derived from this script's position (never
#            hardcoded). Cron-safe: passes -f (pull without prompt) and
#            -q explicitly; --quiet never implies consent on its own.
# Usage:     update-external-repos.sh [-f|--force] [-q|--quiet]
#                                      [--dry-run] [-h|--help]
#
# Managed state: external/ checkouts + external/.repo-update-status.json
#   (via children) + external/.update-cron.log (this script's log).
# Network: github.com (children only). Offline children record exit 3
#   and this script propagates failure (exit 1) without masking it.
# Preview: --dry-run passes through to every child and writes no log.
# Exit codes: 0 all converged, 1 one or more children failed,
#   2 usage error, 3 indeterminate (log dir unwritable).
#=======================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

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
update-external-repos.sh - converge all external/ checkouts.

Usage:
  update-external-repos.sh [-f|--force] [-q|--quiet] [--dry-run] [-h|--help]

Options:
  -f, --force   Pull latest in each checkout (no prompt).
  -q, --quiet   Suppress INFO/OK chatter (never implies consent).
  --dry-run     Plan only: forward to every child, write no log.
  -h, --help    Show this help (side-effect-free).

Exit codes: 0 all converged, 1 child failure, 2 usage error, 3 blocked.
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

# Default keeps historical cron behavior (converge quietly); an
# interactive caller without -f still gets prompted by children only
# when stdin is a terminal, otherwise children skip pulls safely.
if [[ "$FORCE" != true && ! -t 0 ]]; then
    log_info "Non-interactive without -f: children ensure presence but skip pulls."
fi

CHILD_ARGS=()
[[ "$FORCE" == true ]] && CHILD_ARGS+=("-f")
[[ "$QUIET" == true ]] && CHILD_ARGS+=("-q")
[[ "$DRY_RUN" == true ]] && CHILD_ARGS+=("--dry-run")

LOG_FILE="$REPO_DIR/external/.update-cron.log"

log() {
    if [[ "$DRY_RUN" == true ]]; then
        log_dry "log: $*"
        return 0
    fi
    echo "$(date -u '+%Y-%m-%d %H:%M:%S UTC') $*" >> "$LOG_FILE"
}

if [[ "$DRY_RUN" != true ]]; then
    if ! mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null || ! touch "$LOG_FILE" 2>/dev/null; then
        log_err "Cannot write log file: $LOG_FILE"
        exit 3
    fi
else
    log_dry "would append run to $LOG_FILE"
fi

log "=== Starting external repo update ==="

FAILED=0
FAILED_NAMES=()
for script in clone-ce-source.sh clone-knowledge-source.sh clone-opencode-source.sh; do
    if bash "$REPO_DIR/tooling/sources/$script" "${CHILD_ARGS[@]}" 2>&1; then
        log "OK: $script"
    else
        rc=$?
        log "FAIL: $script (exit $rc)"
        FAILED=1
        FAILED_NAMES+=("$script:$rc")
    fi
done

if [[ "$FAILED" -eq 0 ]]; then
    log "=== All repos updated successfully ==="
    log_ok "All external repos converged."
else
    log "=== Update completed with failures ==="
    log_err "Failed: ${FAILED_NAMES[*]}. Rerun with -f, or check network."
    exit 1
fi

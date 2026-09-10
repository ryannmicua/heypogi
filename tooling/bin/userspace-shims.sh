#!/usr/bin/env bash
#=======================================================================
# Script:    userspace-shims.sh
# Purpose:   Reconciler provisioning the userspace PATH layout that the
#            rootless systemd units depend on: ~/.local/bin exists,
#            ~/.local/node-bin points at the current nvm Node's bin dir
#            (via symlink-nvm-node-bin.sh, never duplicated here), the
#            npm global prefix is user-owned, and stable ~/.local/bin
#            symlinks exist for the dev-stack CLIs so unit paths like
#            %h/.local/bin/paseo resolve before the unit is enabled
#            (R32). Runs before the rootless unit install.
# Usage:     userspace-shims.sh [status|install] [-f|--force]
#                                [-q|--quiet] [--dry-run] [-h|--help]
#
# Managed state: ~/.local/bin/, ~/.local/node-bin symlink,
#   ~/.local/bin/{paseo,openchamber,opencode} symlinks, and the
#   tooling/bin/dev-stack entry point (git-ignored by decision, so it
#   is converged here instead of committed).
# Privilege: none (userspace only; never sudo). Network: none.
# Exit codes: 0 converged, 1 drift/failed, 2 usage error, 3 blocked
#   (no nvm Node available, npm prefix not user-owned).
#=======================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

COMMAND="status"
FORCE=false
QUIET=false
DRY_RUN=false

log_info() {
    [[ "$QUIET" == true ]] && return 0
    printf 'INFO: %s\n' "$*"
}
log_ok() {
    [[ "$QUIET" == true ]] && return 0
    printf 'OK: %s\n' "$*"
}
log_warn() { printf 'WARN: %s\n' "$*" >&2; }
log_err() { printf 'ERROR: %s\n' "$*" >&2; }
log_dry() { printf 'DRY-RUN: %s\n' "$*"; }

usage() {
    cat <<'EOF'
userspace-shims.sh - provision the userspace PATH layout.

Usage:
  userspace-shims.sh [status] [-q|--quiet] [-h|--help]
  userspace-shims.sh install [-f|--force] [-q|--quiet] [--dry-run] [-h|--help]

Commands:
  status   Read-only check of ~/.local/bin, ~/.local/node-bin, the npm
           prefix, and dev-stack CLI shims (default).
  install  Converge the layout (repoint node-bin via
           symlink-nvm-node-bin.sh, create shims for present CLIs).

Options:
  -f, --force   Recreate shims even when they already resolve correctly.
  -q, --quiet   Suppress INFO/OK chatter; WARN/ERROR still shown.
  --dry-run     Print the plan without creating or changing anything.
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

LOCAL_BIN="$HOME/.local/bin"
NODE_BIN_LINK="$HOME/.local/node-bin"
SYMLINK_SCRIPT="$SCRIPT_DIR/symlink-nvm-node-bin.sh"
SHIM_TOOLS=(paseo openchamber opencode)
# Repo entry point: git-ignored by decision (.gitignore), converged here.
REPO_BIN_DIR="$(cd "$SCRIPT_DIR" && pwd -P)"
DEVSTACK_LINK="$REPO_BIN_DIR/dev-stack"
DEVSTACK_TARGET="../dev-stack/dev-stack.sh"

resolve() {
    # Canonicalize a path, resolving symlinks for files and
    # directories alike. cd/pwd alone only canonicalizes
    # directories: for a file symlink it fails and echoes the input
    # unchanged, so shim comparisons must go through readlink -f
    # (coreutils, present on all target systems) first.
    if command -v readlink >/dev/null 2>&1; then
        local out
        if out="$(readlink -f -- "$1" 2>/dev/null)" && [[ -n "$out" ]]; then
            printf '%s' "$out"
            return 0
        fi
    fi
    cd "$1" 2>/dev/null && pwd -P || printf '%s' "$1"
}

npm_prefix() { npm config get prefix 2>/dev/null || echo ""; }

do_status() {
    local drift=0
    if [[ -L "$DEVSTACK_LINK" && "$(readlink "$DEVSTACK_LINK")" == "$DEVSTACK_TARGET" ]]; then
        log_ok "tooling/bin/dev-stack entry point converged"
    else
        log_warn "tooling/bin/dev-stack entry point missing or wrong."
        drift=1
    fi
    if [[ -d "$LOCAL_BIN" ]]; then
        log_ok "$HOME/.local/bin present"
    else
        log_warn "$HOME/.local/bin missing."
        drift=1
    fi
    if [[ -L "$NODE_BIN_LINK" ]]; then
        local target
        target="$(resolve "$NODE_BIN_LINK")"
        if [[ -x "$target/node" ]]; then
            log_ok "$HOME/.local/node-bin -> $target (node present)"
        else
            log_warn "$HOME/.local/node-bin points at $target without node."
            drift=1
        fi
    else
        log_warn "$HOME/.local/node-bin missing (run install)."
        drift=1
    fi
    if command -v npm >/dev/null 2>&1; then
        local prefix
        prefix="$(npm_prefix)"
        if [[ -n "$prefix" && -d "$prefix" && -w "$prefix" ]]; then
            log_ok "npm prefix user-owned: $prefix"
        else
            log_warn "npm prefix '${prefix:-unknown}' is not a writable user-owned dir (blocker)."
            return 3
        fi
    else
        log_warn "npm not on PATH (blocker: install Node.js first)."
        return 3
    fi
    local t
    for t in "${SHIM_TOOLS[@]}"; do
        if [[ -L "$LOCAL_BIN/$t" ]]; then
            local got want
            got="$(resolve "$LOCAL_BIN/$t")"
            want="$(resolve "$NODE_BIN_LINK/$t" 2>/dev/null || echo '')"
            if [[ -n "$want" && "$got" == "$want" ]]; then
                log_ok "shim ~/.local/bin/$t -> $got"
            else
                log_warn "shim ~/.local/bin/$t points at $got (want $want)."
                drift=1
            fi
        elif [[ -e "$LOCAL_BIN/$t" ]]; then
            log_warn "$HOME/.local/bin/$t exists but is not the managed symlink."
            drift=1
        else
            # Missing shim for an uninstalled tool is not drift: the
            # package is dev-stack's state. Report it informationally.
            if [[ -x "$NODE_BIN_LINK/$t" ]]; then
                log_warn "shim ~/.local/bin/$t missing (tool installed, link pending)."
                drift=1
            else
                log_info "$t not installed; no shim expected."
            fi
        fi
    done
    [[ "$drift" -ne 0 ]] && return 1
    log_ok "Userspace shims converged."
    return 0
}

ensure_shim() {
    # $1=tool. Creates/refreshes ~/.local/bin/<tool> -> ../node-bin/<tool>.
    # The link target stays node-bin-relative so shims float across
    # Node upgrades when node-bin is repointed; correctness is judged
    # by the canonical (readlink -f) comparison in do_status.
    local tool="$1"
    local src="$NODE_BIN_LINK/$tool" dest="$LOCAL_BIN/$tool"
    [[ -x "$src" ]] || return 0
    local want
    want="$(resolve "$src")"
    if [[ -L "$dest" && "$(resolve "$dest")" == "$want" && "$FORCE" != true ]]; then
        log_info "shim $tool already correct; skipping."
        return 0
    fi
    if [[ -e "$dest" && ! -L "$dest" ]]; then
        log_err "$HOME/.local/bin/$tool exists and is not a symlink; refusing to replace. Move it aside manually."
        return 1
    fi
    if [[ "$DRY_RUN" == true ]]; then
        log_dry "ln -sfn $src $dest"
        return 0
    fi
    ln -sfn "$src" "$dest"
    log_ok "shim ~/.local/bin/$tool -> $src"
}

do_install() {
    if [[ "$DRY_RUN" == true ]]; then
        log_dry "mkdir -p $LOCAL_BIN"
        log_dry "bash $SYMLINK_SCRIPT (repoint $HOME/.local/node-bin at nvm default Node)"
        log_dry "ln -sfn <node-bin>/<tool> $LOCAL_BIN/<tool> for installed dev-stack CLIs"
        log_dry "ln -sfn $DEVSTACK_TARGET $DEVSTACK_LINK (repo entry point)"
        log_dry "verify npm prefix is user-owned"
        return 0
    fi
    mkdir -p "$LOCAL_BIN"
    if [[ ! -L "$DEVSTACK_LINK" || "$(readlink "$DEVSTACK_LINK")" != "$DEVSTACK_TARGET" ]]; then
        ln -sfn "$DEVSTACK_TARGET" "$DEVSTACK_LINK"
        log_ok "tooling/bin/dev-stack entry point converged"
    else
        log_info "tooling/bin/dev-stack entry point already correct; skipping."
    fi
    log_info "Repointing $HOME/.local/node-bin via symlink-nvm-node-bin.sh ..."
    if [[ "$QUIET" == true ]]; then
        bash "$SYMLINK_SCRIPT" >/dev/null || {
            log_err "symlink-nvm-node-bin.sh failed (no nvm default Node?)."
            log_err "Remediation: nvm install --lts && nvm alias default <version>, then re-run."
            return 3
        }
    elif ! bash "$SYMLINK_SCRIPT"; then
        log_err "symlink-nvm-node-bin.sh failed (no nvm default Node?)."
        log_err "Remediation: nvm install --lts && nvm alias default <version>, then re-run."
        return 3
    fi
    export PATH="$LOCAL_BIN:$NODE_BIN_LINK:$PATH"
    if command -v npm >/dev/null 2>&1; then
        local prefix
        prefix="$(npm_prefix)"
        if [[ -z "$prefix" || ! -d "$prefix" || ! -w "$prefix" ]]; then
            log_err "npm prefix '${prefix:-unknown}' is not a writable user-owned dir (blocker)."
            log_err "Remediation: point npm at a user-owned prefix (nvm Node owns its prefix by default)."
            return 3
        fi
        log_ok "npm prefix user-owned: $prefix"
    else
        log_err "npm not on PATH even after node-bin provisioning (blocker)."
        return 3
    fi
    local t rc=0
    for t in "${SHIM_TOOLS[@]}"; do
        ensure_shim "$t" || rc=1
    done
    [[ "$rc" -ne 0 ]] && return 1
    do_status
}

case "$COMMAND" in
    status) do_status ;;
    install) do_install ;;
esac

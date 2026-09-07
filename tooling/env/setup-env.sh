#!/usr/bin/env bash
#=======================================================================
# Script:    setup-env.sh
# Purpose:   Reconciler owning the heypogi env files. Generates
#            ~/.config/heypogi/.env-{common,override,secrets} and keeps
#            the marker-bounded source block in ~/.bashrc. Called first
#            by bootstrap/bootstrap.sh (env-first ordering, KTD7); this
#            script never sources require-env.sh (it creates the env).
# Usage:     setup-env.sh [status|install] [-f|--force] [-q|--quiet]
#                          [--dry-run] [-h|--help]
#
# Creates:
#   ~/.config/heypogi/.env-common   (generated from template, chmod 644)
#   ~/.config/heypogi/.env-override  (empty, chmod 640, user-maintained)
#   ~/.config/heypogi/.env-secrets   (from template, chmod 600)
#
# Target user: operates on $HOME. Bootstrap runs this as the target
#   user (sudo -u TARGET with HOME set), so all state lands in ~TARGET
#   with no root-owned leaves. Never run the whole script under sudo
#   for a different user without setting HOME.
# Exit codes: 0 converged, 1 drift/failed, 2 usage error, 3 blocked
#   (e.g. repo template missing).
#=======================================================================
set -euo pipefail

# --- Locate repo root from this script's position ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

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
setup-env.sh - own the heypogi environment files.

Usage:
  setup-env.sh [status] [-q|--quiet] [-h|--help]
  setup-env.sh install [-f|--force] [-q|--quiet] [--dry-run] [-h|--help]

Commands:
  status   Read-only check of env files, perms/ownership, and the
           .bashrc marker block (default).
  install  Render .env-common, create .env-override/.env-secrets when
           absent, and reconcile the .bashrc source block.

Options:
  -f, --force   Re-render .env-common even when unchanged (no-op state);
                never overwrites .env-override or .env-secrets content.
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

# --- Paths (HOME-relative: caller runs as the target user) ---
CONFIG_DIR="$HOME/.config/heypogi"
ENV_COMMON="$CONFIG_DIR/.env-common"
ENV_OVERRIDE="$CONFIG_DIR/.env-override"
ENV_SECRETS="$CONFIG_DIR/.env-secrets"
TEMPLATE_COMMON="$SCRIPT_DIR/env-common.template"
TEMPLATE_SECRETS="$SCRIPT_DIR/env-secrets.template"
BASHRC="$HOME/.bashrc"

# --- Marker block for .bashrc ---
MARKER_START="# >>> heypogi env >>>"
MARKER_END="# <<< heypogi <<<"

SOURCE_BLOCK="$MARKER_START
set -a
. \"\$HOME/.config/heypogi/.env-common\"
. \"\$HOME/.config/heypogi/.env-override\"
. \"\$HOME/.config/heypogi/.env-secrets\"
set +a
$MARKER_END"

render_common_to() {
    # $1 = destination path. Renders the template with absolute paths
    # (systemd EnvironmentFile= performs no $VAR expansion).
    local dest="$1"
    sed -e "s|__REPO_ROOT__|$REPO_ROOT|g" -e "s|\$HOME|$HOME|g" "$TEMPLATE_COMMON" > "$dest"
}

check_mode_owner() {
    # $1=path $2=want mode $3=label. Prints status, returns nonzero on drift.
    local path="$1" want="$2" label="$3"
    if [[ ! -f "$path" ]]; then
        log_warn "$label missing: $path"
        return 1
    fi
    local mode owner me
    mode="$(stat -c %a "$path" 2>/dev/null || echo '?')"
    owner="$(stat -c %U "$path" 2>/dev/null || echo '?')"
    me="$(id -un 2>/dev/null || echo '?')"
    if [[ "$mode" != "$want" ]]; then
        log_warn "$label mode $mode, want $want: $path"
        return 1
    fi
    if [[ "$owner" != "$me" ]]; then
        log_warn "$label owned by '$owner', want '$me': $path"
        return 1
    fi
    return 0
}

do_status() {
    local drift=0
    [[ -f "$TEMPLATE_COMMON" ]] || { log_err "Template missing: $TEMPLATE_COMMON"; return 3; }
    [[ -f "$TEMPLATE_SECRETS" ]] || { log_err "Template missing: $TEMPLATE_SECRETS"; return 3; }
    # .env-common content
    if [[ -f "$ENV_COMMON" ]]; then
        local tmp
        tmp="$(mktemp)"
        trap 'rm -f "$tmp"' RETURN
        render_common_to "$tmp"
        if cmp -s "$tmp" "$ENV_COMMON"; then
            log_ok ".env-common converged"
        else
            log_warn ".env-common content differs from rendered template."
            drift=1
        fi
        rm -f "$tmp"
        trap - RETURN
    else
        log_warn ".env-common missing."
        drift=1
    fi
    check_mode_owner "$ENV_COMMON" "644" ".env-common" || drift=1
    if [[ -f "$ENV_OVERRIDE" ]]; then
        log_ok ".env-override present"
    else
        log_warn ".env-override missing."
        drift=1
    fi
    check_mode_owner "$ENV_OVERRIDE" "640" ".env-override" || drift=1
    if [[ -f "$ENV_SECRETS" ]]; then
        log_ok ".env-secrets present"
    else
        log_warn ".env-secrets missing."
        drift=1
    fi
    check_mode_owner "$ENV_SECRETS" "600" ".env-secrets" || drift=1
    # .bashrc marker block: exactly one valid pair, content current.
    if [[ -f "$BASHRC" ]] && grep -qF "$MARKER_START" "$BASHRC" && grep -qF "$MARKER_END" "$BASHRC"; then
        local starts ends existing
        starts="$(grep -cF "$MARKER_START" "$BASHRC")"
        ends="$(grep -cF "$MARKER_END" "$BASHRC")"
        existing="$(sed -n "/$MARKER_START/,/$MARKER_END/p" "$BASHRC")"
        if [[ "$starts" == "1" && "$ends" == "1" && "$existing" == "$SOURCE_BLOCK" ]]; then
            log_ok ".bashrc source block converged"
        else
            log_warn ".bashrc marker block differs (starts=$starts ends=$ends)."
            drift=1
        fi
    else
        log_warn ".bashrc source block missing."
        drift=1
    fi
    [[ "$drift" -ne 0 ]] && return 1
    log_ok "Environment converged."
    return 0
}

do_install() {
    [[ -f "$TEMPLATE_COMMON" ]] || { log_err "Template missing: $TEMPLATE_COMMON"; return 3; }
    [[ -f "$TEMPLATE_SECRETS" ]] || { log_err "Template missing: $TEMPLATE_SECRETS"; return 3; }

    if [[ "$DRY_RUN" == true ]]; then
        log_dry "mkdir -p $CONFIG_DIR"
        log_dry "render template -> $ENV_COMMON (compare-before-write, atomic mv, chmod 644)"
        log_dry "touch $ENV_OVERRIDE (chmod 640) if absent; never overwrite"
        log_dry "cp template -> $ENV_SECRETS (chmod 600) if absent; never overwrite"
        log_dry "reconcile marker-bounded source block in $BASHRC"
        return 0
    fi

    log_info "Setting up heypogi environment..."
    log_info "  Repo root: $REPO_ROOT"
    log_info "  Config dir: $CONFIG_DIR"

    # --- Create config directory (managed scope) ---
    mkdir -p "$CONFIG_DIR"

    # --- Render .env-common from template (generated + script-owned) ---
    log_info "Rendering .env-common from template..."
    local tmp_common
    tmp_common="$(mktemp "$CONFIG_DIR/.env-common.tmp.XXXXXX")"
    trap 'rm -f "$tmp_common"' EXIT
    render_common_to "$tmp_common"

    if [[ -f "$ENV_COMMON" ]] && [[ "$FORCE" != true ]]; then
        if cmp -s "$tmp_common" "$ENV_COMMON"; then
            rm -f "$tmp_common"
            log_ok ".env-common: unchanged, skipping"
        else
            mv "$tmp_common" "$ENV_COMMON"
            log_ok ".env-common: updated"
        fi
    else
        mv "$tmp_common" "$ENV_COMMON"
        if [[ "$FORCE" == true ]]; then
            log_ok ".env-common: re-rendered (--force)"
        else
            log_ok ".env-common: created"
        fi
    fi
    trap - EXIT
    chmod 644 "$ENV_COMMON"

    # --- Create .env-override if missing (user-maintained: never overwrite) ---
    if [[ ! -f "$ENV_OVERRIDE" ]]; then
        touch "$ENV_OVERRIDE"
        log_ok ".env-override: created (empty)"
    else
        log_info ".env-override: exists, skipping"
    fi
    chmod 640 "$ENV_OVERRIDE"

    # --- Create .env-secrets from template if missing (secret-bearing) ---
    if [[ ! -f "$ENV_SECRETS" ]]; then
        cp "$TEMPLATE_SECRETS" "$ENV_SECRETS"
        log_ok ".env-secrets: created from template"
    else
        log_info ".env-secrets: exists, skipping"
    fi
    chmod 600 "$ENV_SECRETS"

    # --- Idempotent .bashrc update (marker-bounded reconcile) ---
    log_info "Updating .bashrc..."
    if [[ ! -f "$BASHRC" ]]; then
        printf '%s\n' "$SOURCE_BLOCK" > "$BASHRC"
        log_ok ".bashrc: created with source block"
    elif grep -qF "$MARKER_START" "$BASHRC" && grep -qF "$MARKER_END" "$BASHRC"; then
        local starts ends existing saved tmp_bashrc
        starts="$(grep -cF "$MARKER_START" "$BASHRC")"
        ends="$(grep -cF "$MARKER_END" "$BASHRC")"
        if [[ "$starts" != "1" || "$ends" != "1" ]]; then
            log_err ".bashrc has $starts start / $ends end markers; refusing to guess. Fix manually, then re-run."
            return 1
        fi
        existing="$(sed -n "/$MARKER_START/,/$MARKER_END/p" "$BASHRC")"
        if [[ "$existing" == "$SOURCE_BLOCK" ]]; then
            log_info ".bashrc: source block unchanged, skipping"
        else
            saved="$(stat -c %a "$BASHRC")"
            tmp_bashrc="$(mktemp "$HOME/.bashrc.tmp.XXXXXX")"
            awk -v start="$MARKER_START" -v end="$MARKER_END" -v block="$SOURCE_BLOCK" '
                $0 == start { print block; skip=1; next }
                skip && $0 == end { skip=0; next }
                !skip { print }
            ' "$BASHRC" > "$tmp_bashrc"
            mv "$tmp_bashrc" "$BASHRC"
            chmod "$saved" "$BASHRC"
            log_ok ".bashrc: source block updated"
        fi
    else
        local saved2
        saved2="$(stat -c %a "$BASHRC")"
        printf '\n%s\n' "$SOURCE_BLOCK" >> "$BASHRC"
        chmod "$saved2" "$BASHRC"
        log_ok ".bashrc: source block appended"
    fi

    log_ok "Done. Environment files:"
    log_info "  $ENV_COMMON (644)"
    log_info "  $ENV_OVERRIDE (640)"
    log_info "  $ENV_SECRETS (600)"
    log_info "Reload your shell or run: source ~/.bashrc"
}

case "$COMMAND" in
    status) do_status ;;
    install) do_install ;;
esac

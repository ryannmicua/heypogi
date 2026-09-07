#!/usr/bin/env bash
#=======================================================================
# Guard:     require-env.sh
# Purpose:   Sourced guard that fails fast when the heypogi base env
#            is missing. Sources .env-common/override/secrets when vars
#            are unset (covers systemd/cron non-login shells), then
#            verifies HEYPOGI_ROOT / OPENCODE_CONFIG_DIR and that
#            tooling/bin is on PATH.
#
# Usage (at top of a dependent, after arg parsing, before mutation):
#   source "$SCRIPT_DIR/../env/require-env.sh" || exit $?
#
# Contract: read-only, no prompts, honors -q (errors still shown).
#   Under --dry-run (DRY_RUN=true or --dry-run in the parent argv)
#   children run in plan-only mode: the guard validates declared
#   intent and never exits nonzero for missing live files (KTD7).
#   Env files are grammar-checked (KEY=value, no `export`, no command
#   substitution, no backticks) and ownership/permission-checked
#   (owned by the effective user; common 644, override 640, secrets
#   600) before sourcing; malformed or mis-owned files are exit 3
#   and are never sourced (R30).
# Exit codes: 0 env satisfied (or dry-run plan mode), 3 env missing /
#   malformed / mis-owned with remediation. Never exits 2 (not a CLI).
#=======================================================================

# Must be sourced, never executed.
if [[ "${BASH_SOURCE[0]:-}" == "${0}" ]]; then
    printf 'ERROR: require-env.sh must be sourced, not executed.\n' >&2
    printf 'ERROR: Remediation: source it from a dependent script instead.\n' >&2
    exit 2
fi

# Guard against double-sourcing in one shell.
if [[ "${HEYPOGI_REQUIRE_ENV_LOADED:-}" == "1" ]]; then
    return 0
fi

_require_env_quiet="${QUIET:-false}"
# KTD7 plan-only mode: callers set DRY_RUN=true during arg parsing
# before sourcing this guard, so live files are never required.
_require_env_dry="false"
if [[ "${DRY_RUN:-false}" == "true" ]]; then
    _require_env_dry="true"
fi

_require_env_info() {
    [[ "$_require_env_quiet" == "true" ]] && return 0
    printf 'INFO: %s\n' "$*"
}
_require_env_err() { printf 'ERROR: %s\n' "$*" >&2; }

_require_env_fail() {
    _require_env_err "$1"
    _require_env_err "Remediation: run tooling/env/setup-env.sh install (or bootstrap/bootstrap.sh --force) as the target user."
    unset _require_env_quiet _require_env_dry
    return 3
}

_require_env_ok() {
    unset _require_env_quiet _require_env_dry
    HEYPOGI_REQUIRE_ENV_LOADED=1
    return 0
}

# --- Dry-run plan mode (KTD7): no live files required ---
if [[ "$_require_env_dry" == "true" ]]; then
    _require_env_info "require-env: dry-run plan mode; skipping live env reads."
    _require_env_ok && return 0
fi

_require_env_config_dir="$HOME/.config/heypogi"
_require_env_common="$_require_env_config_dir/.env-common"
_require_env_override="$_require_env_config_dir/.env-override"
_require_env_secrets="$_require_env_config_dir/.env-secrets"
_require_env_me="$(id -un 2>/dev/null || echo '')"

_require_env_check_file() {
    # $1=path $2=expected mode $3=label. Missing common/secrets is a
    # fail; missing override is tolerated (setup-env creates it, but an
    # operator may legitimately not have one yet -> treat as empty).
    local path="$1" want_mode="$2" label="$3"
    if [[ ! -e "$path" ]]; then
        if [[ "$label" == "override" ]]; then
            return 0
        fi
        _require_env_fail "require-env: $HOME/.config/heypogi/.env-${label} is missing."
        return 3
    fi
    if [[ ! -f "$path" ]]; then
        _require_env_fail "require-env: .env-${label} is not a regular file: $path."
        return 3
    fi
    local owner mode
    owner="$(stat -c %U "$path" 2>/dev/null || echo '')"
    mode="$(stat -c %a "$path" 2>/dev/null || echo '')"
    if [[ -n "$_require_env_me" && -n "$owner" && "$owner" != "$_require_env_me" ]]; then
        _require_env_fail "require-env: .env-${label} owned by '$owner', expected '${_require_env_me}'. Refusing to source."
        return 3
    fi
    if [[ "$mode" != "$want_mode" ]]; then
        _require_env_fail "require-env: .env-${label} mode $mode, expected $want_mode. Fix: chmod $want_mode $path (and chown to the target user)."
        return 3
    fi
    # Grammar allowlist: KEY=value only. No `export`, no command
    # substitution, no backticks, no leading whitespace tricks.
    local lineno=0 line
    while IFS= read -r line || [[ -n "$line" ]]; do
        lineno=$((lineno + 1))
        [[ "$line" =~ ^[[:space:]]*(#|$) ]] && continue
        if [[ "$line" =~ ^[[:space:]]*export([[:space:]]|$) ]]; then
            _require_env_fail "require-env: .env-${label}:$lineno uses 'export' (forbidden)."
            return 3
        fi
        if [[ "$line" == *'`'* || "$line" == *'$('* ]]; then
            _require_env_fail "require-env: .env-${label}:$lineno uses command substitution (forbidden)."
            return 3
        fi
        if [[ ! "$line" =~ ^[A-Za-z_][A-Za-z0-9_]*= ]]; then
            _require_env_fail "require-env: .env-${label}:$lineno is not KEY=value."
            return 3
        fi
    done <"$path"
    return 0
}

if ! _require_env_check_file "$_require_env_common" "644" "common"; then
    return 3
fi
if ! _require_env_check_file "$_require_env_override" "640" "override"; then
    return 3
fi
if ! _require_env_check_file "$_require_env_secrets" "600" "secrets"; then
    return 3
fi

# Source validated files so non-login shells (systemd, cron) self-heal.
if [[ -z "${HEYPOGI_ROOT:-}" || -z "${OPENCODE_CONFIG_DIR:-}" ]]; then
    set -a
    # shellcheck disable=SC1090
    . "$_require_env_common"
    if [[ -f "$_require_env_override" ]]; then
        # shellcheck disable=SC1090
        . "$_require_env_override"
    fi
    # shellcheck disable=SC1090
    . "$_require_env_secrets"
    set +a
fi

if [[ -z "${HEYPOGI_ROOT:-}" ]]; then
    _require_env_fail "require-env: HEYPOGI_ROOT is unset after sourcing env files."
    return 3
fi
if [[ -z "${OPENCODE_CONFIG_DIR:-}" ]]; then
    _require_env_fail "require-env: OPENCODE_CONFIG_DIR is unset after sourcing env files."
    return 3
fi
case ":$PATH:" in
    *":$HEYPOGI_ROOT/tooling/bin:"*) ;;
    *)
        _require_env_fail "require-env: $HEYPOGI_ROOT/tooling/bin is not on PATH."
        return 3
        ;;
esac

unset _require_env_config_dir _require_env_common _require_env_override
unset _require_env_secrets _require_env_me
_require_env_ok && return 0

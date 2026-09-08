#!/usr/bin/env bash
#=======================================================================
# Script:    dev-stack.sh
# Purpose:   Linux equivalent of dev-stack.ps1 — manages OpenCode,
#            OpenChamber, and Paseo services on Linux VMs.
# Usage:     ./dev-stack.sh [command] [options]
#
# Commands:
#   status       Check everything and report issues (default)
#   install      Install or update all tools to latest
#   update       Alias for install
#   fix          Auto-fix runtime issues (start services, fix config)
#   start        Start services
#   stop         Stop services
#   restart      Restart services
#   startup      Manage autostart (systemd user unit):
#                startup install|fix|enable|disable|uninstall
#   uninstall    Remove tools
#   help         Show this help
#
# Options:
#   -a, --app APP     Target app: opencode, openchamber, paseo, all (default)
#   -f, --force       Skip confirmation prompts (declared targets only)
#   -q, --quiet       Suppress non-essential output (never implies consent)
#   --dry-run         Plan only: no writes, no service/network/package
#                     changes; forwarded to children
#   -h, --help        Show this help
#
# Prereqs:
#   - Node.js 18+
#   - npm
#   - curl
#
# Author:    Ops Team
# Created:   2026-08-21
#=======================================================================
set -euo pipefail

# Userspace-first PATH: this script manages a rootless stack, so make sure
# the user-owned shims resolve even when the caller has a minimal PATH
# (cron, scripts, non-interactive shells). System copies in /usr/bin are
# only ever a fallback and must never shadow ~/.local/bin.
for _dir in "$HOME/.local/bin" "$HOME/.local/node-bin" "$HOME/.opencode/bin"; do
    case ":$PATH:" in
        *":$_dir:"*) ;;
        *) export PATH="$_dir:$PATH" ;;
    esac
done
unset _dir

# --- Constants ---
OPENCHAMBER_PORT=7777
PASEO_PORT=6767
PKG_OPENCODE="opencode-ai"
PKG_OPENCHAMBER="@openchamber/web"
PKG_PASEO="@getpaseo/cli"

# --- Colors (stdout decoration only: empty unless stdout is a TTY and
# NO_COLOR is unset; stderr helpers below gate on fd 2 themselves) ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'
if [[ -n "${NO_COLOR:-}" ]] || [[ ! -t 1 ]]; then
    RED=''; GREEN=''; YELLOW=''; BLUE=''; NC=''
fi

# --- State ---
CHECKS=()

# --- Helpers (printf only; INFO/OK -> stdout unless quiet; WARN/ERROR -> stderr always) ---
echo_info() {
    [[ "${QUIET:-false}" == true ]] && return 0
    if [[ -z "${NO_COLOR:-}" && -t 1 ]]; then printf '\033[0;34mINFO:\033[0m %s\n' "$*"
    else printf 'INFO: %s\n' "$*"; fi
}
echo_success() {
    [[ "${QUIET:-false}" == true ]] && return 0
    if [[ -z "${NO_COLOR:-}" && -t 1 ]]; then printf '\033[0;32mOK:\033[0m %s\n' "$*"
    else printf 'OK: %s\n' "$*"; fi
}
echo_warn() {
    if [[ -z "${NO_COLOR:-}" && -t 2 ]]; then printf '\033[1;33mWARN:\033[0m %s\n' "$*" >&2
    else printf 'WARN: %s\n' "$*" >&2; fi
}
echo_err() {
    if [[ -z "${NO_COLOR:-}" && -t 2 ]]; then printf '\033[0;31mERROR:\033[0m %s\n' "$*" >&2
    else printf 'ERROR: %s\n' "$*" >&2; fi
}
dry_echo() { printf 'DRY-RUN: %s\n' "$*"; }

get_version() {
    local cmd="$1"
    if command -v "$cmd" &>/dev/null; then
        "$cmd" --version 2>/dev/null | head -1 | tr -d '[:space:]' || echo ""
    else
        printf '\n'
    fi
}

get_command_source() {
    local cmd="$1"
    if command -v "$cmd" &>/dev/null; then
        command -v "$cmd"
    else
        printf '\n'
    fi
}

check_port() {
    local port="$1"
    ss -tlnp 2>/dev/null | grep -q ":$port " && return 0 || return 1
}

get_listening_pid() {
    local port="$1"
    ss -tlnp 2>/dev/null | grep ":$port " | grep -oP 'pid=\K[0-9]+' | head -1 || echo ""
}

get_process_cmdline() {
    local pid="$1"
    if [[ -n "$pid" ]] && [[ -f "/proc/$pid/cmdline" ]]; then
        tr '\0' ' ' < "/proc/$pid/cmdline" 2>/dev/null || echo ""
    else
        printf '\n'
    fi
}

test_health() {
    local url="$1"
    local response
    if response=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 5 "$url" 2>/dev/null); then
        [[ "$response" == "200" ]]
    else
        return 1
    fi
}

get_latest_version() {
    local package="$1"
    if command -v timeout >/dev/null 2>&1; then
        timeout 30 npm view "$package" version 2>/dev/null | tail -1 || echo ""
    else
        npm view "$package" version 2>/dev/null | tail -1 || echo ""
    fi
}

get_dist_tag_version() {
    local package="$1"
    local tag="$2"
    if command -v timeout >/dev/null 2>&1; then
        timeout 30 npm view "$package" "dist-tags.$tag" 2>/dev/null | tail -1 || echo ""
    else
        npm view "$package" "dist-tags.$tag" 2>/dev/null | tail -1 || echo ""
    fi
}

# Finite registry-reachability probe. Offline registry lookups are
# exit-3 blockers per R31, never silently treated as "up to date".
registry_reachable() {
    command -v npm >/dev/null 2>&1 || return 1
    if command -v timeout >/dev/null 2>&1; then
        timeout 25 npm ping >/dev/null 2>&1
    else
        npm ping >/dev/null 2>&1
    fi
}

# Semver comparison - returns 0 if $1 >= $2
version_gte() {
    local v1="$1" v2="$2"
    [[ -z "$v1" || -z "$v2" ]] && return 1
    # sort -V -C checks that its input is already sorted ascending, so to
    # test "v1 >= v2" we must feed it v2 then v1 (true iff v2 <= v1). The
    # original `printf v1 v2` tested the opposite (v1 <= v2), silently
    # inverting every up-to-date check in this script: it reported "up to
    # date" for anything NOT already newer than the registry - i.e. always,
    # except the impossible case of a locally installed version somehow
    # exceeding the registry's latest. Missing installs were unaffected
    # (caught separately by the "not installed" check before this ever ran).
    [[ "$v1" == "$v2" ]] && return 0
    printf '%s\n%s' "$v2" "$v1" | sort -V -C
}

# Ensure the systemd user bus is reachable (non-login shells often lack
# XDG_RUNTIME_DIR even though user@UID.service is up).
ensure_user_bus() {
    if [[ -z "${XDG_RUNTIME_DIR:-}" && -S "/run/user/$(id -u)/bus" ]]; then
        XDG_RUNTIME_DIR="/run/user/$(id -u)"
        export XDG_RUNTIME_DIR
    fi
}

# npm install -g wrapper: the global prefix must be user-owned (nvm version
# dir via ~/.local/node-bin - see tooling/bin/symlink-nvm-node-bin.sh). This
# function never escalates to sudo; on failure it explains how to fix the
# userspace layout instead.
npm_install_global() {
    local pkg="$1"
    if [[ "$DRY_RUN" == true ]]; then
        dry_echo "npm install -g $pkg (as target user, no sudo)"
        return 0
    fi
    local output exit_code
    local npm_prefix
    npm_prefix=$(npm config get prefix 2>/dev/null || echo "")

    output=$(npm install -g "$pkg" 2>&1) && { printf '%s\n' "$output"; return 0; }
    exit_code=$?

    printf '%s\n' "$output"
    if [[ -n "$npm_prefix" && ! -w "$npm_prefix" ]]; then
        echo_err "Global npm prefix '$npm_prefix' is not writable and this script will not use sudo."
        echo_err "Fix the userspace layout, then retry:"
        echo_err "  ./tooling/bin/symlink-nvm-node-bin.sh   # re-point ~/.local/node-bin at the nvm default node"
        echo_err "  npm config get prefix               # must resolve to a user-owned dir (nvm version dir)"
    fi
    return $exit_code
}

add_check() {
    local service="$1" check="$2" ok="$3" detail="${4:-}"
    local status="ok"
    [[ "$ok" == "false" ]] && status="FAIL"
    CHECKS+=("${service}|${check}|${status}|${detail}")
}

add_warn() {
    local service="$1" check="$2" detail="${3:-}"
    CHECKS+=("${service}|${check}|WARN|${detail}")
}

write_status_report() {
    local current_service=""
    local issues=0
    
    for entry in "${CHECKS[@]}"; do
        IFS='|' read -r service check status detail <<< "$entry"
        
        if [[ "$service" != "$current_service" ]]; then
            [[ -n "$current_service" ]] && echo ""
            printf '%s%s%s\n' "${BLUE}" "$service" "${NC}"
            current_service="$service"
        fi
        
        local color="$GREEN"
        local mark="ok  "
        
        case "$status" in
            FAIL) color="$RED"; mark="FAIL"; issues=$((issues+1)) ;;
            WARN) color="$YELLOW"; mark="WARN" ;;
        esac
        
        printf '%s' "${color}"
        printf "  %-28s: %s" "$check" "$mark"
        [[ -n "$detail" ]] && printf " - %s" "$detail"
        printf '%s\n' "${NC}"
    done
    
    printf '\n'
    if [[ "$REGISTRY_OK" != true ]]; then
        echo_warn "npm registry unreachable: version checks indeterminate (exit 3)."
        return 3
    fi
    if [[ $issues -eq 0 ]]; then
        echo_success "All checks passed."
        return 0
    else
        echo_warn "$issues issue(s) found. Run: dev-stack.sh fix"
        return 1
    fi
}

# --- Status Collection ---
collect_status() {
    CHECKS=()
    REGISTRY_OK=true

    # R31: distinguish drift (1) from indeterminate-offline (3). One
    # finite probe; version checks below are skipped when it fails.
    if command -v npm >/dev/null 2>&1; then
        if ! registry_reachable; then
            REGISTRY_OK=false
            add_warn "Toolchain" "npm registry reachable" "offline or unreachable; version checks indeterminate"
        fi
    fi
    
    # Fetch latest versions (with timeout)
    local latest_oc latest_ocweb latest_paseo_latest latest_paseo_beta latest_paseo
    latest_oc=$(get_latest_version "$PKG_OPENCODE" 2>/dev/null || echo "")
    latest_ocweb=$(get_latest_version "$PKG_OPENCHAMBER" 2>/dev/null || echo "")
    latest_paseo_latest=$(get_latest_version "$PKG_PASEO" 2>/dev/null || echo "")
    latest_paseo_beta=$(get_dist_tag_version "$PKG_PASEO" "beta" 2>/dev/null || echo "")
    
    # Prefer beta if newer
    if [[ -n "$latest_paseo_beta" ]] && version_gte "$latest_paseo_beta" "$latest_paseo_latest"; then
        latest_paseo="$latest_paseo_beta"
    else
        latest_paseo="$latest_paseo_latest"
    fi
    
    # --- OpenCode ---
    local oc_path oc_ver
    oc_path=$(get_command_source "opencode")
    add_check "OpenCode" "CLI present" "$([[ -n "$oc_path" ]] && echo true || echo false)" "$oc_path"
    
    oc_ver=$(get_version "opencode")
    add_check "OpenCode" "Version" "$([[ -n "$oc_ver" ]] && echo true || echo false)" "$oc_ver"
    
    if [[ -n "$oc_ver" && -n "$latest_oc" ]]; then
        if ! version_gte "$oc_ver" "$latest_oc"; then
            add_check "OpenCode" "Up to date" "false" "installed $oc_ver, latest $latest_oc"
        else
            add_check "OpenCode" "Up to date" "true" "latest $latest_oc"
        fi
    fi
    
    # --- OpenChamber ---
    local ocweb_path ocweb_ver ocweb_pid
    ocweb_path=$(get_command_source "openchamber")
    add_check "OpenChamber" "CLI present" "$([[ -n "$ocweb_path" ]] && echo true || echo false)" "$ocweb_path"
    
    ocweb_ver=$(get_version "openchamber")
    add_check "OpenChamber" "Version" "$([[ -n "$ocweb_ver" ]] && echo true || echo false)" "$ocweb_ver"
    
    if [[ -n "$ocweb_ver" && -n "$latest_ocweb" ]]; then
        if ! version_gte "$ocweb_ver" "$latest_ocweb"; then
            add_check "OpenChamber" "Up to date" "false" "installed $ocweb_ver, latest $latest_ocweb"
        else
            add_check "OpenChamber" "Up to date" "true" "latest $latest_ocweb"
        fi
    fi
    
    ocweb_pid=$(get_listening_pid "$OPENCHAMBER_PORT")
    add_check "OpenChamber" "Running" "$([[ -n "$ocweb_pid" ]] && echo true || echo false)" \
        "$(if [[ -n "$ocweb_pid" ]]; then echo "pid $ocweb_pid on port $OPENCHAMBER_PORT"; else echo "not listening on $OPENCHAMBER_PORT"; fi)"
    
    if [[ -n "$ocweb_pid" ]]; then
        local ocweb_cmdline
        ocweb_cmdline=$(get_process_cmdline "$ocweb_pid")
        if [[ "$ocweb_cmdline" == *"openchamber"* ]]; then
            add_check "OpenChamber" "Server (not desktop)" "true" "openchamber serve"
        else
            add_check "OpenChamber" "Server (not desktop)" "false" "process is not openchamber"
        fi
        add_check "OpenChamber" "Health" "$(test_health "http://localhost:$OPENCHAMBER_PORT/health" && echo true || echo false)" \
            "http://localhost:$OPENCHAMBER_PORT/health"
    fi
    
    # --- Paseo ---
    local paseo_path paseo_ver paseo_pid
    paseo_path=$(get_command_source "paseo")
    add_check "Paseo" "CLI present" "$([[ -n "$paseo_path" ]] && echo true || echo false)" "$paseo_path"
    
    paseo_ver=$(get_version "paseo")
    add_check "Paseo" "Version" "$([[ -n "$paseo_ver" ]] && echo true || echo false)" "$paseo_ver"
    
    if [[ -n "$paseo_ver" && -n "$latest_paseo" ]]; then
        if ! version_gte "$paseo_ver" "$latest_paseo"; then
            add_check "Paseo" "Up to date" "false" "installed $paseo_ver, latest $latest_paseo (latest: $latest_paseo_latest, beta: $latest_paseo_beta)"
        else
            add_check "Paseo" "Up to date" "true" "latest $latest_paseo (latest: $latest_paseo_latest, beta: $latest_paseo_beta)"
        fi
    fi
    
    paseo_pid=$(get_listening_pid "$PASEO_PORT")
    add_check "Paseo" "Daemon running" "$([[ -n "$paseo_pid" ]] && echo true || echo false)" \
        "$(if [[ -n "$paseo_pid" ]]; then echo "pid $paseo_pid on port $PASEO_PORT"; else echo "not listening on $PASEO_PORT"; fi)"
    
    if [[ -n "$paseo_pid" ]]; then
        local paseo_cmdline paseo_cmdline_lc
        paseo_cmdline=$(get_process_cmdline "$paseo_pid")
        # Case-insensitive: current Paseo versions set their own process
        # title (e.g. "Paseo Daemon") via process.title, which no longer
        # contains the literal "daemon-worker" or lowercase "paseo".
        paseo_cmdline_lc="${paseo_cmdline,,}"
        if [[ "$paseo_cmdline_lc" == *"daemon-worker"* || "$paseo_cmdline_lc" == *"paseo"* ]]; then
            add_check "Paseo" "Daemon (not desktop)" "true" "$paseo_cmdline"
        else
            add_check "Paseo" "Daemon (not desktop)" "false" "unrecognized process: $paseo_cmdline"
        fi
        add_check "Paseo" "Health" "$(test_health "http://localhost:$PASEO_PORT/api/health" && echo true || echo false)" \
            "http://localhost:$PASEO_PORT/api/health"

        # --web-ui is a runtime flag on current Paseo, not a persisted config
        # key (older versions had features.webUi.enabled in config.json;
        # that key no longer exists on 0.4.0+). The socket-listening process
        # itself renames its own cmdline (e.g. to "Paseo Daemon" via
        # process.title), losing the flag, so scan all processes for the
        # launcher that still has it rather than trusting one specific pid.
        if ps -eo args= 2>/dev/null | grep -q -- '--web-ui'; then
            add_check "Paseo" "Web UI enabled" "true" "daemon launched with --web-ui"
        else
            add_check "Paseo" "Web UI enabled" "false" "no paseo process found with --web-ui"
        fi
    fi
    
    # Paseo systemd USER service (userspace - never the system unit)
    if [[ -f "/etc/systemd/system/paseo.service" ]]; then
        add_warn "Paseo" "Legacy system unit" "/etc/systemd/system/paseo.service exists; run 'startup install -a paseo' to migrate"
    fi
    if command -v systemctl &>/dev/null; then
        ensure_user_bus
        local svc_status
        svc_status=$(systemctl --user is-active paseo.service 2>/dev/null || echo "inactive")
        if [[ "$svc_status" == "active" ]]; then
            add_check "Paseo" "Systemd service" "true" "paseo.service active (user)"
        else
            # Check if it's registered at all
            if systemctl --user list-unit-files paseo.service &>/dev/null; then
                add_check "Paseo" "Systemd service" "false" "paseo.service $svc_status (user)"
            else
                add_warn "Paseo" "Systemd service" "paseo.service not registered (user)"
            fi
        fi
    fi
    
    # Paseo config checks
    local paseo_cfg="$HOME/.paseo/config.json"
    if [[ -f "$paseo_cfg" ]]; then
        local listen_ok
        listen_ok=$(grep -q '"listen".*"0\.0\.0\.0:'"$PASEO_PORT" "$paseo_cfg" 2>/dev/null && echo true || echo false)
        add_check "Paseo" "Config listen 0.0.0.0" "$listen_ok" "$(if [[ "$listen_ok" == "true" ]]; then echo "daemon.listen = 0.0.0.0:$PASEO_PORT"; else echo "daemon.listen is not 0.0.0.0:$PASEO_PORT"; fi)"

        # (Web UI enabled is checked above from the running process, not
        # here - current Paseo has no persisted features.webUi config key.)

        # Check password is set (non-empty)
        if python3 -c "import json; c=json.load(open('$paseo_cfg')); assert c.get('daemon',{}).get('auth',{}).get('password','')" 2>/dev/null; then
            add_check "Paseo" "Password set" "true" "daemon.auth.password in config"
        else
            add_check "Paseo" "Password set" "false" "no auth password - run 'paseo daemon set-password'"
        fi
    else
        add_check "Paseo" "Config exists" "false" "$paseo_cfg not found"
    fi

    # Secrets allowlist (R28): the user unit loads .env-common +
    # .env-override + .env-paseo, never the whole .env-secrets file.
    local allowlist="$HOME/.config/heypogi/.env-paseo"
    local secrets_pw allowlist_pw
    secrets_pw="$(grep -E '^PASEO_PASSWORD=' "$HOME/.config/heypogi/.env-secrets" 2>/dev/null | tail -1 | cut -d= -f2- || echo '')"
    allowlist_pw="$(grep -E '^PASEO_PASSWORD=' "$allowlist" 2>/dev/null | tail -1 | cut -d= -f2- || echo '')"
    if [[ -n "$secrets_pw" ]]; then
        if [[ "$allowlist_pw" == "$secrets_pw" ]]; then
            add_check "Paseo" "Secrets allowlist" "true" ".env-paseo matches .env-secrets (password never logged)"
        else
            add_check "Paseo" "Secrets allowlist" "false" ".env-paseo stale or missing; run 'install -a paseo'"
        fi
    else
        if [[ -f "$allowlist" ]]; then
            add_check "Paseo" "Secrets allowlist" "true" "no PASEO_PASSWORD set; allowlist file present"
        else
            add_warn "Paseo" "Secrets allowlist" ".env-paseo not generated yet; run 'install -a paseo'"
        fi
    fi
    local user_unit="$HOME/.config/systemd/user/paseo.service"
    if [[ -f "$user_unit" ]]; then
        if grep -qF "EnvironmentFile=-%h/.config/heypogi/.env-secrets" "$user_unit" 2>/dev/null; then
            add_check "Paseo" "Unit loads allowlist only" "false" "unit still loads whole .env-secrets; run 'startup fix -a paseo'"
        elif grep -qF "EnvironmentFile=-%h/.config/heypogi/.env-paseo" "$user_unit" 2>/dev/null; then
            add_check "Paseo" "Unit loads allowlist only" "true" "no whole-secrets line in user unit"
        else
            add_check "Paseo" "Unit loads allowlist only" "false" "allowlist line missing; run 'startup fix -a paseo'"
        fi
    fi
}

# --- Paseo config seed + secrets allowlist + fail-closed (R7/R28/R29) ---
PASEO_HOME_DIR="$HOME/.paseo"
PASEO_LIVE_CONFIG="$PASEO_HOME_DIR/config.json"
PASEO_ENV_FILE="$HOME/.config/heypogi/.env-paseo"
PASEO_SECRETS_FILE="$HOME/.config/heypogi/.env-secrets"
LEGACY_SYSTEM_UNIT="/etc/systemd/system/paseo.service"

paseo_template_config() { printf '%s' "$SCRIPT_DIR/../../dotfiles/paseo/config.json"; }

seed_paseo_config() {
    # Additive, versioned seed/reconcile of the Paseo config (R29):
    # supports the tracked template and live 0.4.0+ (daemon.listen, no
    # features.webUi key). Preserves daemon.auth.password, provider
    # keys, runtime fields, and user overrides; patches only the
    # listen address. Never overwrites a password-bearing config.
    local template
    template="$(paseo_template_config)"
    if [[ ! -f "$template" ]]; then
        echo_warn "Paseo template not found at $template; skipping seed."
        return 0
    fi
    if [[ "$DRY_RUN" == true ]]; then
        dry_echo "seed/reconcile $PASEO_LIVE_CONFIG from template (additive, password-preserving)"
        return 0
    fi
    if ! command -v python3 >/dev/null 2>&1; then
        echo_err "python3 is required for the Paseo config merge and is missing."
        echo_err "Remediation: install python3, then re-run."
        return 3
    fi
    mkdir -p "$PASEO_HOME_DIR"
    if [[ ! -f "$PASEO_LIVE_CONFIG" ]]; then
        echo_info "Seeding Paseo config from template (no auth.password key: set it with 'paseo daemon set-password')..."
        cp "$template" "$PASEO_LIVE_CONFIG"
        chmod 600 "$PASEO_LIVE_CONFIG"
        echo_warn "Paseo auth password not set. Run 'paseo daemon set-password' after provisioning."
        ensure_paseo_env_allowlist || return $?
        return 0
    fi
    local tmp
    tmp="$(mktemp)"
    trap 'rm -f "$tmp"' EXIT
    if ! python3 - "$template" "$PASEO_LIVE_CONFIG" "$tmp" <<'PYEOF'; then
import json, sys
template_path, live_path, out_path = sys.argv[1], sys.argv[2], sys.argv[3]
with open(template_path) as f:
    template = json.load(f)
with open(live_path) as f:
    live = json.load(f)

def deep_additive(t, l):
    # Add keys from the template that are absent in live; never
    # overwrite existing live scalars. Dicts recurse; lists/scalars
    # stay exactly as the operator left them.
    for k, v in t.items():
        if k not in l:
            l[k] = v
        elif isinstance(v, dict) and isinstance(l[k], dict):
            deep_additive(v, l[k])
    return l

merged = deep_additive(template, live)
# Converge only the listen address to the intended state; everything
# else (password, providers, runtime, overrides) is preserved.
want_listen = template.get("daemon", {}).get("listen")
if want_listen:
    merged.setdefault("daemon", {})["listen"] = want_listen
with open(out_path, "w") as f:
    json.dump(merged, f, indent=2)
    f.write("\n")
PYEOF
        rm -f "$tmp"
        trap - EXIT
        echo_err "Paseo config merge failed (unparseable live config?)."
        echo_err "Remediation: validate $PASEO_LIVE_CONFIG as JSON, back it up, then re-run."
        return 1
    fi
    trap - EXIT
    if cmp -s "$tmp" "$PASEO_LIVE_CONFIG"; then
        rm -f "$tmp"
        echo_success "Paseo config already converged; password/providers preserved."
    else
        # Safety: refuse to write if the live config carries a password
        # and the merge somehow dropped it (defense in depth; the merge
        # above never touches auth.password, but verify anyway).
        if python3 -c "import json; c=json.load(open('$PASEO_LIVE_CONFIG')); assert c.get('daemon',{}).get('auth',{}).get('password','')" 2>/dev/null; then
            if ! python3 -c "import json; c=json.load(open('$tmp')); assert c.get('daemon',{}).get('auth',{}).get('password','')" 2>/dev/null; then
                rm -f "$tmp"
                echo_err "Merge would drop daemon.auth.password; refusing to write (fail-closed)."
                return 1
            fi
        fi
        mv "$tmp" "$PASEO_LIVE_CONFIG"
        chmod 600 "$PASEO_LIVE_CONFIG"
        echo_success "Paseo config reconciled (listen converged; password/providers/runtime preserved)."
    fi
    ensure_paseo_env_allowlist
}

ensure_paseo_env_allowlist() {
    # The user unit must never load the whole secrets file (R28). It
    # loads .env-common + .env-override + this generated allowlist file
    # (0600) carrying only PASEO_PASSWORD. Regenerated when the secrets
    # value changes; compare-before-write keeps it a no-op otherwise.
    local secrets_val=""
    if [[ -f "$PASEO_SECRETS_FILE" ]]; then
        secrets_val="$(grep -E '^PASEO_PASSWORD=' "$PASEO_SECRETS_FILE" 2>/dev/null | tail -1 | cut -d= -f2- || echo '')"
    fi
    if [[ "$DRY_RUN" == true ]]; then
        dry_echo "reconcile $PASEO_ENV_FILE (PASEO_PASSWORD allowlist only, chmod 600)"
        return 0
    fi
    local tmp
    tmp="$(mktemp)"
    trap 'rm -f "$tmp"' EXIT
    {
        printf '# Generated by dev-stack.sh (Paseo allowlist). Do not edit; set PASEO_PASSWORD in .env-secrets.\n'
        if [[ -n "$secrets_val" ]]; then
            printf 'PASEO_PASSWORD=%s\n' "$secrets_val"
        else
            printf '# PASEO_PASSWORD is unset in .env-secrets.\n'
        fi
    } >"$tmp"
    chmod 600 "$tmp"
    if [[ -f "$PASEO_ENV_FILE" ]] && cmp -s "$tmp" "$PASEO_ENV_FILE"; then
        rm -f "$tmp"
        trap - EXIT
        return 0
    fi
    mv "$tmp" "$PASEO_ENV_FILE"
    chmod 600 "$PASEO_ENV_FILE"
    trap - EXIT
    echo_info "Paseo env allowlist reconciled ($PASEO_ENV_FILE)."
}

paseo_effective_listen() {
    # Prints the effective daemon listen address (live config, else
    # the intended default). Never prints secrets. Fail-closed: any
    # read/parse failure defaults to the remote bind, never to empty
    # (an unreadable config must not silently open the daemon).
    if [[ -f "$PASEO_LIVE_CONFIG" ]]; then
        python3 -c "import json; print(json.load(open('$PASEO_LIVE_CONFIG')).get('daemon',{}).get('listen',''))" 2>/dev/null || echo '0.0.0.0:6767'
    else
        echo '0.0.0.0:6767'
    fi
}

paseo_password_set() {
    [[ -n "${PASEO_PASSWORD:-}" ]] && return 0
    if [[ -f "$PASEO_ENV_FILE" ]] && grep -qE '^PASEO_PASSWORD=.+' "$PASEO_ENV_FILE" 2>/dev/null; then
        return 0
    fi
    if [[ -f "$PASEO_SECRETS_FILE" ]] && grep -qE '^PASEO_PASSWORD=.+' "$PASEO_SECRETS_FILE" 2>/dev/null; then
        return 0
    fi
    return 1
}

paseo_password_in_unit_env() {
    # R28: systemd user units load PASEO_PASSWORD only from the
    # EnvironmentFile (the .env-paseo allowlist file). The caller's
    # bash environment is irrelevant because systemd discards it.
    # This function checks only the file-based surface that the unit
    # actually loads.
    if [[ -f "$PASEO_ENV_FILE" ]] && grep -qE '^PASEO_PASSWORD=.+' "$PASEO_ENV_FILE" 2>/dev/null; then
        return 0
    fi
    return 1
}

require_paseo_password_for_remote() {
    # Fail-closed (R28): a 0.0.0.0 bind without PASEO_PASSWORD refuses
    # with exit 3. No open remote daemon, ever.
    # $1 = "unit" when the managed systemd unit is involved: the unit
    # template hardcodes `--listen 0.0.0.0:6767`, so the password is
    # required unconditionally there (the config-file listen value is
    # not the bind surface for unit paths). Otherwise the effective
    # config listen decides.
    local mode="${1:-config}"
    if [[ "$mode" == "unit" ]]; then
        if ! paseo_password_in_unit_env; then
            echo_err "Refusing to install/enable/start the Paseo unit without PASEO_PASSWORD in .env-paseo (fail-closed: the unit binds 0.0.0.0)."
            echo_err "Remediation: set PASEO_PASSWORD in ~/.config/heypogi/.env-secrets, run 'dev-stack.sh install -a paseo', then retry."
            return 3
        fi
        return 0
    fi
    local listen
    listen="$(paseo_effective_listen)"
    case "$listen" in
        0.0.0.0*|"[::]"*|"*"*)
            if ! paseo_password_set; then
                echo_err "Refusing to bind Paseo to '$listen' without PASEO_PASSWORD (fail-closed)."
                echo_err "Remediation: set PASEO_PASSWORD in ~/.config/heypogi/.env-secrets, run 'dev-stack.sh install -a paseo', then retry."
                return 3
            fi
            ;;
    esac
    return 0
}

migrate_legacy_system_unit() {
    # R22: detect the bootstrap.sh:353-era system unit, stop + disable
    # it (narrow sudo, logged, dry-run aware), verify the port is free,
    # then let the caller install the user unit.
    if [[ ! -f "$LEGACY_SYSTEM_UNIT" ]]; then
        return 0
    fi
    echo_warn "Legacy system unit detected: $LEGACY_SYSTEM_UNIT (migrating to the rootless user unit)."
    if [[ "$DRY_RUN" == true ]]; then
        dry_echo "sudo systemctl stop paseo.service + sudo systemctl disable paseo.service + verify port $PASEO_PORT free"
        return 0
    fi
    run_priv systemctl stop paseo.service || true
    run_priv systemctl disable paseo.service || true
    run_priv rm -f "$LEGACY_SYSTEM_UNIT" || return 1
    run_priv systemctl daemon-reload || true
    sleep 1
    if check_port "$PASEO_PORT"; then
        echo_err "Port $PASEO_PORT still held after legacy unit removal; refusing to install the user unit over it."
        echo_err "Remediation: identify the listener (ss -tlnp | grep $PASEO_PORT), stop it, then re-run."
        return 1
    fi
    echo_success "Legacy system unit removed; port $PASEO_PORT free."
}

ensure_linger() {
    # R23: linger ownership. When privileged, enable + verify; when
    # unprivileged and linger is off, exit 3 (blocker) with the exact
    # one-time remediation instead of a WARN-only pass.
    local user
    user="$(whoami)"
    local linger
    linger="$(loginctl show-user "$user" 2>/dev/null | grep -i '^Linger=' || echo 'Linger=unknown')"
    if [[ "$linger" == "Linger=yes" ]]; then
        return 0
    fi
    if sudo -n true 2>/dev/null; then
        echo_info "Enabling linger (one-time, privileged)..."
        run_priv loginctl enable-linger "$user"
        linger="$(loginctl show-user "$user" 2>/dev/null | grep -i '^Linger=' || echo 'Linger=unknown')"
        if [[ "$linger" == "Linger=yes" ]]; then
            echo_success "Linger enabled for $user."
            return 0
        fi
        echo_err "Failed to enable linger for $user."
        return 3
    fi
    echo_err "Linger is off for $user: the user service will stop at logout (blocker)."
    echo_err "Remediation (one-time, requires sudo): sudo loginctl enable-linger $user"
    return 3
}

# --- Install ---
do_install() {
    local apps
    apps=$(resolve_app_list "$APP")

    # R31: fail closed when the registry is unreachable instead of
    # misreading empty lookups as "up to date" and mutating anyway.
    if [[ "$DRY_RUN" != true ]]; then
        if ! registry_reachable; then
            echo_err "npm registry unreachable (offline?). Cannot evaluate versions; refusing to mutate."
            echo_err "Remediation: restore network, then re-run."
            return 3
        fi
    fi
    
    local to_update=()
    local oc_ver ocweb_ver paseo_ver
    
    oc_ver=$(get_version "opencode")
    ocweb_ver=$(get_version "openchamber")
    paseo_ver=$(get_version "paseo")
    
    local latest_oc latest_ocweb latest_paseo_latest latest_paseo_beta latest_paseo
    latest_oc=$(get_latest_version "$PKG_OPENCODE")
    latest_ocweb=$(get_latest_version "$PKG_OPENCHAMBER")
    latest_paseo_latest=$(get_latest_version "$PKG_PASEO")
    latest_paseo_beta=$(get_dist_tag_version "$PKG_PASEO" "beta")
    
    if [[ -n "$latest_paseo_beta" ]] && version_gte "$latest_paseo_beta" "$latest_paseo_latest"; then
        latest_paseo="$latest_paseo_beta"
    else
        latest_paseo="$latest_paseo_latest"
    fi
    
    # Check what needs updating
    if [[ "$apps" == *"opencode"* ]] || [[ "$apps" == *"all"* ]]; then
        if [[ -z "$oc_ver" ]] || ! version_gte "$oc_ver" "$latest_oc"; then
            to_update+=("opencode")
            echo_warn "OpenCode: ${oc_ver:-NOT INSTALLED} -> $latest_oc"
        else
            echo_success "OpenCode: up to date ($oc_ver)"
        fi
    fi
    
    if [[ "$apps" == *"openchamber"* ]] || [[ "$apps" == *"all"* ]]; then
        if [[ -z "$ocweb_ver" ]] || ! version_gte "$ocweb_ver" "$latest_ocweb"; then
            to_update+=("openchamber")
            echo_warn "OpenChamber: ${ocweb_ver:-NOT INSTALLED} -> $latest_ocweb"
        else
            echo_success "OpenChamber: up to date ($ocweb_ver)"
        fi
    fi
    
    if [[ "$apps" == *"paseo"* ]] || [[ "$apps" == *"all"* ]]; then
        if [[ -z "$paseo_ver" ]] || ! version_gte "$paseo_ver" "$latest_paseo"; then
            to_update+=("paseo")
            local paseo_tag="latest"
            [[ "$latest_paseo" == "$latest_paseo_beta" ]] && paseo_tag="beta"
            echo_warn "Paseo: ${paseo_ver:-NOT INSTALLED} -> $latest_paseo ($paseo_tag)"
        else
            echo_success "Paseo: up to date ($paseo_ver)"
        fi
    fi
    
    if [[ ${#to_update[@]} -eq 0 ]]; then
        echo_success "Everything is already up to date."
        if [[ "$apps" == *"paseo"* ]] || [[ "$apps" == *"all"* ]]; then
            seed_paseo_config || return $?
        fi
        return 0
    fi

    # Preview needs no consent: it changes nothing. Print the complete
    # plan before any confirmation gate.
    if [[ "$DRY_RUN" == true ]]; then
        if [[ ${#to_update[@]} -eq 0 ]]; then
            dry_echo "everything up to date; would reconcile Paseo config + verify (read-only)"
        else
        for tool in "${to_update[@]}"; do
            case "$tool" in
                opencode) dry_echo "install/update opencode (npm or opencode.ai installer)" ;;
                openchamber) dry_echo "npm install -g $PKG_OPENCHAMBER" ;;
                paseo)
                    local paseo_tag="latest"
                    [[ "$latest_paseo" == "$latest_paseo_beta" ]] && paseo_tag="beta"
                    dry_echo "npm install -g ${PKG_PASEO}${paseo_tag:+@$paseo_tag} (tag resolved live; shown resolved)"
                    ;;
            esac
        done
        dry_echo "seed/reconcile Paseo config (additive merge, password-preserving)"
        dry_echo "restart affected services + verify (read-only)"
        fi
        return 0
    fi

    # Confirm: --force authorizes the declared installs. Quiet never
    # implies consent; non-interactive without --force fails loudly.
    if [[ "$FORCE" == false ]]; then
        if [[ -t 0 ]]; then
            printf '%s' "Install/update ${to_update[*]}? [Y/n] " >&2
            read -r choice
            if [[ "$choice" =~ ^[Nn] ]]; then
                echo_info "Aborted."
                return 1
            fi
        else
            echo_err "Refusing to install/update ${to_update[*]} non-interactively without --force."
            echo_err "Remediation: re-run with -f/--force, or run interactively."
            return 1
        fi
    fi
    
    # Install
    local install_failed=0
    for tool in "${to_update[@]}"; do
        printf '\n'
        echo_info "=== Updating $tool ==="

        case "$tool" in
            opencode)
                if command -v opencode &>/dev/null; then
                    if command -v timeout &>/dev/null; then
                        timeout 180 bash -c 'curl -fsSL --connect-timeout 15 --max-time 120 https://opencode.ai/install | bash' || install_failed=1
                    else
                        bash -c 'curl -fsSL --connect-timeout 15 --max-time 120 https://opencode.ai/install | bash' || install_failed=1
                    fi
                else
                    npm_install_global "$PKG_OPENCODE" || install_failed=1
                fi
                ;;
            openchamber)
                npm_install_global "$PKG_OPENCHAMBER" || install_failed=1
                ;;
            paseo)
                # paseo_tag was computed above (from comparing the "latest"
                # and "beta" dist-tags) but was never actually used here -
                # this always installed plain @getpaseo/cli, i.e. whatever
                # "latest" resolves to, even when a newer beta was detected
                # and reported in the update message above.
                if [[ "${paseo_tag:-latest}" == "beta" ]]; then
                    npm_install_global "${PKG_PASEO}@beta" || install_failed=1
                else
                    npm_install_global "$PKG_PASEO" || install_failed=1
                fi
                ;;
        esac
    done

    # Paseo config seed/merge is part of install (R7/R29), after packages.
    if [[ "$apps" == *"paseo"* ]] || [[ "$apps" == *"all"* ]]; then
        seed_paseo_config || install_failed=1
    fi

    if [[ "$install_failed" -ne 0 ]]; then
        echo_err "Install converged with failures (see above)."
        return 1
    fi

    # Restart services
    printf '\n'
    if [[ " ${to_update[*]} " == *" openchamber "* ]]; then
        echo_info "Restarting OpenChamber..."
        do_start_app "openchamber" || true
    fi

    if [[ " ${to_update[*]} " == *" paseo "* ]]; then
        echo_info "Restarting Paseo daemon..."
        do_start_app "paseo" || true
    fi

    # Verify (informational: install result above is authoritative and
    # must not be erased by the summary).
    printf '\n'
    echo_info "Verifying..."
    collect_status
    write_status_report || true
}

# --- Start ---
do_start_app() {
    local app="$1"
    
    case "$app" in
        opencode)
            echo_info "OpenCode: no standalone daemon to start (runs as sidecar)"
            ;;
        openchamber)
            if [[ "$DRY_RUN" == true ]]; then
                dry_echo "start OpenChamber (openchamber serve --host 0.0.0.0 --port $OPENCHAMBER_PORT)"
                return 0
            fi
            if ! check_port "$OPENCHAMBER_PORT"; then
                echo_info "Starting OpenChamber..."
                nohup openchamber serve --host 0.0.0.0 --port "$OPENCHAMBER_PORT" > /dev/null 2>&1 &
                sleep 2
                if check_port "$OPENCHAMBER_PORT"; then
                    echo_success "OpenChamber started"
                else
                    echo_warn "OpenChamber may have failed to start"
                    if [[ -z "${OPENCHAMBER_UI_PASSWORD:-}" ]]; then
                        echo_warn "OpenChamber refuses to bind to 0.0.0.0 without a UI password. Set one first:"
                        echo_warn "  export OPENCHAMBER_UI_PASSWORD=\"yourpassword\""
                        echo_warn "  echo 'export OPENCHAMBER_UI_PASSWORD=\"yourpassword\"' >> ~/.bashrc"
                    fi
                    return 1
                fi
            else
                echo_success "OpenChamber already running"
            fi
            ;;
        paseo)
            if [[ "$DRY_RUN" == true ]]; then
                dry_echo "start paseo.service (user unit) or 'paseo daemon start' fallback"
                return 0
            fi
            ensure_user_bus
            if systemctl --user list-unit-files paseo.service &>/dev/null 2>&1; then
                require_paseo_password_for_remote unit || return $?
            else
                require_paseo_password_for_remote config || return $?
            fi
            if ! check_port "$PASEO_PORT"; then
                echo_info "Starting Paseo daemon..."
                if systemctl --user list-unit-files paseo.service &>/dev/null 2>&1; then
                    systemctl --user start paseo.service || true
                else
                    nohup paseo daemon start > /dev/null 2>&1 &
                    sleep 2
                fi
                if check_port "$PASEO_PORT"; then
                    echo_success "Paseo daemon started"
                else
                    echo_warn "Paseo daemon may have failed to start"
                    return 1
                fi
            else
                echo_success "Paseo daemon already running"
            fi
            ;;
    esac
}

# --- Stop ---
do_stop_app() {
    local app="$1"
    
    case "$app" in
        opencode)
            echo_info "OpenCode: nothing to stop (no standalone daemon)"
            ;;
        openchamber)
            if [[ "$DRY_RUN" == true ]]; then
                dry_echo "stop OpenChamber listener on port $OPENCHAMBER_PORT"
                return 0
            fi
            if check_port "$OPENCHAMBER_PORT"; then
                local pid
                pid=$(get_listening_pid "$OPENCHAMBER_PORT")
                if [[ -n "$pid" ]]; then
                    echo_info "Stopping OpenChamber (pid $pid)..."
                    kill "$pid" 2>/dev/null
                    sleep 1
                    echo_success "OpenChamber stopped"
                fi
            else
                echo_info "OpenChamber not running"
            fi
            ;;
        paseo)
            if [[ "$DRY_RUN" == true ]]; then
                dry_echo "stop Paseo daemon on port $PASEO_PORT"
                return 0
            fi
            if check_port "$PASEO_PORT"; then
                echo_info "Stopping Paseo daemon..."
                ensure_user_bus
                if systemctl --user list-unit-files paseo.service &>/dev/null 2>&1; then
                    systemctl --user stop paseo.service 2>/dev/null
                else
                    paseo daemon stop 2>/dev/null
                fi
                echo_success "Paseo daemon stopped"
            else
                echo_info "Paseo daemon not running"
            fi
            ;;
    esac
}

# --- Fix ---
do_fix() {
    collect_status

    local issues=0
    for entry in "${CHECKS[@]}"; do
        IFS='|' read -r service check status detail <<< "$entry"
        [[ "$status" == "FAIL" ]] && issues=$((issues+1))
    done

    if [[ $issues -eq 0 ]]; then
        echo_success "No runtime issues to fix."
        return 0
    fi

    # Fix restarts services and rewrites config: --force authorizes it.
    # Quiet never implies consent; non-interactive without --force fails.
    if [[ "$FORCE" == false ]]; then
        if [[ "$DRY_RUN" == true ]]; then
            dry_echo "fix $issues issue(s): restart stopped services, reconcile Paseo config, verify"
            return 0
        fi
        if [[ -t 0 ]]; then
            printf '%s' "Fix $issues issue(s)? [y/N] " >&2
            read -r choice
            if [[ ! "$choice" =~ ^[Yy] ]]; then
                echo_info "Aborted."
                return 1
            fi
        else
            echo_err "Refusing to fix $issues issue(s) non-interactively without --force."
            echo_err "Remediation: re-run with -f/--force, or run interactively."
            return 1
        fi
    fi

    if [[ "$DRY_RUN" == true ]]; then
        dry_echo "fix $issues issue(s): restart stopped services, reconcile Paseo config, verify"
        return 0
    fi

    echo_info "Fixing runtime state..."

    # Ensure services are running
    local apps
    apps=$(resolve_app_list "$APP")

    local fix_rc=0
    if [[ "$apps" == *"openchamber"* ]] || [[ "$apps" == *"all"* ]]; then
        if ! check_port "$OPENCHAMBER_PORT"; then
            do_start_app "openchamber" || fix_rc=$?
        fi
    fi
    if [[ "$apps" == *"paseo"* ]] || [[ "$apps" == *"all"* ]]; then
        if ! check_port "$PASEO_PORT"; then
            do_start_app "paseo" || fix_rc=$?
        fi
        # Reconcile Paseo config additively (password-preserving) instead
        # of sed-rewriting the live file.
        seed_paseo_config || fix_rc=$?
    fi
    if [[ "$fix_rc" -ne 0 ]]; then
        echo_err "Fix converged with failures (see above)."
        return "$fix_rc"
    fi

    # Verify (informational; fix failures above already returned).
    printf '\n'
    echo_info "Verifying..."
    collect_status
    write_status_report || true
}

# --- Startup (systemd user unit; never the system unit) ---
startup_ensure_allowlist_lines() {
    # Reconcile the unit's EnvironmentFile allowlist (R28): common +
    # override + generated .env-paseo. Removes any legacy line loading
    # the whole .env-secrets file. Atomic: reads, merges in memory,
    # writes to mktemp, cmp before mv (no check-then-sed race).
    # Returns 0 when converged, 1 when changed.
    local target="$1"
    local changed=0

    if [[ "$DRY_RUN" == true ]]; then
        local need_add=0 need_rm=0
        for line in "EnvironmentFile=-%h/.config/heypogi/.env-common" \
                    "EnvironmentFile=-%h/.config/heypogi/.env-override" \
                    "EnvironmentFile=-%h/.config/heypogi/.env-paseo"; do
            grep -qF "$line" "$target" 2>/dev/null || need_add=1
        done
        grep -qF "EnvironmentFile=-%h/.config/heypogi/.env-secrets" "$target" 2>/dev/null && need_rm=1
        if [[ "$need_add" -eq 1 || "$need_rm" -eq 1 ]]; then
            dry_echo "reconcile EnvironmentFile allowlist in $target (atomic rewrite)"
        fi
        return 0
    fi

    local tmp_target
    tmp_target="$(mktemp "${target}.tmp.XXXXXX")"
    trap 'rm -f "$tmp_target"' EXIT

    # Build the desired unit file content: keep all lines except the
    # legacy whole-secrets line, and ensure the three allowlist lines
    # are present before ExecStart=.
    local allowlist_inserted=0
    while IFS= read -r src_line || [[ -n "$src_line" ]]; do
        # Skip legacy whole-secrets line
        if [[ "$src_line" =~ ^EnvironmentFile=-.*\.config/heypogi/\.env-secrets$ ]]; then
            changed=1
            continue
        fi
        # Insert allowlist lines before the first ExecStart=
        if [[ "$allowlist_inserted" -eq 0 && "$src_line" =~ ^ExecStart= ]]; then
            printf '%s\n' "EnvironmentFile=-%h/.config/heypogi/.env-common" >>"$tmp_target"
            printf '%s\n' "EnvironmentFile=-%h/.config/heypogi/.env-override" >>"$tmp_target"
            printf '%s\n' "EnvironmentFile=-%h/.config/heypogi/.env-paseo" >>"$tmp_target"
            allowlist_inserted=1
        fi
        printf '%s\n' "$src_line" >>"$tmp_target"
    done <"$target"

    # Handle edge case: no ExecStart= found, append at end
    if [[ "$allowlist_inserted" -eq 0 ]]; then
        printf '%s\n' "EnvironmentFile=-%h/.config/heypogi/.env-common" >>"$tmp_target"
        printf '%s\n' "EnvironmentFile=-%h/.config/heypogi/.env-override" >>"$tmp_target"
        printf '%s\n' "EnvironmentFile=-%h/.config/heypogi/.env-paseo" >>"$tmp_target"
        allowlist_inserted=1
    fi

    # Check if any allowlist line was missing (even if we didn't skip
    # the secrets line, the content may have changed)
    for line in "EnvironmentFile=-%h/.config/heypogi/.env-common" \
                "EnvironmentFile=-%h/.config/heypogi/.env-override" \
                "EnvironmentFile=-%h/.config/heypogi/.env-paseo"; do
        grep -qF "$line" "$tmp_target" 2>/dev/null || changed=1
    done

    if [[ "$changed" -eq 0 ]]; then
        rm -f "$tmp_target"
        trap - EXIT
        return 0
    fi

    mv "$tmp_target" "$target"
    trap - EXIT
    return 1
}

do_startup() {
    local verb="$1"
    local apps
    apps=$(resolve_app_list "$APP")
    local startup_rc=0

    for app in $apps; do
        case "$app" in
            opencode)
                echo_info "OpenCode: no autostart mechanism (runs as sidecar)"
                ;;
            openchamber)
                echo_info "OpenChamber: no built-in autostart (use systemd or cron)"
                ;;
            paseo)
                # Userspace autostart: systemd USER unit, no sudo required
                # except the one-time linger grant and legacy cleanup.
                ensure_user_bus
                local SERVICE_FILE="$HOME/.config/systemd/user/paseo.service"
                local TEMPLATE="$SCRIPT_DIR/paseo.service"
                local SHIMS="$SCRIPT_DIR/../bin/userspace-shims.sh"

                case "$verb" in
                    install)
                        require_paseo_password_for_remote unit || { startup_rc=$?; continue; }
                        migrate_legacy_system_unit || { startup_rc=$?; continue; }
                        ensure_linger || { startup_rc=$?; continue; }
                        # R32: provision the userspace PATH layout before
                        # the rootless unit install, then prove the unit's
                        # binary path resolves.
                        if [[ "$DRY_RUN" == true ]]; then
                            dry_echo "$SHIMS install -q (+ --dry-run passthrough)"
                        else
                            bash "$SHIMS" install -q || {
                                startup_rc=$?
                                echo_err "userspace-shims install failed; refusing to enable the unit over an unprovisioned path."
                                [[ "$startup_rc" -eq 0 ]] && startup_rc=1
                                continue
                            }
                        fi
                        if [[ "$DRY_RUN" != true ]] && ! command -v paseo >/dev/null 2>&1; then
                            echo_err "paseo does not resolve on the userspace PATH (blocker)."
                            echo_err "Remediation: run 'dev-stack.sh install -a paseo', then re-run startup install."
                            startup_rc=1
                            continue
                        fi
                        ensure_paseo_env_allowlist || { startup_rc=$?; continue; }
                        if [[ -f "$SERVICE_FILE" ]]; then
                            if startup_ensure_allowlist_lines "$SERVICE_FILE"; then
                                if [[ "$DRY_RUN" == true ]]; then
                                    dry_echo "unit $SERVICE_FILE already converged (no writes)"
                                else
                                    echo_success "Paseo user service already converged"
                                fi
                            else
                                if [[ "$DRY_RUN" != true ]]; then
                                    systemctl --user daemon-reload
                                    echo_success "Paseo user service updated (allowlist, no whole-secrets)"
                                else
                                    dry_echo "systemctl --user daemon-reload"
                                    dry_echo "unit $SERVICE_FILE would be updated (allowlist, no whole-secrets)"
                                fi
                            fi
                        elif [[ -f "$TEMPLATE" ]]; then
                            if [[ "$DRY_RUN" == true ]]; then
                                dry_echo "install $SERVICE_FILE from template + systemctl --user daemon-reload + enable"
                            else
                                mkdir -p "$(dirname "$SERVICE_FILE")"
                                cp "$TEMPLATE" "$SERVICE_FILE"
                                chmod 600 "$SERVICE_FILE"
                                startup_ensure_allowlist_lines "$SERVICE_FILE" || true
                                systemctl --user daemon-reload
                                systemctl --user enable paseo.service
                                echo_success "Paseo user service installed (~/.config/systemd/user/paseo.service)"
                            fi
                        else
                            echo_err "paseo.service template not found at $TEMPLATE"
                            startup_rc=1
                        fi
                        ;;
                    fix)
                        if [[ -f "$SERVICE_FILE" ]]; then
                            if startup_ensure_allowlist_lines "$SERVICE_FILE"; then
                                if [[ "$DRY_RUN" == true ]]; then
                                    dry_echo "unit $SERVICE_FILE already converged (no writes)"
                                else
                                    echo_success "Paseo user service already converged"
                                fi
                            else
                                if [[ "$DRY_RUN" != true ]]; then
                                    systemctl --user daemon-reload
                                    echo_success "Paseo user service fixed (allowlist, no whole-secrets)"
                                else
                                    dry_echo "systemctl --user daemon-reload"
                                    dry_echo "unit $SERVICE_FILE would be fixed (allowlist, no whole-secrets)"
                                fi
                            fi
                            ensure_paseo_env_allowlist || startup_rc=$?
                        else
                            echo_err "paseo.service not found at $SERVICE_FILE"
                            echo_err "Remediation: run 'dev-stack.sh startup install -a paseo'."
                            startup_rc=1
                        fi
                        ;;
                    enable)
                        require_paseo_password_for_remote unit || { startup_rc=$?; continue; }
                        if [[ "$DRY_RUN" == true ]]; then
                            dry_echo "systemctl --user enable paseo.service"
                        elif systemctl --user enable paseo.service 2>/dev/null; then
                            echo_success "Enabled paseo.service (user)"
                        else
                            echo_err "Could not enable paseo.service."
                            startup_rc=1
                        fi
                        ;;
                    disable)
                        if [[ "$DRY_RUN" == true ]]; then
                            dry_echo "systemctl --user disable paseo.service"
                        elif systemctl --user disable paseo.service 2>/dev/null; then
                            echo_success "Disabled paseo.service (user)"
                        else
                            echo_err "Could not disable paseo.service."
                            startup_rc=1
                        fi
                        ;;
                    uninstall)
                        if [[ "$DRY_RUN" == true ]]; then
                            dry_echo "systemctl --user disable paseo.service + remove $SERVICE_FILE + daemon-reload"
                        else
                            systemctl --user disable paseo.service 2>/dev/null || true
                            rm -f "$HOME/.config/systemd/user/paseo.service"
                            systemctl --user daemon-reload
                            echo_success "Paseo user service removed"
                        fi
                        ;;
                esac
                ;;
        esac
    done

    # Verify (informational; the startup result above is authoritative).
    printf '\n'
    echo_info "Verifying..."
    collect_status
    write_status_report || true
    return "$startup_rc"
}

# --- App Resolution ---
resolve_app_list() {
    local app="$1"
    
    case "${app,,}" in
        all|"")     echo "opencode openchamber paseo" ;;
        opencode)   echo "opencode" ;;
        openchamber) echo "openchamber" ;;
        paseo)      echo "paseo" ;;
        *)          echo_err "Unknown app: $app (want: opencode|openchamber|paseo|all)"; exit 2 ;;
    esac
}

# --- Help (prints and returns; the caller decides the exit status) ---
show_help() {
    cat << 'EOF'
dev-stack.sh - AI Dev Stack Manager (Linux)

Usage: ./dev-stack.sh [command] [options]

Commands:
  status       Check everything and report issues (default).
               Exit 0 converged, 1 drift, 3 indeterminate/blocked.
  install      Install or update all tools to latest (incl. Paseo
               config seed/merge). Idempotent.
  update       Alias for install
  fix          Auto-fix runtime issues (start services, fix config)
  start        Start services
  stop         Stop services
  restart      Restart services
  startup      Manage autostart (systemd user unit, never system):
               startup install|fix|enable|disable|uninstall [-a paseo]
  uninstall    Remove tools (requires -a)
  help         Show this help

Options:
  -a, --app APP     Target app: opencode, openchamber, paseo, all (default: all)
  -f, --force       Skip confirmation prompts (declared targets only)
  -q, --quiet       Suppress non-essential output (never implies consent)
  --dry-run         Plan only, zero writes (forwarded to children)
  -h, --help        Show this help

Examples:
  ./dev-stack.sh                          # Check status
  ./dev-stack.sh install                  # Install/update all
  ./dev-stack.sh install -a paseo         # Install/update Paseo only
  ./dev-stack.sh start                    # Start all services
  ./dev-stack.sh stop -a openchamber      # Stop OpenChamber only
  ./dev-stack.sh startup install -a paseo # Install Paseo systemd user service

OpenChamber will not bind to 0.0.0.0 (LAN-reachable) without a UI password.
Set one before starting it:
  export OPENCHAMBER_UI_PASSWORD="yourpassword"
  echo 'export OPENCHAMBER_UI_PASSWORD="yourpassword"' >> ~/.bashrc

Paseo will not bind to 0.0.0.0 without PASEO_PASSWORD set (fail-closed).
Set it in ~/.config/heypogi/.env-secrets, then run:
  ./dev-stack.sh install -a paseo   # seeds ~/.config/heypogi/.env-paseo
EOF
    return 0
}

# --- Defaults ---
COMMAND="status"
STARTUP_VERB=""
APP="all"
FORCE=false
QUIET=false
DRY_RUN=false
REGISTRY_OK=true
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Narrowly scoped sudo wrapper for machine-level steps only (apt,
# linger, legacy-unit removal). Logs before execution, dry-run aware.
# User-scoped work in this script never elevates.
run_priv() {
    if [[ "$DRY_RUN" == true ]]; then
        dry_echo "sudo $*"
        return 0
    fi
    echo_info "Running with sudo: $*"
    sudo "$@"
}

# --- Parse args (validate everything before any mutation) ---
EXPECT_STARTUP_VERB=false
COMMAND_SET=false
while [[ $# -gt 0 ]]; do
    case "$1" in
        status|update|start|stop|restart|startup|help)
            if [[ "$EXPECT_STARTUP_VERB" == true ]]; then
                echo_err "startup requires a subcommand: install, fix, enable, disable, uninstall"
                exit 2
            fi
            if [[ "$COMMAND_SET" == true ]]; then
                echo_err "Multiple commands given ('$COMMAND' and '$1'); pass exactly one."
                exit 2
            fi
            COMMAND="$1"; COMMAND_SET=true; shift
            if [[ "$COMMAND" == "startup" ]]; then
                EXPECT_STARTUP_VERB=true
            fi
            ;;
        install|fix|enable|disable|uninstall)
            if [[ "$EXPECT_STARTUP_VERB" == true && -z "$STARTUP_VERB" ]]; then
                STARTUP_VERB="$1"; EXPECT_STARTUP_VERB=false; shift
            elif [[ "$COMMAND_SET" == true ]]; then
                echo_err "Multiple commands given ('$COMMAND' and '$1'); pass exactly one."
                exit 2
            elif [[ "$1" == "install" || "$1" == "fix" || "$1" == "uninstall" ]]; then
                COMMAND="$1"; COMMAND_SET=true; shift
            else
                echo_err "Invalid command: $1 (enable|disable are startup subcommands: startup $1 -a paseo)."
                exit 2
            fi
            ;;
        -a|--app)
            if [[ $# -lt 2 || "$2" == -* ]]; then
                echo_err "Missing value for $1 (want: opencode|openchamber|paseo|all)."
                exit 2
            fi
            APP="$2"; shift 2 ;;
        -f|--force)
            FORCE=true; shift ;;
        -q|--quiet)
            QUIET=true; shift ;;
        --dry-run)
            DRY_RUN=true; shift ;;
        -h|--help)
            show_help; exit 0 ;;
        --)
            shift
            while [[ $# -gt 0 ]]; do
                if [[ "$EXPECT_STARTUP_VERB" == true && -z "$STARTUP_VERB" ]]; then
                    case "$1" in
                        install|fix|enable|disable|uninstall)
                            STARTUP_VERB="$1"; EXPECT_STARTUP_VERB=false; shift; continue ;;
                    esac
                fi
                echo_err "Unexpected argument: $1"
                exit 2
            done
            ;;
        -*)
            echo_err "Unknown option: $1"
            echo_err "Remediation: see --help for valid options."
            exit 2
            ;;
        *)
            if [[ "$EXPECT_STARTUP_VERB" == true && -z "$STARTUP_VERB" ]]; then
                echo_err "Invalid startup subcommand: $1 (want: install|fix|enable|disable|uninstall)."
                exit 2
            fi
            echo_err "Unknown argument: $1"
            echo_err "Remediation: see --help for valid commands."
            exit 2
            ;;
    esac
done
if [[ "$COMMAND" == "startup" && -z "$STARTUP_VERB" ]]; then
    echo_err "startup requires a subcommand: install, fix, enable, disable, uninstall"
    exit 2
fi

# Guard: base env must exist (plan-only mode under --dry-run per KTD7).
# shellcheck disable=SC1091
source "$SCRIPT_DIR/../env/require-env.sh" || exit 3

# --- Main ---
case "$COMMAND" in
    status)
        collect_status
        write_status_report
        ;;
    install|update)
        do_install
        ;;
    fix)
        do_fix
        ;;
    start)
        apps=$(resolve_app_list "$APP")
        start_rc=0
        for app in $apps; do
            do_start_app "$app" || start_rc=$?
        done
        exit "$start_rc"
        ;;
    stop)
        apps=$(resolve_app_list "$APP")
        stop_rc=0
        for app in $apps; do
            do_stop_app "$app" || stop_rc=$?
        done
        exit "$stop_rc"
        ;;
    restart)
        if [[ "$DRY_RUN" == true ]]; then
            dry_echo "restart ${APP}: stop + start (no writes)"
            exit 0
        fi
        apps=$(resolve_app_list "$APP")
        restart_rc=0
        for app in $apps; do
            do_stop_app "$app" || restart_rc=$?
        done
        sleep 2
        for app in $apps; do
            do_start_app "$app" || restart_rc=$?
        done
        exit "$restart_rc"
        ;;
    startup)
        do_startup "$STARTUP_VERB"
        ;;
    uninstall)
        echo_err "Uninstall not yet implemented. Remove manually:"
        echo_err "  npm uninstall -g $PKG_OPENCODE $PKG_OPENCHAMBER $PKG_PASEO"
        exit 1
        ;;
    help)
        show_help
        ;;
esac

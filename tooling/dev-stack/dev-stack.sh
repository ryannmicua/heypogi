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
#   startup      Manage autostart (systemd)
#   uninstall    Remove tools
#   help         Show this help
#
# Options:
#   -a, --app APP     Target app: opencode, openchamber, paseo, all (default)
#   -f, --force       Skip confirmation prompts
#   -q, --quiet       Suppress non-essential output
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

# --- Constants ---
OPENCHAMBER_PORT=7777
PASEO_PORT=6767
PKG_OPENCODE="opencode-ai"
PKG_OPENCHAMBER="@openchamber/web"
PKG_PASEO="@getpaseo/cli"

# --- Colors ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
GRAY='\033[0;90m'
NC='\033[0m'

# --- State ---
CHECKS=()

# --- Helpers ---
echo_info()    { echo -e "${BLUE}INFO:${NC} $*"; }
echo_success() { echo -e "${GREEN}OK:${NC} $*"; }
echo_warn()    { echo -e "${YELLOW}WARN:${NC} $*"; }
echo_err()     { echo -e "${RED}ERROR:${NC} $*" >&2; }

run() {
    if [[ "$DRY_RUN" == true ]]; then
        echo -e "${CYAN}[DRY-RUN]${NC} $*"
        return 0
    fi
    "$@"
}

get_version() {
    local cmd="$1"
    if command -v "$cmd" &>/dev/null; then
        "$cmd" --version 2>/dev/null | head -1 | tr -d '[:space:]' || echo ""
    else
        echo ""
    fi
}

get_command_source() {
    local cmd="$1"
    if command -v "$cmd" &>/dev/null; then
        command -v "$cmd"
    else
        echo ""
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
        echo ""
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
    npm view "$package" version 2>/dev/null | tail -1 || echo ""
}

get_dist_tag_version() {
    local package="$1"
    local tag="$2"
    npm view "$package" "dist-tags.$tag" 2>/dev/null | tail -1 || echo ""
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

# npm install -g wrapper: retries with sudo when the global prefix is not writable
npm_install_global() {
    local pkg="$1"
    local output exit_code
    local npm_prefix
    npm_prefix=$(npm config get prefix 2>/dev/null || echo "/usr/local")

    output=$(npm install -g "$pkg" 2>&1) && { echo "$output"; return 0; }
    exit_code=$?

    # Only escalate to sudo if the global prefix's node_modules is not writable.
    # This avoids false triggers from "permission denied" text in package
    # lifecycle scripts (security fix for review finding #2).
    if [[ ! -w "$npm_prefix/lib/node_modules" ]]; then
        echo "$output"
        echo_warn "Need root permissions. Retrying with sudo..."
        sudo npm install -g "$pkg"
    else
        echo "$output"
        return $exit_code
    fi
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
            echo -e "${BLUE}${service}${NC}"
            current_service="$service"
        fi
        
        local color="$GREEN"
        local mark="ok  "
        
        case "$status" in
            FAIL) color="$RED"; mark="FAIL"; issues=$((issues+1)) ;;
            WARN) color="$YELLOW"; mark="WARN" ;;
        esac
        
        echo -ne "${color}"
        printf "  %-28s: %s" "$check" "$mark"
        [[ -n "$detail" ]] && printf " - %s" "$detail"
        echo -e "${NC}"
    done
    
    echo ""
    if [[ $issues -eq 0 ]]; then
        echo_success "All checks passed."
    else
        echo_warn "$issues issue(s) found. Run: dev-stack.sh fix"
    fi
    
    return $issues
}

# --- Status Collection ---
collect_status() {
    CHECKS=()
    
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
    
    # Paseo systemd service
    if command -v systemctl &>/dev/null; then
        local svc_status
        svc_status=$(systemctl is-active paseo.service 2>/dev/null || echo "inactive")
        if [[ "$svc_status" == "active" ]]; then
            add_check "Paseo" "Systemd service" "true" "paseo.service active"
        else
            # Check if it's registered at all
            if systemctl list-unit-files paseo.service &>/dev/null; then
                add_check "Paseo" "Systemd service" "false" "paseo.service $svc_status"
            else
                add_warn "Paseo" "Systemd service" "paseo.service not registered"
            fi
        fi
    fi
    
    # Paseo config checks
    local paseo_cfg="$HOME/.paseo/config.json"
    if [[ -f "$paseo_cfg" ]]; then
        local listen_ok pwd_ok
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
}

# --- Install ---
do_install() {
    local apps
    apps=$(resolve_app_list "$APP")
    
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
        return 0
    fi
    
    # Confirm
    if [[ "$FORCE" == false ]] && [[ "$QUIET" == false ]]; then
        echo -n "Install/update ${to_update[*]}? [Y/n] "
        read -r choice
        if [[ "$choice" =~ ^[Nn] ]]; then
            echo_info "Aborted."
            return 0
        fi
    fi
    
    # Install
    for tool in "${to_update[@]}"; do
        echo ""
        echo_info "=== Updating $tool ==="
        
        case "$tool" in
            opencode)
                if command -v opencode &>/dev/null; then
                    curl -fsSL https://opencode.ai/install | bash
                else
                    npm_install_global "$PKG_OPENCODE"
                fi
                ;;
            openchamber)
                npm_install_global "$PKG_OPENCHAMBER"
                ;;
            paseo)
                # paseo_tag was computed above (from comparing the "latest"
                # and "beta" dist-tags) but was never actually used here -
                # this always installed plain @getpaseo/cli, i.e. whatever
                # "latest" resolves to, even when a newer beta was detected
                # and reported in the update message above.
                if [[ "${paseo_tag:-latest}" == "beta" ]]; then
                    npm_install_global "${PKG_PASEO}@beta"
                else
                    npm_install_global "$PKG_PASEO"
                fi
                ;;
        esac
    done
    
    # Restart services
    echo ""
    if [[ " ${to_update[*]} " == *" openchamber "* ]]; then
        echo_info "Restarting OpenChamber..."
        do_start_app "openchamber" || true
    fi
    
    if [[ " ${to_update[*]} " == *" paseo "* ]]; then
        echo_info "Restarting Paseo daemon..."
        do_start_app "paseo" || true
    fi
    
    # Verify
    echo ""
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
                fi
            else
                echo_success "OpenChamber already running"
            fi
            ;;
        paseo)
            if ! check_port "$PASEO_PORT"; then
                echo_info "Starting Paseo daemon..."
                if command -v systemctl &>/dev/null && systemctl list-unit-files paseo.service &>/dev/null 2>&1; then
                    sudo systemctl start paseo.service
                else
                    nohup paseo daemon start > /dev/null 2>&1 &
                    sleep 2
                fi
                if check_port "$PASEO_PORT"; then
                    echo_success "Paseo daemon started"
                else
                    echo_warn "Paseo daemon may have failed to start"
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
            if check_port "$OPENCHAMBER_PORT"; then
                local pid
                pid=$(get_listening_pid "$OPENCHAMBER_PORT")
                if [[ -n "$pid" ]]; then
                    echo_info "Stopping OpenChamber (pid $pid)..."
                    kill "$pid" 2>/dev/null || true
                    sleep 1
                    echo_success "OpenChamber stopped"
                fi
            else
                echo_info "OpenChamber not running"
            fi
            ;;
        paseo)
            if check_port "$PASEO_PORT"; then
                echo_info "Stopping Paseo daemon..."
                if command -v systemctl &>/dev/null && systemctl list-unit-files paseo.service &>/dev/null 2>&1; then
                    sudo systemctl stop paseo.service
                else
                    paseo daemon stop 2>/dev/null || true
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
    
    echo_info "Fixing runtime state..."
    
    # Ensure services are running
    local apps
    apps=$(resolve_app_list "$APP")
    
    if [[ "$apps" == *"openchamber"* ]] || [[ "$apps" == *"all"* ]]; then
        if ! check_port "$OPENCHAMBER_PORT"; then
            do_start_app "openchamber"
        fi
    fi
    
    if [[ "$apps" == *"paseo"* ]] || [[ "$apps" == *"all"* ]]; then
        if ! check_port "$PASEO_PORT"; then
            do_start_app "paseo"
        fi
    fi
    
    # Fix Paseo config if needed
    local paseo_cfg="$HOME/.paseo/config.json"
    if [[ -f "$paseo_cfg" ]]; then
        if ! grep -q '"listen".*"0\.0\.0\.0:'"$PASEO_PORT" "$paseo_cfg" 2>/dev/null; then
            echo_warn "Paseo listen address is not 0.0.0.0:$PASEO_PORT"
            if [[ "$FORCE" == true ]] || [[ "$QUIET" == true ]]; then
                sed -i 's/"listen".*/"listen": "0.0.0.0:'"$PASEO_PORT"'",/' "$paseo_cfg"
                echo_info "Fixed listen address. Restarting Paseo..."
                sudo systemctl restart paseo.service 2>/dev/null || paseo daemon restart 2>/dev/null || true
            fi
        fi
    fi
    
    # Verify
    echo ""
    echo_info "Verifying..."
    collect_status
    write_status_report || true
}

# --- Startup (systemd) ---
do_startup() {
    local verb="$1"
    local apps
    apps=$(resolve_app_list "$APP")
    
    for app in $apps; do
        case "$app" in
            opencode)
                echo_info "OpenCode: no autostart mechanism (runs as sidecar)"
                ;;
            openchamber)
                echo_info "OpenChamber: no built-in autostart (use systemd or cron)"
                ;;
            paseo)
                local SERVICE_FILE="/etc/systemd/system/paseo.service"
                local TEMPLATE="$SCRIPT_DIR/paseo.service"

                ensure_env_file_lines() {
                    local target="$1"
                    local env_lines=(
                        "EnvironmentFile=-%h/.config/heypogi/.env-common"
                        "EnvironmentFile=-%h/.config/heypogi/.env-override"
                        "EnvironmentFile=-%h/.config/heypogi/.env-secrets"
                    )
                    local added=0
                    for line in "${env_lines[@]}"; do
                        local suffix
                        suffix=$(echo "$line" | sed 's|.*EnvironmentFile=-%h||')
                        if ! grep -q "EnvironmentFile=-.*${suffix}" "$target" 2>/dev/null; then
                            sudo sed -i "/^ExecStart=/i $line" "$target"
                            added=$((added+1))
                        fi
                    done
                    return $added
                }

                case "$verb" in
                    install)
                        if [[ -f "$SERVICE_FILE" ]]; then
                            # Existing service: append EnvironmentFile= lines if missing
                            local env_count
                            env_count=$(grep -c "EnvironmentFile=-.*\.config/heypogi" "$SERVICE_FILE" 2>/dev/null || true)
                            if [[ "$env_count" -lt 3 ]]; then
                                ensure_env_file_lines "$SERVICE_FILE"
                                sudo systemctl daemon-reload
                                echo_success "Paseo systemd service updated with env file references"
                            else
                                echo_success "Paseo systemd service already has env file references"
                            fi
                        elif [[ -f "$TEMPLATE" ]]; then
                            # New install: render template and write
                            local rendered
                            rendered=$(sed -e "s|__USER__|$(whoami)|g" -e "s|__HOME__|$HOME|g" "$TEMPLATE")
                            echo "$rendered" | sudo tee "$SERVICE_FILE" > /dev/null
                            sudo systemctl daemon-reload
                            sudo systemctl enable paseo.service
                            echo_success "Paseo systemd service installed"
                        else
                            echo_warn "paseo.service template not found at $TEMPLATE"
                        fi
                        ;;
                    fix)
                        if [[ -f "$SERVICE_FILE" ]]; then
                            local env_count
                            env_count=$(grep -c "EnvironmentFile=-.*\.config/heypogi" "$SERVICE_FILE" 2>/dev/null || true)
                            if [[ "$env_count" -lt 3 ]]; then
                                ensure_env_file_lines "$SERVICE_FILE"
                                sudo systemctl daemon-reload
                                echo_success "Paseo systemd service fixed with env file references"
                            else
                                echo_success "Paseo systemd service already has env file references"
                            fi
                        else
                            echo_warn "paseo.service not found at $SERVICE_FILE"
                        fi
                        ;;
                    enable)
                        sudo systemctl enable paseo.service 2>/dev/null && echo_success "Enabled paseo.service" || echo_warn "Could not enable paseo.service"
                        ;;
                    disable)
                        sudo systemctl disable paseo.service 2>/dev/null && echo_success "Disabled paseo.service" || echo_warn "Could not disable paseo.service"
                        ;;
                    uninstall)
                        sudo systemctl disable paseo.service 2>/dev/null || true
                        sudo rm -f /etc/systemd/system/paseo.service
                        sudo systemctl daemon-reload
                        echo_success "Paseo systemd service removed"
                        ;;
                esac
                ;;
        esac
    done
    
    echo ""
    echo_info "Verifying..."
    collect_status
    write_status_report || true
}

# --- App Resolution ---
resolve_app_list() {
    local app="$1"
    
    case "${app,,}" in
        all|"")     echo "opencode openchamber paseo" ;;
        opencode)   echo "opencode" ;;
        openchamber) echo "openchamber" ;;
        paseo)      echo "paseo" ;;
        *)          echo_err "Unknown app: $app"; exit 1 ;;
    esac
}

# --- Help ---
show_help() {
    cat << 'EOF'
dev-stack.sh - AI Dev Stack Manager (Linux)

Usage: ./dev-stack.sh [command] [options]

Commands:
  status       Check everything and report issues (default)
  install      Install or update all tools to latest
  update       Alias for install
  fix          Auto-fix runtime issues (start services, fix config)
  start        Start services
  stop         Stop services
  restart      Restart services
  startup      Manage autostart (systemd): install|enable|disable|uninstall
  uninstall    Remove tools (requires -a)
  help         Show this help

Options:
  -a, --app APP     Target app: opencode, openchamber, paseo, all (default: all)
  -f, --force       Skip confirmation prompts
  -q, --quiet       Suppress non-essential output
  -h, --help        Show this help

Examples:
  ./dev-stack.sh                          # Check status
  ./dev-stack.sh install                  # Install/update all
  ./dev-stack.sh install -a paseo         # Install/update Paseo only
  ./dev-stack.sh start                    # Start all services
  ./dev-stack.sh stop -a openchamber      # Stop OpenChamber only
  ./dev-stack.sh startup install -a paseo # Install Paseo systemd service

OpenChamber will not bind to 0.0.0.0 (LAN-reachable) without a UI password.
Set one before starting it:
  export OPENCHAMBER_UI_PASSWORD="yourpassword"
  echo 'export OPENCHAMBER_UI_PASSWORD="yourpassword"' >> ~/.bashrc
EOF
    exit 0
}

# --- Defaults ---
COMMAND="status"
APP="all"
FORCE=false
QUIET=false
DRY_RUN=false
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# --- Parse args ---
while [[ $# -gt 0 ]]; do
    case "$1" in
        status|install|update|fix|start|stop|restart|startup|uninstall|help)
            COMMAND="$1"; shift ;;
        -a|--app)
            APP="$2"; shift 2 ;;
        -f|--force)
            FORCE=true; shift ;;
        -q|--quiet)
            QUIET=true; shift ;;
        -h|--help)
            show_help ;;
        *)
            echo_err "Unknown argument: $1"
            show_help
            ;;
    esac
done

# --- Main ---
case "$COMMAND" in
    status)
        collect_status
        write_status_report || true
        ;;
    install|update)
        do_install
        ;;
    fix)
        do_fix
        ;;
    start)
        apps=$(resolve_app_list "$APP")
        for app in $apps; do
            do_start_app "$app"
        done
        ;;
    stop)
        apps=$(resolve_app_list "$APP")
        for app in $apps; do
            do_stop_app "$app"
        done
        ;;
    restart)
        apps=$(resolve_app_list "$APP")
        for app in $apps; do
            do_stop_app "$app"
        done
        sleep 2
        for app in $apps; do
            do_start_app "$app"
        done
        ;;
    startup)
        shift  # consume 'startup'
        if [[ $# -eq 0 ]]; then
            echo_err "startup requires a subcommand: install, enable, disable, uninstall"
            exit 1
        fi
        do_startup "$1"
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

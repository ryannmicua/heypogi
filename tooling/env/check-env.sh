#!/usr/bin/env bash
#=======================================================================
# Script:    check-env.sh
# Purpose:   Validate heypogi env vars and report status.
# Usage:     ./tooling/env/check-env.sh [--json]
#
# Reads ~/.config/heypogi/{.env-common,.env-override,.env-secrets},
# resolves precedence, and validates against the required registry.
#
# Exit codes: 0 = all ok, 1 = missing vars, 2 = parse error
#=======================================================================
set -euo pipefail

# --- Config ---
CONFIG_DIR="$HOME/.config/heypogi"
ENV_COMMON="$CONFIG_DIR/.env-common"
ENV_OVERRIDE="$CONFIG_DIR/.env-override"
ENV_SECRETS="$CONFIG_DIR/.env-secrets"

JSON_OUTPUT=false
[[ "${1:-}" == "--json" ]] && JSON_OUTPUT=true

# --- Env var registry ---
# Format: VAR_NAME|REQUIRED|CONDITION|SECRET
REGISTRY=(
    "HEYPOGI_ROOT|always||false"
    "OPENCODE_CONFIG_DIR|always||false"
    "PATH|always||false"
    "PASEO_PASSWORD|when Paseo uses auth||true"
    "GH_PAT_COPILOT|when Copilot reviews used||true"
    "OPENCODE_SERVER_PASSWORD|when OpenCode server binds non-loopback||true"
    "OPENCHAMBER_UI_PASSWORD|when OpenChamber binds non-loopback||true"
)

# --- Resolve precedence: override > secrets > common ---
declare -A RESOLVED
declare -A SOURCES

resolve_var() {
    local var="$1"

    # Check override first
    if [[ -f "$ENV_OVERRIDE" ]] && grep -q "^${var}=" "$ENV_OVERRIDE" 2>/dev/null; then
        RESOLVED["$var"]="set"
        SOURCES["$var"]=".env-override"
        return
    fi

    # Check secrets
    if [[ -f "$ENV_SECRETS" ]] && grep -q "^${var}=" "$ENV_SECRETS" 2>/dev/null; then
        RESOLVED["$var"]="set"
        SOURCES["$var"]=".env-secrets"
        return
    fi

    # Check common
    if [[ -f "$ENV_COMMON" ]] && grep -q "^${var}=" "$ENV_COMMON" 2>/dev/null; then
        RESOLVED["$var"]="set"
        SOURCES["$var"]=".env-common"
        return
    fi

    # Not found in any file
    RESOLVED["$var"]="missing"
    SOURCES["$var"]=""
}

# --- Main ---
# Resolve each registry entry
for entry in "${REGISTRY[@]}"; do
    IFS='|' read -r var required condition secret <<< "$entry"
    resolve_var "$var"
done

# --- Output ---
if [[ "$JSON_OUTPUT" == true ]]; then
    echo "["
    first=true
    for entry in "${REGISTRY[@]}"; do
        IFS='|' read -r var required condition secret <<< "$entry"
        status="${RESOLVED[$var]}"
        source="${SOURCES[$var]}"

        [[ "$first" == true ]] && first=false || echo ","
        printf '  {"variable":"%s","status":"%s","source":"%s","condition":"%s"}' \
            "$var" "$status" "$source" "$condition"
    done
    echo ""
    echo "]"
else
    # Pretty table
    printf "%-30s %-10s %-15s %s\n" "VARIABLE" "STATUS" "SOURCE" "CONDITION"
    printf "%-30s %-10s %-15s %s\n" "--------" "------" "------" "---------"

    missing=0
    for entry in "${REGISTRY[@]}"; do
        IFS='|' read -r var required condition secret <<< "$entry"
        status="${RESOLVED[$var]}"
        source="${SOURCES[$var]}"

        if [[ "$status" == "missing" ]]; then
            printf "%-30s %-10s %-15s %s\n" "$var" "MISSING" "${source:-not set}" "$required"
            missing=$((missing+1))
        elif [[ "$secret" == "true" ]]; then
            printf "%-30s %-10s %-15s %s\n" "$var" "set" "$source" "$required"
        else
            printf "%-30s %-10s %-15s\n" "$var" "set" "$source"
        fi
    done

    echo ""
    if [[ $missing -eq 0 ]]; then
        echo "All required env vars are set."
    else
        echo "$missing env var(s) missing."
    fi
fi

# --- Exit code ---
if [[ "${#RESOLVED[@]}" -eq 0 ]]; then
    exit 2  # parse error - no vars loaded
fi

always_missing=0
for entry in "${REGISTRY[@]}"; do
    IFS='|' read -r var required condition secret <<< "$entry"
    if [[ "$required" == "always" ]] && [[ "${RESOLVED[$var]}" == "missing" ]]; then
        always_missing=$((always_missing+1))
    fi
done

[[ $always_missing -gt 0 ]] && exit 1
exit 0

#!/usr/bin/env bash
#=======================================================================
# Script:    setup-env.sh
# Purpose:   Generate heypogi env files and update .bashrc idempotently.
# Usage:     ./tooling/env/setup-env.sh
#
# Creates:
#   ~/.config/heypogi/.env-common   (generated from template, chmod 644)
#   ~/.config/heypogi/.env-override  (empty, chmod 640, user-maintained)
#   ~/.config/heypogi/.env-secrets   (from template, chmod 600)
#
# Updates ~/.bashrc with a marker-bounded source block.
#=======================================================================
set -euo pipefail

# --- Locate repo root from this script's position ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# --- Paths ---
CONFIG_DIR="$HOME/.config/heypogi"
ENV_COMMON="$CONFIG_DIR/.env-common"
ENV_OVERRIDE="$CONFIG_DIR/.env-override"
ENV_SECRETS="$CONFIG_DIR/.env-secrets"
TEMPLATE_COMMON="$SCRIPT_DIR/env-common.template"
TEMPLATE_SECRETS="$SCRIPT_DIR/env-secrets.template"

# --- Marker block for .bashrc ---
MARKER_START="# >>> heypogi env >>>"
MARKER_END="# <<< heypogi <<<"

echo "Setting up heypogi environment..."
echo "  Repo root: $REPO_ROOT"
echo "  Config dir: $CONFIG_DIR"

# --- Create config directory ---
mkdir -p "$CONFIG_DIR"

# --- Render .env-common from template ---
echo ""
echo "Rendering .env-common from template..."
TEMP_COMMON=$(mktemp)
trap 'rm -f "$TEMP_COMMON"' EXIT

sed "s|__REPO_ROOT__|$REPO_ROOT|g" "$TEMPLATE_COMMON" > "$TEMP_COMMON"

if [[ -f "$ENV_COMMON" ]]; then
    if cmp -s "$TEMP_COMMON" "$ENV_COMMON"; then
        echo "  .env-common: unchanged, skipping"
    else
        mv "$TEMP_COMMON" "$ENV_COMMON"
        echo "  .env-common: updated"
    fi
else
    mv "$TEMP_COMMON" "$ENV_COMMON"
    echo "  .env-common: created"
fi
chmod 644 "$ENV_COMMON"

# --- Create .env-override if missing ---
if [[ ! -f "$ENV_OVERRIDE" ]]; then
    touch "$ENV_OVERRIDE"
    echo "  .env-override: created (empty)"
else
    echo "  .env-override: exists, skipping"
fi
chmod 640 "$ENV_OVERRIDE"

# --- Create .env-secrets from template if missing ---
if [[ ! -f "$ENV_SECRETS" ]]; then
    cp "$TEMPLATE_SECRETS" "$ENV_SECRETS"
    echo "  .env-secrets: created from template"
else
    echo "  .env-secrets: exists, skipping"
fi
chmod 600 "$ENV_SECRETS"

# --- Idempotent .bashrc update ---
echo ""
echo "Updating .bashrc..."

BASHRC="$HOME/.bashrc"
SOURCE_BLOCK="$MARKER_START
set -a
. \"\$HOME/.config/heypogi/.env-common\"
. \"\$HOME/.config/heypogi/.env-override\"
. \"\$HOME/.config/heypogi/.env-secrets\"
set +a
$MARKER_END"

if [[ ! -f "$BASHRC" ]]; then
    echo "$SOURCE_BLOCK" > "$BASHRC"
    echo "  .bashrc: created with source block"
elif grep -qF "$MARKER_START" "$BASHRC" && grep -qF "$MARKER_END" "$BASHRC"; then
    # Both markers present - check if content differs
    EXISTING=$(sed -n "/$MARKER_START/,/$MARKER_END/p" "$BASHRC")
    if [[ "$EXISTING" == "$SOURCE_BLOCK" ]]; then
        echo "  .bashrc: source block unchanged, skipping"
    else
        # Replace existing block (safe: both markers confirmed present)
        TEMP_BASHRC=$(mktemp)
        awk -v start="$MARKER_START" -v end="$MARKER_END" -v block="$SOURCE_BLOCK" '
            $0 == start { print block; skip=1; next }
            skip && $0 == end { skip=0; next }
            !skip { print }
        ' "$BASHRC" > "$TEMP_BASHRC"
        mv "$TEMP_BASHRC" "$BASHRC"
        echo "  .bashrc: source block updated"
    fi
else
    echo "" >> "$BASHRC"
    echo "$SOURCE_BLOCK" >> "$BASHRC"
    echo "  .bashrc: source block appended"
fi

echo ""
echo "Done. Environment files:"
echo "  $ENV_COMMON (644)"
echo "  $ENV_OVERRIDE (640)"
echo "  $ENV_SECRETS (600)"
echo ""
echo "Reload your shell or run: source ~/.bashrc"

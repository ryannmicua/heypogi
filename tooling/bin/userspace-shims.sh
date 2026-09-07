#!/usr/bin/env bash
#=======================================================================
# Script:    userspace-shims.sh
# Purpose:   Re-point ~/.local/bin shims at the current nvm default Node
#            and its globally installed CLIs. Run after `nvm install`
#            / `nvm alias default` / `npm install -g` so the stable
#            userspace PATH keeps working with no root required.
# Usage:     ./tooling/bin/userspace-shims.sh
#=======================================================================
set -euo pipefail

NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
TARGET_DIR="$HOME/.local/bin"

# Resolve the nvm default version's bin dir without depending on nvm.sh.
DEFAULT_ALIAS_FILE="$NVM_DIR/alias/default"
if [[ -f "$DEFAULT_ALIAS_FILE" ]]; then
    DEFAULT_VER="$(cat "$DEFAULT_ALIAS_FILE")"
else
    echo "ERROR: no nvm default alias set. Run: nvm alias default <version>" >&2
    exit 1
fi

# The alias file may contain a version number or another alias (e.g. lts/*);
# resolve via nvm if available, else assume v-prefixed dir.
if [[ "$DEFAULT_VER" == v* && -d "$NVM_DIR/versions/node/$DEFAULT_VER" ]]; then
    NVM_BIN="$NVM_DIR/versions/node/$DEFAULT_VER/bin"
else
    export NVM_DIR
    # shellcheck disable=SC1091
    . "$NVM_DIR/nvm.sh" --no-use >/dev/null 2>&1
    RESOLVED="$(nvm_version "$DEFAULT_VER")"
    NVM_BIN="$NVM_DIR/versions/node/$RESOLVED/bin"
fi

if [[ ! -x "$NVM_BIN/node" ]]; then
    echo "ERROR: node not found at $NVM_BIN/node" >&2
    exit 1
fi

mkdir -p "$TARGET_DIR"

linked=0
skipped=0
for src in "$NVM_BIN"/*; do
    name="$(basename "$src")"
    dest="$TARGET_DIR/$name"
    if [[ -e "$dest" && ! -L "$dest" ]]; then
        echo "SKIP  $name (real file exists in ~/.local/bin, not a shim)"
        skipped=$((skipped+1))
        continue
    fi
    ln -sf "$src" "$dest"
    linked=$((linked+1))
done

echo ""
echo "Shims in $TARGET_DIR now point at $NVM_BIN"
echo "  linked: $linked, skipped (real files): $skipped"
echo "  node: $("$TARGET_DIR/node" --version 2>/dev/null || echo MISSING)"
echo "  npm prefix: $(npm config get prefix 2>/dev/null)"

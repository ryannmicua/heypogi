#!/usr/bin/env bash
#=======================================================================
# Script:    symlink-nvm-node-bin.sh
# Purpose:   Point ~/.local/node-bin at the current nvm default Node's
#            bin dir. ~/.local/node-bin is on PATH (see
#            tooling/env/env-common.template), so node, npm, and all
#            globally installed CLIs resolve without per-binary shims.
#            Run after `nvm install` / `nvm alias default`.
# Usage:     ./tooling/bin/symlink-nvm-node-bin.sh
#=======================================================================
set -euo pipefail

NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
LINK="$HOME/.local/node-bin"

# Resolve the nvm default version's bin dir without depending on nvm.sh.
DEFAULT_ALIAS_FILE="$NVM_DIR/alias/default"
if [[ -f "$DEFAULT_ALIAS_FILE" ]]; then
    DEFAULT_VER="$(cat "$DEFAULT_ALIAS_FILE")"
else
    echo "ERROR: no nvm default alias set. Run: nvm alias default <version>" >&2
    exit 1
fi

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

# Repoint the single link (no trailing slash on the link name, or ln
# would create the link *inside* the target dir instead of replacing it).
ln -sfn "$NVM_BIN" "$LINK"

# Put the link on PATH before probing: npm derives its default prefix from
# the node binary that executes it, so the checks below must run under the
# just-pointed node, not whatever node the caller happens to have.
export PATH="$LINK:$PATH"

echo ""
echo "~/.local/node-bin now points at $NVM_BIN"
echo "  node: $($LINK/node --version 2>/dev/null || echo MISSING)"
echo "  npm prefix: $($LINK/npm config get prefix 2>/dev/null)"
echo "  exposed tools: $(ls "$LINK" | tr '\n' ' ')"

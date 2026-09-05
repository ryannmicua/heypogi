#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="/home/rgm/repo/heypogi"
LOG_FILE="$REPO_DIR/external/.update-cron.log"
mkdir -p "$(dirname "$LOG_FILE")"

log() { echo "$(date -u '+%Y-%m-%d %H:%M:%S UTC') $*" >> "$LOG_FILE"; }

log "=== Starting external repo update ==="

FAILED=0

for script in clone-ce-source.sh clone-knowledge-source.sh clone-opencode-source.sh; do
  if bash "$REPO_DIR/tooling/sources/$script" --quiet 2>&1; then
    log "OK: $script"
  else
    log "FAIL: $script (exit $?)"
    FAILED=1
  fi
done

if [ "$FAILED" -eq 0 ]; then
  log "=== All repos updated successfully ==="
else
  log "=== Update completed with failures ==="
fi

log ""

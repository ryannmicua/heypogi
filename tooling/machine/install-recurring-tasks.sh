#!/usr/bin/env bash
# install-recurring-tasks.sh - Install all heypogi recurring tasks declared in the manifest
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
MANIFEST="$REPO_DIR/tooling/recurring-tasks.json"

if [ ! -f "$MANIFEST" ]; then
  echo "ERROR: manifest not found at $MANIFEST" >&2
  exit 1
fi

installed=0
skipped=0

install_cron() {
  local script="$1" schedule="$2" name="$3"
  local full_script="$REPO_DIR/$script"
  local cron_line="$schedule $full_script"

  # check if already installed
  if crontab -l 2>/dev/null | grep -qF "$full_script"; then
    echo "  SKIP  $name (already in crontab)"
    ((skipped++)) || true
    return
  fi

  (crontab -l 2>/dev/null; echo "$cron_line") | crontab -
  echo "  OK    $name -> crontab ($schedule)"
  ((installed++)) || true
}

echo "Installing heypogi recurring tasks..."
echo ""

task_count=$(python3 -c "
import json
with open('$MANIFEST') as f:
    print(len(json.load(f)['tasks']))
")

for i in $(seq 0 $((task_count - 1))); do
  eval "$(python3 -c "
import json
with open('$MANIFEST') as f:
    t = json.load(f)['tasks'][$i]
print(f\"TYPE=\\\"{t['type']}\\\"\")
print(f\"NAME=\\\"{t['name']}\\\"\")
print(f\"SCRIPT=\\\"{t['script']}\\\"\")
print(f\"SCHEDULE=\\\"{t.get('schedule', '')}\\\"\")
")"

  case "$TYPE" in
    cron)
      install_cron "$SCRIPT" "$SCHEDULE" "$NAME"
      ;;
    paseo)
      echo "  SKIP  $NAME (paseo schedules must be installed via paseo CLI)"
      ((skipped++)) || true
      ;;
    *)
      echo "  WARN  $NAME (unknown type: $TYPE)"
      ((skipped++)) || true
      ;;
  esac
done

echo ""
echo "Done: $installed installed, $skipped skipped"

#!/usr/bin/env bash
set -euo pipefail

max_age_days=7

usage() {
  cat <<'EOF'
Reports staleness of the external repo clones.

Usage:
  bash tooling/sources/get-external-repo-status.sh [--max-age-days <1-3650>]

Checks compound-engineering, compound-knowledge, and opencode against
external/.repo-update-status.json. Exits 1 if any is missing a record or
older than --max-age-days (default 7).
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --max-age-days)
      [[ $# -ge 2 ]] || { echo "--max-age-days requires a value." >&2; exit 1; }
      max_age_days="$2"; shift 2 ;;
    --max-age-days=*)
      max_age_days="${1#*=}"; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage; exit 2 ;;
  esac
done

if ! printf '%s' "${max_age_days}" | grep -Eq '^[0-9]+$' || [[ "${max_age_days}" -lt 1 || "${max_age_days}" -gt 3650 ]]; then
  echo "Invalid --max-age-days '${max_age_days}' - must be between 1 and 3650." >&2
  echo "" >&2
  usage
  exit 1
fi

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
repo_root="$(cd "${script_dir}/../.." && pwd -P)"
status_path="${repo_root}/external/.repo-update-status.json"
repositories="compound-engineering
compound-knowledge
opencode"

if [[ ! -f "${status_path}" ]]; then
  echo "No external-repository update record exists. Run the update scripts before relying on this status."
  exit 1
fi

# Reads status JSON on stdin, emits one TSV line per top-level entry:
#   name \t lastUpdatedAtUtc \t branch \t commit \t remote
parse_entries() {
  awk '
    BEGIN { depth = 0; cur = ""; n = 0 }
    {
      raw = $0
      line = $0
      opens = gsub(/\{/, "", line)
      closes = gsub(/\}/, "", line)

      if (depth == 1 && cur == "" && raw ~ /^[[:space:]]*"[^"]+"[[:space:]]*:[[:space:]]*\{[[:space:]]*$/) {
        key = raw
        sub(/^[[:space:]]*"/, "", key)
        sub(/".*$/, "", key)
        order[++n] = key
        cur = key
        fields[cur "|lastUpdatedAtUtc"] = ""
        fields[cur "|commit"] = ""
      } else if (depth == 2 && cur != "" && raw ~ /^[[:space:]]*"lastUpdatedAtUtc"[[:space:]]*:[[:space:]]*"[^"]*"/) {
        v = raw
        sub(/^[[:space:]]*"lastUpdatedAtUtc"[[:space:]]*:[[:space:]]*"/, "", v)
        sub(/"[[:space:]]*,?[[:space:]]*$/, "", v)
        fields[cur "|lastUpdatedAtUtc"] = v
      } else if (depth == 2 && cur != "" && raw ~ /^[[:space:]]*"commit"[[:space:]]*:[[:space:]]*"[^"]*"/) {
        v = raw
        sub(/^[[:space:]]*"commit"[[:space:]]*:[[:space:]]*"/, "", v)
        sub(/"[[:space:]]*,?[[:space:]]*$/, "", v)
        fields[cur "|commit"] = v
      } else if (depth == 2 && cur != "" && raw ~ /^[[:space:]]*\}[[:space:]]*,?[[:space:]]*$/) {
        cur = ""
      }

      depth += opens - closes
    }
    END {
      for (i = 1; i <= n; i++) {
        key = order[i]
        printf "%s\t%s\t%s\n", key, fields[key "|lastUpdatedAtUtc"], fields[key "|commit"]
      }
    }
  '
}

records=""
if [[ "$(head -c 3 "${status_path}" | od -An -tx1 | tr -d ' \n')" == "efbbbf" ]]; then
  records="$(tail -c +4 "${status_path}" | parse_entries)"
else
  records="$(parse_entries <"${status_path}")"
fi

# Cross-platform ISO-8601 UTC to epoch seconds (GNU date first, BSD fallback).
to_epoch() {
  ts="$(printf '%s' "$1" | sed -E 's/\.[0-9]+//')"
  epoch=""
  epoch="$(date -u -d "${ts}" +%s 2>/dev/null || true)"
  if [[ -z "${epoch}" ]]; then
    epoch="$(date -j -u -f '%Y-%m-%dT%H:%M:%SZ' "${ts}" +%s 2>/dev/null || true)"
  fi
  printf '%s' "${epoch}"
}

now_epoch="$(date -u +%s)"
check_due=0

while IFS= read -r repo; do
  rec="$(printf '%s\n' "${records}" | awk -F'\t' -v r="${repo}" '$1 == r')"
  if [[ -z "${rec}" ]]; then
    printf 'CHECK DUE  %s (no update record)\n' "${repo}"
    check_due=1
    continue
  fi

  updated_at="$(printf '%s' "${rec}" | cut -f2)"
  commit="$(printf '%s' "${rec}" | cut -f3)"

  epoch="$(to_epoch "${updated_at}")"
  if [[ -z "${epoch}" ]]; then
    printf 'CHECK DUE  %s (unreadable timestamp: %s)\n' "${repo}" "${updated_at}"
    check_due=1
    continue
  fi

  age_days=$(((now_epoch - epoch) / 86400))
  due=0
  if [[ ${age_days} -ge ${max_age_days} ]]; then
    due=1
  fi

  label="CURRENT"
  [[ ${due} -eq 1 ]] && label="CHECK DUE"
  date_str="$(printf '%s' "${updated_at}" | cut -c1-16 | tr 'T' ' ')"

  printf '%-10s %-22s updated %s UTC (%sd ago) %s\n' "${label}" "${repo}" "${date_str}" "${age_days}" "${commit:0:8}"
  if [[ ${due} -eq 1 ]]; then
    check_due=1
  fi
done <<<"${repositories}"

if [[ ${check_due} -eq 1 ]]; then
  exit 1
fi
exit 0

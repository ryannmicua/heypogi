#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Records an external repo's branch/commit/remote in external/.repo-update-status.json.

Usage:
  bash tooling/sources/record-external-repo-update.sh --name <name> --repository-path <path>

Options:
  --name             Key to record under (e.g. opencode). Required.
  --repository-path  Path to the local git clone. Required.
EOF
}

name=""
repository_path=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --name)
      [[ $# -ge 2 ]] || { echo "--name requires a value." >&2; exit 1; }
      name="$2"; shift 2 ;;
    --repository-path)
      [[ $# -ge 2 ]] || { echo "--repository-path requires a value." >&2; exit 1; }
      repository_path="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage; exit 2 ;;
  esac
done

if [[ -z "${name}" || -z "${repository_path}" ]]; then
  echo "Both --name and --repository-path are required." >&2
  echo "" >&2
  usage
  exit 1
fi

if ! printf '%s' "${name}" | grep -Eq '^[A-Za-z0-9._-]+$'; then
  echo "Invalid --name '${name}' - use letters, digits, dots, dashes, underscores only." >&2
  exit 1
fi

if [[ ! -d "${repository_path}/.git" ]]; then
  echo "Could not collect update status for ${name}: not a git repository: ${repository_path}" >&2
  exit 1
fi

branch="$(git -C "${repository_path}" branch --show-current 2>/dev/null || true)"
commit="$(git -C "${repository_path}" rev-parse HEAD 2>/dev/null || true)"
remote="$(git -C "${repository_path}" remote get-url origin 2>/dev/null || true)"

if [[ -z "${branch}" || -z "${commit}" || -z "${remote}" ]]; then
  echo "Could not collect update status for ${name}." >&2
  exit 1
fi

updated_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

external_dir="$(cd "${repository_path}" && cd .. && pwd -P)"
status_path="${external_dir}/.repo-update-status.json"

# Reads status JSON on stdin, emits one TSV line per top-level entry:
#   name \t lastUpdatedAtUtc \t branch \t commit \t remote
# Tolerates 2- or 4-space indentation and Windows-style formatting.
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
        fields[cur "|branch"] = ""
        fields[cur "|commit"] = ""
        fields[cur "|remote"] = ""
      } else if (depth == 2 && cur != "" && raw ~ /^[[:space:]]*"[^"]+"[[:space:]]*:[[:space:]]*"[^"]*"[[:space:]]*,?[[:space:]]*$/) {
        pair = raw
        k = pair
        sub(/^[[:space:]]*"/, "", k)
        sub(/".*$/, "", k)
        v = pair
        sub(/^[[:space:]]*"[^"]+"[[:space:]]*:[[:space:]]*"/, "", v)
        sub(/"[[:space:]]*,?[[:space:]]*$/, "", v)
        fields[cur "|" k] = v
      } else if (depth == 2 && cur != "" && raw ~ /^[[:space:]]*\}[[:space:]]*,?[[:space:]]*$/) {
        cur = ""
      }

      depth += opens - closes
    }
    END {
      for (i = 1; i <= n; i++) {
        key = order[i]
        printf "%s\t%s\t%s\t%s\t%s\n", key, fields[key "|lastUpdatedAtUtc"], fields[key "|branch"], fields[key "|commit"], fields[key "|remote"]
      }
    }
  '
}

emit_entry() {
  IFS="$(printf '\t')" read -r ename ets ebr ecm erem <<<"$1"
  printf '  "%s": {\n' "${ename}"
  printf '    "lastUpdatedAtUtc": "%s",\n' "${ets}"
  printf '    "branch": "%s",\n' "${ebr}"
  printf '    "commit": "%s",\n' "${ecm}"
  printf '    "remote": "%s"\n' "${erem}"
  printf '  }'
}

records=""
if [[ -f "${status_path}" ]]; then
  # Strip a UTF-8 BOM if the file was written by Windows PowerShell.
  if [[ "$(head -c 3 "${status_path}" | od -An -tx1 | tr -d ' \n')" == "efbbbf" ]]; then
    records="$(tail -c +4 "${status_path}" | parse_entries)"
  else
    records="$(parse_entries <"${status_path}")"
  fi
fi

new_record="${name}"$'\t'"${updated_at}"$'\t'"${branch}"$'\t'"${commit}"$'\t'"${remote}"

tmp_status="$(mktemp)"
trap 'rm -f "${tmp_status}"' EXIT

wrote_target=0
body=""
separator=""

append_entry() {
  local entry
  entry="$(emit_entry "$1")"
  body="${body}${separator}${entry}"
  separator=$',\n'
}

while IFS= read -r rec; do
  [[ -z "${rec}" ]] && continue
  rname="$(printf '%s' "${rec}" | cut -f1)"
  if [[ "${rname}" == "${name}" ]]; then
    rec="${new_record}"
    wrote_target=1
  fi
  append_entry "${rec}"
done <<<"${records}"
if [[ ${wrote_target} -eq 0 ]]; then
  append_entry "${new_record}"
fi

{
  printf '{\n%s\n}\n' "${body}"
} >"${tmp_status}"

mv "${tmp_status}" "${status_path}"

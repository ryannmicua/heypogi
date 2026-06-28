#!/usr/bin/env bash
set -euo pipefail

create_dest=0

usage() {
  cat <<'EOF'
Install Compound Knowledge plugin skills by linking the repo's plugin skills folder into ~/.agents/skills/compound-knowledge.

Usage:
  bash install/scripts/install-knowledge-skills.sh [--create-dest]

Options:
  --create-dest  Create ~/.agents/skills if missing (only after user approval)
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --create-dest) create_dest=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage; exit 2 ;;
  esac
done

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
repo_root="$(cd "${script_dir}/../.." && pwd -P)"
skills_root="$(cd "${repo_root}/external/compound-knowledge/plugins/compound-knowledge/skills" && pwd -P)"
dest_dir="${HOME}/.agents/skills"
dest_path="${dest_dir}/compound-knowledge"

if [[ ! -d "${skills_root}" ]]; then
  echo "Could not find CK plugin skills folder at: ${skills_root}" >&2
  exit 1
fi

if [[ ! -d "${dest_dir}" ]]; then
  if [[ "${create_dest}" -ne 1 ]]; then
    echo "Destination folder does not exist: ${dest_dir}" >&2
    echo "Re-run with --create-dest only after user approval to create it." >&2
    exit 1
  fi
  mkdir -p "${dest_dir}"
fi

prompt_overwrite() {
  local dest="$1"
  local context="$2"
  local expected="$3"
  local current="$4"

  while true; do
    printf "Blocker: %s already exists.\n" "${dest}" 1>&2
    printf "Existing kind: %s\n" "${context}" 1>&2
    if [[ -n "${current}" ]]; then
      printf "Existing target: %s\n" "${current}" 1>&2
    fi
    printf "Expected target: %s\n" "${expected}" 1>&2
    printf "Choose: [o]verwrite, [s]kip, [q]uit? " 1>&2
    IFS= read -r ans </dev/tty || ans=""
    ans="$(printf "%s" "${ans}" | tr '[:upper:]' '[:lower:]' | xargs || true)"
    case "${ans}" in
      o) return 0 ;;
      s) return 1 ;;
      q) echo "Aborted by user." >&2; exit 1 ;;
      *) echo "Invalid choice." >&2 ;;
    esac
  done
}

if [[ -e "${dest_path}" || -L "${dest_path}" ]]; then
  expected_target="${skills_root}"
  current_target=""
  if [[ -L "${dest_path}" ]]; then
    current_target="$(readlink "${dest_path}" || true)"
    context="link"
  else
    context="path"
  fi

  if ! prompt_overwrite "${dest_path}" "${context}" "${expected_target}" "${current_target}"; then
    echo ""
    echo "Done."
    echo "Installed: 0"
    echo "Skipped:   1"
    exit 0
  fi

  if [[ -L "${dest_path}" ]]; then
    rm -f "${dest_path}"
  else
    rm -rf "${dest_path}"
  fi
fi

ln -s "${skills_root}" "${dest_path}"
echo "LINK: ${dest_path} -> ${skills_root}"
echo ""
echo "Done."
echo "Installed: 1"
echo "Skipped:   0"

#!/usr/bin/env bash
set -euo pipefail

create_dest=0
force=0
force_all=0

usage() {
  cat <<'EOF'
Install this repo's skills into ~/.agents/skills by symlink-linking each first-level directory
under src/skills that contains a valid SKILL.md (YAML frontmatter with name and description).

Usage:
  bash src/skills/heypogi-install-skills/scripts/install_skills.sh [--create-dest] [--force]

Options:
  --create-dest  Create ~/.agents/skills if missing (only after user approval)
  --force        Replace existing entries at destination
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --create-dest) create_dest=1; shift ;;
    --force) force=1; force_all=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage; exit 2 ;;
  esac
done

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
repo_root="$(cd "${script_dir}/../../../../" && pwd -P)"
skills_root="${repo_root}/src/skills"
dest_root="${HOME}/.agents/skills"

if [[ ! -d "${skills_root}" ]]; then
  echo "Could not find repo skills folder at: ${skills_root}" >&2
  exit 1
fi

if [[ ! -d "${dest_root}" ]]; then
  if [[ "${create_dest}" -ne 1 ]]; then
    echo "Destination folder does not exist: ${dest_root}" >&2
    echo "Re-run with --create-dest only after user approval to create it." >&2
    exit 1
  fi
  mkdir -p "${dest_root}"
fi

is_valid_skill_md() {
  local skill_md="$1"
  [[ -f "${skill_md}" ]] || return 1

  # Read only the first chunk for a cheap validation.
  local head
  head="$(head -n 80 "${skill_md}" || true)"
  [[ "${head}" == ---$'\n'* ]] || return 1

  local fm
  fm="$(printf "%s\n" "${head}" | awk '
    NR==1 { if ($0!="---") exit 1 }
    NR>1 {
      if ($0=="---") exit 0
      print
    }
    END { exit 1 }
  ')" || return 1

  printf "%s\n" "${fm}" | grep -Eq '^[[:space:]]*name[[:space:]]*:[[:space:]]*[^[:space:]]' || return 1
  printf "%s\n" "${fm}" | grep -Eq '^[[:space:]]*description[[:space:]]*:[[:space:]]*[^[:space:]]' || return 1
  return 0
}

installed=0
skipped=0
warnings=0

prompt_overwrite() {
  local dest_path="$1"
  local context="$2"

  while true; do
    printf "Exists (%s): %s. [o]verwrite, [s]kip, overwrite [a]ll, [q]uit? " "${context}" "${dest_path}" 1>&2
    IFS= read -r ans </dev/tty || ans=""
    ans="$(printf "%s" "${ans}" | tr '[:upper:]' '[:lower:]' | xargs || true)"
    case "${ans}" in
      o) return 0 ;;
      s) return 1 ;;
      a) force_all=1; return 0 ;;
      q) echo "Aborted by user." >&2; exit 1 ;;
      *) echo "Invalid choice." >&2 ;;
    esac
  done
}

for skill_dir in "${skills_root}"/*; do
  [[ -d "${skill_dir}" ]] || continue
  skill_md="${skill_dir}/SKILL.md"
  if ! is_valid_skill_md "${skill_md}"; then
    continue
  fi

  skill_name="$(basename "${skill_dir}")"
  dest_path="${dest_root}/${skill_name}"
  expected_target="$(cd "${skill_dir}" && pwd -P)"

  if [[ -e "${dest_path}" || -L "${dest_path}" ]]; then
    if [[ -L "${dest_path}" ]]; then
      current_target="$(readlink "${dest_path}" || true)"
      if [[ "${current_target}" == "${expected_target}" ]]; then
        echo "OK: ${dest_path} -> ${current_target}"
        skipped=$((skipped + 1))
        continue
      fi

      if [[ "${force_all}" -ne 1 ]]; then
        if ! prompt_overwrite "${dest_path}" "symlink"; then
          skipped=$((skipped + 1))
          continue
        fi
      fi

      rm -f "${dest_path}"
    else
      if [[ "${force_all}" -ne 1 ]]; then
        if ! prompt_overwrite "${dest_path}" "not a symlink"; then
          skipped=$((skipped + 1))
          continue
        fi
      fi
      rm -rf "${dest_path}"
    fi
  fi

  ln -s "${expected_target}" "${dest_path}"
  echo "LINK: ${dest_path} -> ${expected_target}"
  installed=$((installed + 1))
done

echo ""
echo "Done."
echo "Installed: ${installed}"
echo "Skipped:   ${skipped}"
echo "Warnings:  ${warnings}"

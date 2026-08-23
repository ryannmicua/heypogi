#!/usr/bin/env bash
set -euo pipefail

quiet=0

usage() {
  cat <<'EOF'
Clones the OpenCode source repository into external/opencode/.

Usage:
  bash tooling/sources/clone-opencode-source.sh [--quiet]

Options:
  --quiet  Pull without prompting; ensure the repo is present
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --quiet) quiet=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage; exit 2 ;;
  esac
done

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
repo_root="$(cd "${script_dir}/../.." && pwd -P)"
external_dir="${repo_root}/external"
target_dir="${external_dir}/opencode"
clone_url="https://github.com/anomalyco/opencode.git"
status_recorder="${script_dir}/record-external-repo-update.sh"

if [[ ! -d "${external_dir}" ]]; then
  mkdir -p "${external_dir}"
fi

did_update=0
if [[ -d "${target_dir}" ]]; then
  if [[ ! -d "${target_dir}/.git" ]]; then
    echo "${target_dir} exists but is not a git repository. Remove it manually and re-run." >&2
    exit 1
  fi
  pull=0
  if [[ "${quiet}" -eq 1 ]]; then
    pull=1
  else
    printf "OpenCode source already cloned at: %s\n" "${target_dir}"
    printf "Pull latest? [y/N] "
    IFS= read -r answer </dev/tty || answer=""
    answer="$(printf "%s" "${answer}" | tr '[:upper:]' '[:lower:]' | xargs || true)"
    if [[ "${answer}" == "y" ]]; then
      pull=1
    fi
  fi
  if [[ "${pull}" -eq 1 ]]; then
    printf "Pulling latest...\n"
    git -C "${target_dir}" pull
    did_update=1
  fi
else
  printf "Cloning opencode source into %s ...\n" "${target_dir}"
  git clone "${clone_url}" "${target_dir}"
  did_update=1
fi

if [[ "${did_update}" -eq 1 ]]; then
  bash "${status_recorder}" --name opencode --repository-path "${target_dir}"
fi

if [[ "${quiet}" -ne 1 ]]; then
  printf "\n"
  printf "OpenCode source: %s\n" "${target_dir}"
  printf "  Branch: "
  git -C "${target_dir}" branch --show-current
  printf "  Remote: "
  git -C "${target_dir}" remote get-url origin
  printf "\nVerify with:\n"
  printf "  ls %s\n" "${target_dir}"
  printf "  git -C %s log --oneline -3\n" "${target_dir}"
fi

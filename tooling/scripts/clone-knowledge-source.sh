#!/usr/bin/env bash
set -euo pipefail

quiet=0

usage() {
  cat <<'EOF'
Clones the Compound Knowledge source repository into external/compound-knowledge/.

Usage:
  bash tooling/scripts/clone-knowledge-source.sh [--quiet]

Options:
  --quiet  Suppress prompts and just ensure the repo is present
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
target_dir="${external_dir}/compound-knowledge"
clone_url="https://github.com/EveryInc/compound-knowledge-plugin.git"

if [[ ! -d "${external_dir}" ]]; then
  mkdir -p "${external_dir}"
fi

if [[ -d "${target_dir}" ]]; then
  if [[ ! -d "${target_dir}/.git" ]]; then
    echo "${target_dir} exists but is not a git repository. Remove it manually and re-run." >&2
    exit 1
  fi
  if [[ "${quiet}" -ne 1 ]]; then
    printf "Compound Knowledge source already cloned at: %s\n" "${target_dir}"
    printf "Pull latest? [y/N] "
    IFS= read -r answer </dev/tty || answer=""
    answer="$(printf "%s" "${answer}" | tr '[:upper:]' '[:lower:]' | xargs || true)"
    if [[ "${answer}" == "y" ]]; then
      printf "Pulling latest...\n"
      git -C "${target_dir}" pull
    fi
  fi
else
  printf "Cloning compound-knowledge source into %s ...\n" "${target_dir}"
  git clone --depth 1 "${clone_url}" "${target_dir}"
fi

if [[ "${quiet}" -ne 1 ]]; then
  printf "\n"
  printf "Compound Knowledge source: %s\n" "${target_dir}"
  printf "  Branch: "
  git -C "${target_dir}" branch --show-current
  printf "  Remote: "
  git -C "${target_dir}" remote get-url origin
  printf "\nVerify with:\n"
  printf "  ls %s\n" "${target_dir}"
  printf "  git -C %s log --oneline -3\n" "${target_dir}"
fi

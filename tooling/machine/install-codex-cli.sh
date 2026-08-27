#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Install and verify OpenAI Codex CLI on macOS, Linux, or WSL2.

Usage:
  bash tooling/machine/install-codex-cli.sh status
  bash tooling/machine/install-codex-cli.sh install

Commands:
  status   Check Codex CLI and Linux sandbox prerequisites without changing the system.
  install  Install Linux sandbox prerequisites, install/update Codex CLI, and verify both.
EOF
}

mode="${1:-status}"
case "${mode}" in
  status|install) ;;
  -h|--help) usage; exit 0 ;;
  *) echo "Unknown command: ${mode}" >&2; usage; exit 2 ;;
esac

platform="$(uname -s)"
os_id=""
os_version=""
if [[ "${platform}" == "Linux" && -r /etc/os-release ]]; then
  # shellcheck disable=SC1091
  . /etc/os-release
  os_id="${ID:-}"
  os_version="${VERSION_ID:-}"
fi

bwrap_smoke_test() {
  local -a command=(
    bwrap
    --ro-bind / /
    --dev /dev
    --proc /proc
    --unshare-user
    --unshare-pid
    --
    /bin/true
  )

  if command -v timeout >/dev/null 2>&1; then
    timeout 10 "${command[@]}"
  else
    "${command[@]}"
  fi
}

show_status() {
  local failed=0

  if command -v codex >/dev/null 2>&1; then
    printf 'Codex CLI:  %s (%s)\n' "$(codex --version)" "$(command -v codex)"
  else
    echo "Codex CLI:  missing"
    failed=1
  fi

  if [[ "${platform}" == "Linux" ]]; then
    if command -v bwrap >/dev/null 2>&1; then
      printf 'Bubblewrap: %s (%s)\n' "$(bwrap --version)" "$(command -v bwrap)"
      if bwrap_smoke_test >/dev/null 2>&1; then
        echo "Sandbox:    ready"
      else
        echo "Sandbox:    bubblewrap cannot create the required user namespace"
        failed=1
      fi
    else
      echo "Bubblewrap: missing"
      echo "Sandbox:    not ready"
      failed=1
    fi
  else
    echo "Sandbox:    uses the macOS built-in Seatbelt framework"
  fi

  return "${failed}"
}

install_bubblewrap() {
  if command -v bwrap >/dev/null 2>&1; then
    echo "Bubblewrap is already installed: $(bwrap --version)"
    return
  fi

  case "${os_id}" in
    ubuntu|debian)
      sudo apt-get update
      sudo apt-get install -y bubblewrap
      ;;
    fedora)
      sudo dnf install -y bubblewrap
      ;;
    *)
      echo "Unsupported Linux distribution: ${os_id:-unknown}." >&2
      echo "Install the package that provides 'bwrap', then rerun this installer." >&2
      exit 1
      ;;
  esac
}

repair_ubuntu_2404_apparmor() {
  if [[ "${os_id}" != "ubuntu" || "${os_version}" != "24.04" ]]; then
    return 1
  fi

  echo "Bubblewrap user namespaces are blocked; loading Ubuntu 24.04's AppArmor profile."
  sudo apt-get update
  sudo apt-get install -y apparmor-profiles apparmor-utils

  local source_profile="/usr/share/apparmor/extra-profiles/bwrap-userns-restrict"
  local target_profile="/etc/apparmor.d/bwrap-userns-restrict"
  if [[ ! -f "${source_profile}" ]]; then
    echo "Expected AppArmor profile is unavailable: ${source_profile}" >&2
    return 1
  fi

  sudo install -m 0644 "${source_profile}" "${target_profile}"
  sudo apparmor_parser -r "${target_profile}"
}

install_codex() {
  if ! command -v curl >/dev/null 2>&1; then
    echo "curl is required by the official Codex installer." >&2
    exit 1
  fi

  echo "Running the official OpenAI Codex installer."
  curl -fsSL https://chatgpt.com/codex/install.sh | sh
  hash -r
}

if [[ "${mode}" == "status" ]]; then
  show_status
  exit $?
fi

case "${platform}" in
  Darwin) ;;
  Linux)
    install_bubblewrap
    if ! bwrap_smoke_test; then
      if ! repair_ubuntu_2404_apparmor || ! bwrap_smoke_test; then
        echo "Bubblewrap is installed but its user-namespace smoke test still fails." >&2
        echo "Do not disable AppArmor's restriction globally without reviewing the security tradeoff." >&2
        exit 1
      fi
    fi
    ;;
  *)
    echo "Unsupported platform: ${platform}. Use the official Windows installation instructions." >&2
    exit 1
    ;;
esac

install_codex

if ! command -v codex >/dev/null 2>&1; then
  echo "Codex installed, but 'codex' is not yet on PATH. Open a new terminal and run this script with 'status'." >&2
  exit 1
fi

show_status
echo
echo "Installation verified. Run 'codex' in a project directory to sign in."

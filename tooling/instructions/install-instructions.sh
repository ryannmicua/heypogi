#!/usr/bin/env bash
set -euo pipefail

# Global Instructions Manager — install RULES.md to each AI coding agent
# Usage: bash tooling/instructions/install-instructions.sh [options]

VERSION="1.0.0"

# ── Resolve paths ────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd -P)"

# ── Defaults ─────────────────────────────────────────────────────────────────
SOURCE="${REPO_ROOT}/dotfiles/instructions/RULES.md"
MODE="interactive"
DRY_RUN=0
REMOVE=0
JSON_OUTPUT=0
CREATE_DEST=0
FORCE_CODEX=0
FORCE_CLAUDE=0
FORCE_AGY=0
FORCE_OPENCODE=0
FORCE_REMOVE=0

# ── Color helpers (R30) ─────────────────────────────────────────────────────
RED="" GREEN="" YELLOW="" CYAN="" BOLD="" RESET=""
if [[ -t 1 ]] && [[ -z "${NO_COLOR:-}" ]]; then
  RED='\033[0;31m' GREEN='\033[0;32m' YELLOW='\033[0;33m'
  CYAN='\033[0;36m' BOLD='\033[1m' RESET='\033[0m'
fi

c() { printf "${1}%s${RESET}" "$2"; }

# ── Agent table ──────────────────────────────────────────────────────────────
# Format: name|binary|dest_path
AGENTS=(
  "codex|codex|${HOME}/.agents/AGENTS.md"
  "claude|claude|${HOME}/.claude/CLAUDE.md"
  "agy|agy|${HOME}/.gemini/GEMINI.md"
  "opencode|opencode|opencode-config"
)

# ── Usage ────────────────────────────────────────────────────────────────────
usage() {
  cat <<'EOF'
Install global instructions (RULES.md) to each AI coding agent's expected location.

Usage:
  bash tooling/instructions/install-instructions.sh [options]

Modes:
  (default)       Interactive scan-then-select, then install
  --status        Read-only overview of agent state (no changes)
  --dry-run       Preview actions without modifying files
  --remove        Uninstall instructions from detected agents
  --auto          Non-interactive install to all detected agents

Options:
  --source PATH   Override default source file (default: dotfiles/instructions/RULES.md)
  --create-dest   Create missing parent directories before copying
  --json          Emit machine-readable JSON (incompatible with default interactive mode)
  --force         Skip confirmation prompts (use with --remove)
  --codex         Force-target Codex even if not detected
  --claude        Force-target Claude Code even if not detected
  --agy           Force-target agy even if not detected
  --opencode      Force-target OpenCode even if not detected
  -h, --help      Show this help message
  --version       Show version

Exit codes:
  0  Success
  1  Error
  2  User abort
EOF
}

# ── Parse arguments ──────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case "$1" in
    --status)       MODE="status"; shift ;;
    --dry-run)      MODE="dry-run"; DRY_RUN=1; shift ;;
    --remove)       MODE="remove"; REMOVE=1; shift ;;
    --auto)         MODE="auto"; shift ;;
    --json)         JSON_OUTPUT=1; shift ;;
    --create-dest)  CREATE_DEST=1; shift ;;
    --force)        FORCE_REMOVE=1; shift ;;
    --codex)        FORCE_CODEX=1; shift ;;
    --claude)       FORCE_CLAUDE=1; shift ;;
    --agy)          FORCE_AGY=1; shift ;;
    --opencode)     FORCE_OPENCODE=1; shift ;;
    --source)       SOURCE="$2"; shift 2 ;;
    -h|--help)      usage; exit 0 ;;
    --version)      echo "install-instructions ${VERSION}"; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage; exit 2 ;;
  esac
done

# ── Validate mutual exclusivity (R34) ───────────────────────────────────────
if [[ "${JSON_OUTPUT}" -eq 1 && "${MODE}" == "interactive" ]]; then
  echo "Error: --json is incompatible with default interactive mode. Use --json --auto." >&2
  exit 1
fi

# ── Source validation (R31) ─────────────────────────────────────────────────
validate_source() {
  if [[ ! -f "${SOURCE}" ]]; then
    echo "Error: Source file does not exist: ${SOURCE}" >&2
    exit 1
  fi
  if [[ ! -s "${SOURCE}" ]]; then
    echo "Error: Source file is empty: ${SOURCE}" >&2
    exit 1
  fi
}

# ── Agent helpers ────────────────────────────────────────────────────────────
detect_agent() {
  local binary="$1"
  command -v "${binary}" >/dev/null 2>&1
}

get_version() {
  local binary="$1"
  if detect_agent "${binary}"; then
    "${binary}" --version 2>/dev/null | head -1 | sed 's/^[[:space:]]*//' || echo "unknown"
  else
    echo "unknown"
  fi
}

is_forced() {
  local name="$1"
  case "${name}" in
    codex)   [[ "${FORCE_CODEX}" -eq 1 ]] ;;
    claude)  [[ "${FORCE_CLAUDE}" -eq 1 ]] ;;
    agy)     [[ "${FORCE_AGY}" -eq 1 ]] ;;
    opencode) [[ "${FORCE_OPENCODE}" -eq 1 ]] ;;
    *)       return 1 ;;
  esac
}

file_state() {
  local dest="$1"
  if [[ ! -f "${dest}" ]]; then
    echo "missing"
  elif cmp -s "${SOURCE}" "${dest}"; then
    echo "identical"
  else
    echo "differs"
  fi
}

show_diff() {
  local src="$1" dest="$2"
  local diff_out
  diff_out=$(diff -u "${dest}" "${src}" 2>/dev/null || true)
  if [[ -n "${diff_out}" ]]; then
    local lines
    lines=$(wc -l <<< "${diff_out}")
    if [[ "${lines}" -gt 50 ]]; then
      echo "${diff_out}" | head -50
      echo "... (diff truncated at 50 lines)"
    else
      echo "${diff_out}"
    fi
  fi
}

backup_file() {
  local dest="$1"
  if [[ -f "${dest}" ]]; then
    cp "${dest}" "${dest}.bak"
  fi
}

install_file() {
  local src="$1" dest="$2" create_dest="$3"
  local dest_dir
  dest_dir=$(dirname "${dest}")

  if [[ ! -d "${dest_dir}" ]]; then
    if [[ "${create_dest}" -eq 1 ]]; then
      mkdir -p "${dest_dir}"
    else
      echo "Destination directory does not exist: ${dest_dir}" >&2
      echo "Re-run with --create-dest to create it." >&2
      return 1
    fi
  fi

  if [[ "${DRY_RUN}" -eq 1 ]]; then
    echo "[dry-run] Would copy ${src} -> ${dest}"
    return 0
  fi

  cp "${src}" "${dest}"
}

remove_file() {
  local dest="$1"
  if [[ -f "${dest}" ]]; then
    if [[ "${DRY_RUN}" -eq 1 ]]; then
      echo "[dry-run] Would remove ${dest}"
      return 0
    fi
    rm "${dest}"
  fi
}

# ── JSON helpers (no jq) ────────────────────────────────────────────────────
JSON_RESULTS=()

json_escape() {
  local s="$1"
  s="${s//\\/\\\\}"
  s="${s//\"/\\\"}"
  s="${s//$'\n'/\\n}"
  s="${s//$'\r'/\\r}"
  s="${s//$'\t'/\\t}"
  printf '%s' "$s"
}

json_add_result() {
  local name="$1" detected="$2" version="$3" action="$4" dest="$5"
  JSON_RESULTS+=("{\"name\":\"$(json_escape "$name")\",\"detected\":${detected},\"version\":\"$(json_escape "$version")\",\"action\":\"$(json_escape "$action")\",\"destination\":\"$(json_escape "$dest")\"}")
}

json_emit() {
  local first=1
  printf '{"agents":['
  for item in "${JSON_RESULTS[@]}"; do
    if [[ "${first}" -eq 1 ]]; then
      first=0
    else
      printf ','
    fi
    printf '%s' "${item}"
  done
  printf ']}\n'
}

# ── Output helpers ───────────────────────────────────────────────────────────
print_header() {
  local title="$1"
  echo ""
  c "${BOLD}" "═══ ${title} ═══"
  echo ""
}

print_status_line() {
  local name="$1" detected="$2" version="$3" state="$4" selected="$5"
  local det_str state_str sel_str

  if [[ "${detected}" == "true" ]]; then
    det_str=$(c "${GREEN}" "installed")
  else
    det_str=$(c "${RED}" "not found")
  fi

  case "${state}" in
    missing)    state_str=$(c "${YELLOW}" "missing") ;;
    identical)  state_str=$(c "${GREEN}" "up to date") ;;
    differs)    state_str=$(c "${YELLOW}" "differs") ;;
    opencode)   state_str=$(c "${CYAN}" "config ref") ;;
    *)          state_str="unknown" ;;
  esac

  if [[ "${selected}" == "yes" ]]; then
    sel_str=$(c "${GREEN}" "[x]")
  else
    sel_str="   "
  fi

  printf "  %s %-12s %-16s %-12s %s\n" "${sel_str}" "${name}" "${det_str}" "${version}" "${state_str}"
}

# ── Interactive selection (R16-R19) ──────────────────────────────────────────
declare -A AGENT_STATE  # name -> detected|version|state|binary|dest
SELECTED_AGENTS=()

scan_agents() {
  for entry in "${AGENTS[@]}"; do
    IFS='|' read -r name binary dest <<< "${entry}"
    local detected="false" version="unknown" state="unknown"
    local dest_resolved="${dest}"

    if [[ "${name}" == "opencode" ]]; then
      state="opencode"
      if detect_agent "${binary}"; then
        detected="true"
        version=$(get_version "${binary}")
      fi
    else
      if detect_agent "${binary}"; then
        detected="true"
        version=$(get_version "${binary}")
        state=$(file_state "${dest}")
      else
        state="missing"
      fi
    fi

    AGENT_STATE["${name}"]="${detected}|${version}|${state}|${binary}|${dest}"
  done
}

interactive_select() {
  local targets=()
  print_header "Agent Scan"

  for entry in "${AGENTS[@]}"; do
    IFS='|' read -r name binary dest <<< "${entry}"
    IFS='|' read -r detected version state _binary _dest <<< "${AGENT_STATE[${name}]}"
    local default_sel="no"
    if [[ "${detected}" == "true" ]]; then
      default_sel="yes"
    fi
    if is_forced "${name}"; then
      default_sel="yes"
    fi
    targets+=("${name}:${default_sel}")
    print_status_line "${name}" "${detected}" "${version}" "${state}" "${default_sel}"
  done

  echo ""
  echo "  Toggle agents by number, or press Enter to accept defaults."
  echo "  Example: '1 3' toggles codex and agy. Empty = accept."
  echo ""

  while true; do
    printf "  Selection (Enter to confirm): "
    IFS= read -r input </dev/tty || input=""
    if [[ -z "${input}" ]]; then
      break
    fi

    for num in ${input}; do
      local idx=$((num - 1))
      if [[ "${idx}" -ge 0 && "${idx}" -lt ${#targets[@]} ]]; then
        local current="${targets[${idx}]}"
        local cur_name="${current%%:*}"
        local cur_sel="${current##*:}"
        if [[ "${cur_sel}" == "yes" ]]; then
          targets[${idx}]="${cur_name}:no"
        else
          targets[${idx}]="${cur_name}:yes"
        fi
      fi
    done

    echo ""
    print_header "Updated Selection"
    for t in "${targets[@]}"; do
      local tname="${t%%:*}"
      local tsel="${t##*:}"
      IFS='|' read -r detected version state _binary _dest <<< "${AGENT_STATE[${tname}]}"
      print_status_line "${tname}" "${detected}" "${version}" "${state}" "${tsel}"
    done
    echo ""
  done

  for t in "${targets[@]}"; do
    local tname="${t%%:*}"
    local tsel="${t##*:}"
    if [[ "${tsel}" == "yes" ]]; then
      SELECTED_AGENTS+=("${tname}")
    fi
  done
}

# ── Install logic ────────────────────────────────────────────────────────────
install_mode() {
  local targets=()
  local apply_all="" apply_choice=""

  if [[ "${MODE}" == "interactive" ]]; then
    interactive_select
    for name in "${SELECTED_AGENTS[@]}"; do
      targets+=("${name}")
    done
  else
    # auto or dry-run: target all detected or force-flagged
    for entry in "${AGENTS[@]}"; do
      IFS='|' read -r name binary dest <<< "${entry}"
      IFS='|' read -r detected version state _binary _dest <<< "${AGENT_STATE[${name}]}"
      if [[ "${detected}" == "true" ]] || is_forced "${name}"; then
        targets+=("${name}")
      fi
    done
  fi

  if [[ ${#targets[@]} -eq 0 ]]; then
    if [[ "${JSON_OUTPUT}" -eq 1 ]]; then
      json_emit
    else
      echo "No agents selected."
    fi
    return 0
  fi

  local installed=0 skipped=0 updated=0

  for name in "${targets[@]}"; do
    IFS='|' read -r detected version state binary dest <<< "${AGENT_STATE[${name}]}"

    if [[ "${name}" == "opencode" ]]; then
      # OpenCode: config reference, no copy
      if [[ "${JSON_OUTPUT}" -eq 0 ]]; then
        echo "  ${name}: config reference (no copy needed)"
      fi
      json_add_result "${name}" "${detected}" "${version}" "config-ref" "${dest}"
      continue
    fi

    if [[ "${state}" == "missing" ]]; then
      install_file "${SOURCE}" "${dest}" "${CREATE_DEST}" && {
        if [[ "${JSON_OUTPUT}" -eq 0 ]]; then
          echo "  ${name}: installed"
        fi
        json_add_result "${name}" "${detected}" "${version}" "installed" "${dest}"
        installed=$((installed + 1))
      } || {
        json_add_result "${name}" "${detected}" "${version}" "error" "${dest}"
        skipped=$((skipped + 1))
      }
    elif [[ "${state}" == "identical" ]]; then
      if [[ "${JSON_OUTPUT}" -eq 0 ]]; then
        echo "  ${name}: up to date"
      fi
      json_add_result "${name}" "${detected}" "${version}" "up-to-date" "${dest}"
      skipped=$((skipped + 1))
    elif [[ "${state}" == "differs" ]]; then
      if [[ "${JSON_OUTPUT}" -eq 1 ]]; then
        # JSON mode: auto-overwrite
        backup_file "${dest}"
        install_file "${SOURCE}" "${dest}" "${CREATE_DEST}"
        json_add_result "${name}" "${detected}" "${version}" "overwritten" "${dest}"
        updated=$((updated + 1))
      elif [[ "${MODE}" == "dry-run" ]]; then
        show_diff "${SOURCE}" "${dest}"
        echo "  ${name}: would overwrite"
        json_add_result "${name}" "${detected}" "${version}" "would-overwrite" "${dest}"
      else
        # Check apply-to-all
        if [[ -n "${apply_all}" ]]; then
          if [[ "${apply_all}" == "overwrite" ]]; then
            backup_file "${dest}"
            install_file "${SOURCE}" "${dest}" "${CREATE_DEST}"
            echo "  ${name}: overwritten (apply-to-all)"
            json_add_result "${name}" "${detected}" "${version}" "overwritten" "${dest}"
            updated=$((updated + 1))
          else
            echo "  ${name}: skipped (apply-to-all)"
            json_add_result "${name}" "${detected}" "${version}" "skipped" "${dest}"
            skipped=$((skipped + 1))
          fi
          continue
        fi

        echo ""
        echo "  ${name}: destination differs"
        show_diff "${SOURCE}" "${dest}"
        echo ""
        while true; do
          printf "  [a]pply to all, [o]verwrite, [s]kip, [q]uit? "
          IFS= read -r choice </dev/tty || choice=""
          choice="$(printf "%s" "${choice}" | tr '[:upper:]' '[:lower:]')"
          case "${choice}" in
            a)
              printf "  Apply [o]verwrite or [s]kip to all remaining? "
              IFS= read -r apply_choice </dev/tty || apply_choice=""
              apply_choice="$(printf "%s" "${apply_choice}" | tr '[:upper:]' '[:lower:]')"
              if [[ "${apply_choice}" == "o" ]]; then
                apply_all="overwrite"
              else
                apply_all="skip"
              fi
              break
              ;;
            o)
              backup_file "${dest}"
              install_file "${SOURCE}" "${dest}" "${CREATE_DEST}"
              echo "  ${name}: overwritten"
              json_add_result "${name}" "${detected}" "${version}" "overwritten" "${dest}"
              updated=$((updated + 1))
              break
              ;;
            s)
              echo "  ${name}: skipped"
              json_add_result "${name}" "${detected}" "${version}" "skipped" "${dest}"
              skipped=$((skipped + 1))
              break
              ;;
            q)
              echo "Aborted by user."
              exit 2
              ;;
            *)
              echo "Invalid choice."
              ;;
          esac
        done
      fi
    fi
  done

  if [[ "${JSON_OUTPUT}" -eq 1 ]]; then
    json_emit
  else
    echo ""
    echo "Done."
    echo "Installed: ${installed}"
    echo "Skipped:   ${skipped}"
    echo "Updated:   ${updated}"
  fi
}

# ── Status mode (R21, R35) ──────────────────────────────────────────────────
status_mode() {
  print_header "Agent Status"

  printf "  %-14s %-18s %-16s %s\n" "AGENT" "DETECTED" "VERSION" "STATE"
  printf "  %-14s %-18s %-16s %s\n" "──────────────" "──────────────────" "────────────────" "──────────────"

  for entry in "${AGENTS[@]}"; do
    IFS='|' read -r name binary dest <<< "${entry}"
    IFS='|' read -r detected version state _binary _dest <<< "${AGENT_STATE[${name}]}"

    local det_str
    if [[ "${detected}" == "true" ]]; then
      det_str=$(c "${GREEN}" "yes")
    else
      det_str=$(c "${RED}" "no")
    fi

    local state_str
    case "${state}" in
      missing)    state_str=$(c "${RED}" "missing") ;;
      identical)  state_str=$(c "${GREEN}" "identical") ;;
      differs)    state_str=$(c "${YELLOW}" "differs") ;;
      opencode)   state_str=$(c "${CYAN}" "config ref") ;;
      *)          state_str="unknown" ;;
    esac

    local ver_str="${version}"
    if [[ "${version}" == "unknown" ]]; then
      ver_str=$(c "${YELLOW}" "unknown")
    fi

    printf "  %-14s %-18s %-16s %s\n" "${name}" "${det_str}" "${ver_str}" "${state_str}"
  done

  echo ""
}

# ── Remove mode (R27-R29) ──────────────────────────────────────────────────
remove_mode() {
  local targets=()

  for entry in "${AGENTS[@]}"; do
    IFS='|' read -r name binary dest <<< "${entry}"
    IFS='|' read -r detected version state _binary _dest <<< "${AGENT_STATE[${name}]}"
    if [[ "${detected}" == "true" ]] || is_forced "${name}"; then
      if [[ "${name}" != "opencode" && "${state}" != "missing" ]]; then
        targets+=("${name}")
      fi
    fi
  done

  if [[ ${#targets[@]} -eq 0 ]]; then
    if [[ "${JSON_OUTPUT}" -eq 1 ]]; then
      json_emit
    else
      echo "No installed instructions found to remove."
    fi
    return 0
  fi

  for name in "${targets[@]}"; do
    IFS='|' read -r detected version state binary dest <<< "${AGENT_STATE[${name}]}"

    if [[ "${FORCE_REMOVE}" -ne 1 && "${JSON_OUTPUT}" -ne 1 ]]; then
      printf "  Remove ${name} instructions from ${dest}? [y/N] "
      IFS= read -r ans </dev/tty || ans=""
      ans="$(printf "%s" "${ans}" | tr '[:upper:]' '[:lower:]')"
      if [[ "${ans}" != "y" && "${ans}" != "yes" ]]; then
        echo "  ${name}: skipped"
        json_add_result "${name}" "${detected}" "${version}" "skipped" "${dest}"
        continue
      fi
    fi

    remove_file "${dest}"
    echo "  ${name}: removed"
    json_add_result "${name}" "${detected}" "${version}" "removed" "${dest}"
  done

  if [[ "${JSON_OUTPUT}" -eq 1 ]]; then
    json_emit
  fi
}

# ── Main ─────────────────────────────────────────────────────────────────────
validate_source
scan_agents

case "${MODE}" in
  status)     status_mode ;;
  remove)     remove_mode ;;
  *)          install_mode ;;
esac

exit 0

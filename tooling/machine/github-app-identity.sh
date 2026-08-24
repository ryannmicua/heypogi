#!/usr/bin/env bash
#=======================================================================
# Script:    github-app-identity.sh
# Purpose:   Set up a GitHub App as the machine-level agent identity:
#            config home, token CLI, git credential helper, gh CLI shim,
#            commit attribution. Idempotent - safe to re-run.
# Usage:     ./github-app-identity.sh [options]
#
# Required inputs (flags, or prompted on a terminal):
#   --app-id N             numeric GitHub App ID
#   --slug NAME            app slug (bot becomes NAME[bot])
#   --key PATH             path to the app's private-key .pem
#   --installation N=ID    named installation, repeatable; first = fallback default
#
# Options:
#   --client-id X          record Client ID as a comment only
#   --copy-key             copy the .pem into the config dir (default: symlink)
#   --set-global-identity  set git GLOBAL user.name/email to the bot identity
#   --test-repo URL        also verify with `git ls-remote URL`
#   --verify-only          skip setup, only run live verification
#   -y, --yes              never prompt; fail if a required value is missing
#   -h, --help             show this help
#
# Prereqs: git, openssl, curl, jq
# Docs:    tooling/machine/github-app-identity.md
#=======================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
BIN_SRC="$SCRIPT_DIR"                            # canonical tools live beside this script
TEMPLATE="$SCRIPT_DIR/github-app.app.conf.template"

CONF_DIR="$HOME/.config/github-app"
CONF_FILE="$CONF_DIR/app.conf"
KEY_LINK="$CONF_DIR/private-key.pem"
CACHE_DIR="$HOME/.cache/github-app/tokens"
LOCAL_BIN="$HOME/.local/bin"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
echo_info()    { echo -e "${BLUE}INFO:${NC} $*"; }
echo_success() { echo -e "${GREEN}OK:${NC} $*"; }
echo_warn()    { echo -e "${YELLOW}WARN:${NC} $*"; }
echo_err()     { echo -e "${RED}ERROR:${NC} $*" >&2; }
die()          { echo_err "$*"; exit 1; }

APP_ID="" SLUG="" KEY_PATH="" CLIENT_ID="" TEST_REPO=""
INSTALLATIONS=()
COPY_KEY=false SET_IDENTITY=false VERIFY_ONLY=false ASSUME_YES=false

usage() { sed -n '2,25p' "$0" | sed 's/^# \{0,1\}//'; exit 0; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --app-id) APP_ID="$2"; shift 2 ;;
    --slug) SLUG="$2"; shift 2 ;;
    --key) KEY_PATH="$2"; shift 2 ;;
    --client-id) CLIENT_ID="$2"; shift 2 ;;
    --installation) INSTALLATIONS+=("$2"); shift 2 ;;
    --copy-key) COPY_KEY=true; shift ;;
    --set-global-identity) SET_IDENTITY=true; shift ;;
    --test-repo) TEST_REPO="$2"; shift 2 ;;
    --verify-only) VERIFY_ONLY=true; shift ;;
    -y|--yes) ASSUME_YES=true; shift ;;
    -h|--help) usage ;;
    *) echo_err "Unknown argument: $1"; usage ;;
  esac
done

for cmd in git openssl curl jq; do
  command -v "$cmd" >/dev/null || die "missing dependency: $cmd"
done

prompt_missing() {
  local var=$1 label=$2
  if [[ -z "${!var}" ]] && [[ -t 0 ]] && [[ "$ASSUME_YES" == false ]]; then
    read -r -p "$label: " "${!var}"
  fi
}

check_required() {
  local missing=0 v
  for v in APP_ID SLUG KEY_PATH; do
    [[ -z "${!v}" ]] && { echo_err "missing required input: $v"; missing=1; }
  done
  [[ ${#INSTALLATIONS[@]} -eq 0 ]] && { echo_err "missing required input: at least one --installation NAME=ID"; missing=1; }
  (( missing == 0 )) || die "re-run with flags or interactively (without -y)"
}

# --- Setup ---

install_conf() {
  mkdir -p "$CONF_DIR" "$CACHE_DIR"
  chmod 700 "$CONF_DIR" "$CACHE_DIR"

  [[ -f "$KEY_PATH" ]] || die "key file not found: $KEY_PATH"
  openssl rsa -in "$KEY_PATH" -check -noout >/dev/null 2>&1 \
    || die "$KEY_PATH is not a valid RSA private key (.pem)"

  if [[ "$COPY_KEY" == true ]]; then
    cp "$KEY_PATH" "$KEY_LINK"
    chmod 600 "$KEY_LINK"
  else
    KEY_PATH="$(readlink -f "$KEY_PATH")"
    ln -sfn "$KEY_PATH" "$KEY_LINK"
  fi
  echo_success "private key available at $KEY_LINK ($([[ "$COPY_KEY" == true ]] && echo copied || echo symlink to "$KEY_PATH"))"

  local inst_block line
  for line in "${INSTALLATIONS[@]}"; do
    [[ "$line" =~ ^[A-Za-z0-9_-]+=[0-9]+$ ]] || die "installation must be NAME=ID (got: $line)"
  done
  inst_block=$(printf '%s\n' "${INSTALLATIONS[@]}")

  local tmp="$CONF_FILE.tmp.$$"
  sed -e "s|__APP_ID__|$APP_ID|g" -e "s|__SLUG__|$SLUG|g" "$TEMPLATE" \
    | awk -v inst="$inst_block" '/^__INSTALLATIONS__$/{print inst; next} {print}' > "$tmp"
  if [[ -n "$CLIENT_ID" ]]; then
    printf '\n# Client ID (public): %s\n' "$CLIENT_ID" >> "$tmp"
  fi
  if [[ -f "$CONF_FILE" ]]; then
    cp "$CONF_FILE" "$CONF_FILE.bak"
    echo_info "existing app.conf backed up to app.conf.bak"
  fi
  mv "$tmp" "$CONF_FILE"
  chmod 600 "$CONF_FILE"
  echo_success "config written: $CONF_FILE"
}

install_tools() {
  mkdir -p "$LOCAL_BIN"
  cp -f "$BIN_SRC/gh-app-token" "$LOCAL_BIN/gh-app-token"
  cp -f "$BIN_SRC/git-credential-gh-app" "$LOCAL_BIN/git-credential-gh-app"
  chmod 755 "$LOCAL_BIN/gh-app-token" "$LOCAL_BIN/git-credential-gh-app"
  echo_success "tools installed: $LOCAL_BIN/gh-app-token, $LOCAL_BIN/git-credential-gh-app"
}

install_gh_shim() {
  # Route every `gh` invocation through the app identity so all gh
  # operations (Paseo daemon + agents included) are attributed to the bot.
  local real_gh="" cand
  while read -r cand; do
    if [[ -n "$cand" && "$cand" != "$LOCAL_BIN/gh" ]]; then real_gh="$cand"; break; fi
  done < <(type -ap gh 2>/dev/null)
  if [[ -z "$real_gh" ]]; then
    echo_warn "no gh CLI outside $LOCAL_BIN — gh shim skipped (install gh, re-run to add it)"
    return 0
  fi
  local tmp="$LOCAL_BIN/.gh.shim.$$"
  sed -e "s|__GH_BIN__|$real_gh|g" "$SCRIPT_DIR/gh.shim.template" > "$tmp"
  mv "$tmp" "$LOCAL_BIN/gh"
  chmod 755 "$LOCAL_BIN/gh"
  echo_success "gh shim installed: $LOCAL_BIN/gh (resolves to $real_gh; gh calls act as ${SLUG}[bot])"
}

wire_git() {
  git config --global --unset-all credential.https://github.com.helper 2>/dev/null || true
  git config --global credential.https://github.com.helper ''
  # NOTE: value must START with '!' (shell-command helper). No surrounding
  # quotes — a leading '"' makes git treat the whole thing as a builtin name.
  git config --global --add credential.https://github.com.helper "!$LOCAL_BIN/git-credential-gh-app"
  # Send the repo path to the helper so it can pick the installation whose
  # name matches the org (e.g. adventistasia/org-repo -> installation 'adventistasia').
  git config --global credential.https://github.com.useHttpPath true
  echo_success "git credential helper wired for https://github.com only"
}

set_identity() {
  local uid
  uid=$(curl -fsS -g "https://api.github.com/users/${SLUG}%5Bbot%5D" | jq -r '.id // empty') || uid=""
  [[ -n "$uid" ]] || { echo_warn "could not resolve bot user id; set attribution manually later"; return 1; }
  git config --global user.name "${SLUG}[bot]"
  git config --global user.email "${uid}+${SLUG}[bot]@users.noreply.github.com"
  echo_success "global git identity set to ${SLUG}[bot] <${uid}+${SLUG}[bot]@users.noreply.github.com>"
}

# --- Verification ---

verify() {
  local fail=0 name tok

  echo_info "whoami:"
  gh-app-token --whoami || fail=1

  echo_info "installations (live API):"
  gh-app-token --list || fail=1

  while read -r name; do
    [[ -z "$name" ]] && continue
    if tok=$(gh-app-token --refresh "$name"); then
      echo_success "token minted for '$name' (${tok:0:8}...)"
    else
      echo_err "token mint FAILED for '$name'"
      fail=1
    fi
  done < <(grep -vE '^\s*#|^\s*$|GITHUB_APP_' "$CONF_FILE" | cut -d= -f1)

  if [[ -n "$TEST_REPO" ]]; then
    echo_info "git ls-remote $TEST_REPO"
    if git ls-remote "$TEST_REPO" HEAD >/dev/null 2>&1; then
      echo_success "git HTTPS fetch works"
    else
      echo_err "git ls-remote failed"
      fail=1
    fi
  fi

  # Auth smoke test: credential fill must return a token via the helper.
  # (ls-remote alone can pass on public repos without any credentials.)
  echo_info "credential helper auth check (github.com)"
  if out=$(printf 'protocol=https\nhost=github.com\n\n' | git credential fill 2>/dev/null) &&
     grep -q '^password=ghs_' <<<"$out"; then
    echo_success "credential helper returned an installation token (ghs_...)"
  else
    echo_err "credential helper did not produce a token"
    fail=1
  fi

  # gh shim check: bare `gh` must resolve to the shim and auth as the bot.
  echo_info "gh shim auth check"
  if [[ "$(command -v gh || true)" == "$LOCAL_BIN/gh" ]]; then
    if out=$(gh auth status 2>&1) && grep -q '\[bot\]' <<<"$out"; then
      echo_success "gh acts as the app identity via $LOCAL_BIN/gh"
    else
      echo_err "gh did not authenticate as the bot (status: ${out:-empty})"
      fail=1
    fi
  else
    echo_warn "gh shim not active on PATH — skipping gh auth check"
  fi

  (( fail == 0 )) || die "verification had failures"
  echo_success "ALL VERIFIED — GitHub App identity is live"
}

if command -v shellcheck >/dev/null 2>&1; then :; fi  # optional lint hook point

if [[ "$VERIFY_ONLY" == true ]]; then
  [[ -f "$CONF_FILE" ]] || die "no $CONF_FILE — run without --verify-only first"
else
  prompt_missing APP_ID "GitHub App ID (numeric)"
  prompt_missing SLUG "App slug"
  prompt_missing KEY_PATH "Path to private-key .pem"
  check_required
  install_conf
  install_tools
  install_gh_shim
  wire_git
  if [[ "$SET_IDENTITY" == true ]]; then
    set_identity || true
  fi
fi

verify

echo ""
echo_info "Daily use:"
echo_info "  gh <command>                            # acts as the bot via the $LOCAL_BIN/gh shim"
echo_info "  git push/pull over https://github.com just works (credential helper)"
echo_info "  GH_APP_INSTALLATION=<name> <command>   # target a specific installation"
echo_info "  export GH_TOKEN=\$(gh-app-token $(grep -vE '^\s*#|^\s*$|GITHUB_APP_' "$CONF_FILE" | head -1 | cut -d= -f1))   # explicit token for non-gh tools"


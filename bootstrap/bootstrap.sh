#!/usr/bin/env bash
#=======================================================================
# Script:    bootstrap.sh
# Purpose:   Orchestrator that converges a machine into an AI Agentic
#            Development VM by delegating to tooling/ (KTD1). Owns
#            argument parsing, env-first call ordering, --skip-*
#            mapping (R25), --user target context (R21), run-history
#            markers (R14-R17/R27), and the status verb (R17). Contains
#            no inline install logic: every leaf reconciler owns its
#            state and is called through status/install with -f/-q/
#            --dry-run passthrough.
# Usage:     bootstrap.sh [status|install] [--user USER]
#                          [--skip-agents] [--skip-paseo]
#                          [--skip-dotfiles] [--skip-services]
#                          [-f|--force] [-q|--quiet] [--dry-run] [-h|--help]
#
# Call order (env-first, KTD7/HLD):
#   setup-env install -> check-prereqs install -> userspace-shims
#   install -> install-{claude,codex,gh} install -> external sources
#   acquire -> dev-stack install (incl. Paseo additive seed) ->
#   skills install-* -> dev-stack startup install + start -> marker.
#
# Flag mapping (R25, exhaustive):
#   --skip-agents    skips install-{claude,codex,gh} only.
#   --skip-paseo     skips dev-stack Paseo install + Paseo seed +
#                    user-unit startup/start.
#   --skip-dotfiles  skips `setup-env install` AND requires
#                    pre-existing env (guard exit 3 otherwise; a
#                    documented precondition, not a silent pass).
#   --skip-services  skips `startup install` + `start` only.
#   --dry-run        passes through to every child; zero writes
#                    incl. marker/logs/children.
# Target context (R21): --user TARGET defines TARGET_UID/HOME
#   (~TARGET), XDG_RUNTIME_DIR=/run/user/<uid>, a userspace-first
#   PATH, and the systemd user bus for TARGET. Only apt (machine
#   installers), linger, and legacy-unit removal may use sudo (inside
#   the leaves, logged, dry-run aware). Leaf installers run as TARGET
#   via sudo -u; they are never run wholesale as root (root without
#   --user is rejected).
# Exit codes: 0 converged, 1 drift/failed/incomplete, 2 usage error,
#   3 blocked (missing env under --skip-dotfiles, offline registry at
#   the first network-dependent unit, linger off unprivileged, ...).
#=======================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HEYPOGI_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

COMMAND="install"
TARGET_USER="${TARGET_USER:-$(whoami)}"
TARGET_USER_EXPLICIT=false
SKIP_AGENTS=false
SKIP_PASEO=false
SKIP_DOTFILES=false
SKIP_SERVICES=false
FORCE=false
QUIET=false
DRY_RUN=false
ORIG_ARGV="$*"

# --- Logging (printf only; INFO/OK -> stdout unless quiet; WARN/ERROR -> stderr) ---
log_info() {
    [[ "$QUIET" == true ]] && return 0
    if [[ -z "${NO_COLOR:-}" && -t 1 ]]; then printf '\033[0;34mINFO:\033[0m %s\n' "$*"
    else printf 'INFO: %s\n' "$*"; fi
}
log_ok() {
    [[ "$QUIET" == true ]] && return 0
    if [[ -z "${NO_COLOR:-}" && -t 1 ]]; then printf '\033[0;32mOK:\033[0m %s\n' "$*"
    else printf 'OK: %s\n' "$*"; fi
}
log_warn() {
    if [[ -z "${NO_COLOR:-}" && -t 2 ]]; then printf '\033[1;33mWARN:\033[0m %s\n' "$*" >&2
    else printf 'WARN: %s\n' "$*" >&2; fi
}
log_err() {
    if [[ -z "${NO_COLOR:-}" && -t 2 ]]; then printf '\033[0;31mERROR:\033[0m %s\n' "$*" >&2
    else printf 'ERROR: %s\n' "$*" >&2; fi
}
log_dry() { printf 'DRY-RUN: %s\n' "$*"; }

# --- Help (prints and returns; caller decides exit status) ---
show_help() {
    cat <<'EOF'
bootstrap.sh - converge a machine into an AI Agentic Development VM.

Usage:
  bootstrap.sh [status|install] [--user USER] [--skip-agents] [--skip-paseo]
               [--skip-dotfiles] [--skip-services] [-f|--force] [-q|--quiet]
               [--dry-run] [-h|--help]

Commands:
  install  Run the env-first delegation order (default).
  status   Report the last run + whether downstream still converges.

Options:
  --user USER      Target user owning all user-scoped state (default:
                   current user). Required when running as root.
  --skip-agents    Skip install-{claude,codex,gh} only.
  --skip-paseo     Skip dev-stack Paseo install + Paseo seed + user-unit startup.
  --skip-dotfiles  Skip `setup-env install`; requires pre-existing env
                   (exit 3 otherwise).
  --skip-services  Skip `startup install` + `start` only.
  -f, --force      Skip confirmation prompts (declared targets only).
  -q, --quiet      Suppress INFO/OK chatter (never implies consent).
  --dry-run        Plan only: forwarded to every child; zero writes.
  -h, --help       Show this help (side-effect-free).

Preflight (before any mutation, --force never skips): env files set up
  once by the user (`setup-env.sh install` as TARGET, then fill in
  secrets); PASEO_PASSWORD set when Paseo will start; linger enabled
  (`sudo loginctl enable-linger TARGET`) when the user unit will start.
  Each failure prints its exact remediation and exits 3.

Exit codes: 0 converged, 1 drift/failed, 2 usage error, 3 blocked.
EOF
    return 0
}

# --- Parse args (validate before any mutation) ---
positional=()
while [[ $# -gt 0 ]]; do
    case "$1" in
        status|install) positional+=("$1"); shift ;;
        --user)
            if [[ $# -lt 2 || "$2" == -* ]]; then
                log_err "Missing value for --user (want: an existing username)."
                exit 2
            fi
            TARGET_USER="$2"; TARGET_USER_EXPLICIT=true; shift 2 ;;
        --skip-agents) SKIP_AGENTS=true; shift ;;
        --skip-paseo) SKIP_PASEO=true; shift ;;
        --skip-dotfiles) SKIP_DOTFILES=true; shift ;;
        --skip-services) SKIP_SERVICES=true; shift ;;
        -f|--force) FORCE=true; shift ;;
        -q|--quiet) QUIET=true; shift ;;
        --dry-run) DRY_RUN=true; shift ;;
        -h|--help) show_help; exit 0 ;;
        --) shift; while [[ $# -gt 0 ]]; do positional+=("$1"); shift; done ;;
        -*) log_err "Unknown option: $1"; show_help >&2; exit 2 ;;
        *) log_err "Unexpected argument: $1"; show_help >&2; exit 2 ;;
    esac
done
if [[ "${#positional[@]}" -gt 1 ]]; then
    log_err "At most one command (status|install) is accepted."
    exit 2
fi
[[ "${#positional[@]}" -eq 1 ]] && COMMAND="${positional[0]}"

# --- Target context (R21) ---
if ! id "$TARGET_USER" &>/dev/null; then
    log_err "User '$TARGET_USER' does not exist."
    exit 2
fi
if [[ "$EUID" -eq 0 && "$TARGET_USER" == "root" && "$TARGET_USER_EXPLICIT" != true ]]; then
    log_err "Running as root without --user would create root-owned leaves."
    log_err "Remediation: re-run with --user TARGET (leaf installers are never run wholesale as root)."
    exit 2
fi
TARGET_UID="$(id -u "$TARGET_USER")"
# R21/KTD6: refuse UID 0 (root) without explicit --user to prevent
# --user 0 bypassing the literal-string root check above.
if [[ "$TARGET_UID" -eq 0 && "$TARGET_USER_EXPLICIT" != true ]]; then
    log_err "Target user resolves to UID 0 (root) without --user flag. Root-owned leaves are not allowed."
    log_err "Remediation: re-run with --user TARGET (leaf installers are never run wholesale as root)."
    exit 2
fi
# R21: --user root is always rejected when running as root, because
# leaf installers are never run wholesale as root (plan R21/KTD6).
if [[ "$EUID" -eq 0 && "$TARGET_USER" == "root" ]]; then
    log_err "--user root is not supported. Leaf installers are never run wholesale as root."
    log_err "Remediation: run without --user to use the current user, or omit --user and run as the target user directly."
    exit 2
fi
TARGET_HOME="$(getent passwd "$TARGET_USER" | cut -d: -f6)"
if [[ -z "$TARGET_HOME" ]]; then
    log_err "Could not resolve home directory for '$TARGET_USER' (getent passwd failed)."
    log_err "Remediation: verify '$TARGET_USER' exists and has a valid passwd entry."
    exit 2
fi
TARGET_XDG="/run/user/$TARGET_UID"
TARGET_PATH="$TARGET_HOME/.local/bin:$TARGET_HOME/.local/node-bin:$TARGET_HOME/.opencode/bin:$HEYPOGI_ROOT/tooling/bin:/usr/local/bin:/usr/bin:/bin:/usr/local/sbin:/usr/sbin:/sbin"
MARKER_DIR="$TARGET_HOME/.config/heypogi"
MARKER_LOG="$MARKER_DIR/.bootstrap-runs.log"
MARKER_LAST="$MARKER_DIR/.bootstrap-last-run"
MARKER_LOCK="$MARKER_DIR/.bootstrap-runs.lock"

NEED_SWITCH=false
if [[ "$EUID" -eq 0 && "$(whoami)" != "$TARGET_USER" ]]; then
    NEED_SWITCH=true
    if ! command -v sudo >/dev/null 2>&1; then
        log_err "Need sudo to run leaf installers as $TARGET_USER, but sudo is missing."
        exit 3
    fi
elif [[ "$(whoami)" != "$TARGET_USER" ]]; then
    log_err "Cannot run leaf installers as '$TARGET_USER' from unprivileged user '$(whoami)'."
    log_err "Remediation: run as root with --user $TARGET_USER, or run as $TARGET_USER."
    exit 3
fi

# Run a command in the target context (R21): user bus + userspace-first
# PATH for TARGET; sudo -u down-switch only when privileged.
exec_as_target() {
    if [[ "$NEED_SWITCH" == true ]]; then
        sudo -u "$TARGET_USER" env "HOME=$TARGET_HOME" "XDG_RUNTIME_DIR=$TARGET_XDG" "PATH=$TARGET_PATH" "$@"
    else
        env "HOME=$TARGET_HOME" "XDG_RUNTIME_DIR=$TARGET_XDG" "PATH=$TARGET_PATH" "$@"
    fi
}

as_target() {
    if [[ "$DRY_RUN" == true ]]; then
        log_dry "(as $TARGET_USER) $*"
        return 0
    fi
    exec_as_target "$@"
}

# --- Run-history marker (R14-R17/R27) ---
finalize_marker() {
    # $1 = real exit code of the run. Skipped under --dry-run. Marker
    # writes never affect the exit code: failures are WARN-only.
    local rc="$1"
    if [[ "$DRY_RUN" == true ]]; then
        return 0
    fi
    local ts sha line
    ts="$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || echo unknown)"
    sha="$(git -C "$HEYPOGI_ROOT" rev-parse HEAD 2>/dev/null || echo unknown)"
    line="$ts | $TARGET_USER | $HEYPOGI_ROOT | $sha | $ORIG_ARGV | $rc"
    if [[ "$NEED_SWITCH" == true ]]; then
        # Values travel as positional args: sudo env_reset strips
        # custom environment variables, but argv survives.
        if ! sudo -u "$TARGET_USER" bash -c '
                line="$1"; log_f="$2"; last_f="$3"; lock_f="$4"; dir_f="$5"
                mkdir -p "$dir_f" 2>/dev/null || exit 1
                exec 9>"$lock_f" 2>/dev/null || exit 1
                flock -x 9 || exit 1
                printf "%s\n" "$line" >>"$log_f" || exit 1
                tmp="$last_f.tmp.$$"
                printf "%s\n" "$line" >"$tmp" || exit 1
                mv "$tmp" "$last_f" || exit 1
            ' _ "$line" "$MARKER_LOG" "$MARKER_LAST" "$MARKER_LOCK" "$MARKER_DIR"; then
            log_warn "Could not write bootstrap run-history marker (non-fatal)."
        fi
    else
        if ! mkdir -p "$MARKER_DIR" 2>/dev/null; then
            log_warn "Could not write bootstrap run-history marker (non-fatal)."
            return 0
        fi
        (
            exec 9>"$MARKER_LOCK" 2>/dev/null || exit 1
            flock -x 9 || exit 1
            printf '%s\n' "$line" >>"$MARKER_LOG" || exit 1
            tmp="$MARKER_LAST.tmp.$$"
            printf '%s\n' "$line" >"$tmp" || exit 1
            mv "$tmp" "$MARKER_LAST" || exit 1
        ) 2>/dev/null || log_warn "Could not write bootstrap run-history marker (non-fatal)."
    fi
    return 0
}

# --- Child runner: every leaf through status/install + passthrough ---
child_flags() {
    # Prints the common passthrough flags for the current run.
    [[ "$FORCE" == true ]] && printf '%s' " -f"
    [[ "$QUIET" == true ]] && printf '%s' " -q"
    [[ "$DRY_RUN" == true ]] && printf '%s' " --dry-run"
}

run_child() {
    # $1 = label; remaining = script + extra args. Aborts the run with
    # the child's exit code on failure (marker trap records it).
    local label="$1"; shift
    local flags
    flags="$(child_flags)"
    log_info "=== $label ==="
    if [[ -n "$flags" ]]; then
        # shellcheck disable=SC2206
        local extra=($flags)
        as_target "$@" "${extra[@]}"
    else
        as_target "$@"
    fi
}

# --- status verb (R17): last run + downstream convergence ---
do_status() {
    log_info "Bootstrap status (target: $TARGET_USER, root: $HEYPOGI_ROOT)"
    if [[ -f "$MARKER_LAST" ]]; then
        log_info "Last run: $(cat "$MARKER_LAST")"
    elif [[ -f "$MARKER_LOG" ]]; then
        log_info "Last run: $(tail -1 "$MARKER_LOG")"
    else
        log_warn "No bootstrap runs recorded yet."
    fi
    local worst=0 rc=0
    check_downstream() {
        as_target "$@" || rc=$?
        if [[ "$rc" -eq 3 ]]; then worst=3
        elif [[ "$rc" -eq 2 && "$worst" -ne 3 ]]; then worst=2
        elif [[ "$rc" -ne 0 && "$worst" -ne 3 && "$worst" -ne 2 ]]; then worst=1
        fi
        rc=0
    }
    check_downstream "$HEYPOGI_ROOT/tooling/env/setup-env.sh" status -q
    check_downstream "$HEYPOGI_ROOT/tooling/machine/check-prereqs.sh" status -q
    check_downstream "$HEYPOGI_ROOT/tooling/bin/userspace-shims.sh" status -q
    check_downstream "$HEYPOGI_ROOT/tooling/machine/install-claude-cli.sh" status -q
    check_downstream "$HEYPOGI_ROOT/tooling/machine/install-codex-cli.sh" status -q
    check_downstream "$HEYPOGI_ROOT/tooling/machine/install-gh-cli.sh" status -q
    check_downstream "$HEYPOGI_ROOT/tooling/skills/install-skills.sh" status -q
    check_downstream "$HEYPOGI_ROOT/tooling/skills/install-ce-skills.sh" status -q
    check_downstream "$HEYPOGI_ROOT/tooling/skills/install-knowledge-skills.sh" status -q
    # External sources: presence check (the acquire step itself is
    # update-external-repos.sh -f, which converges rather than reports).
    for src in compound-engineering compound-knowledge opencode; do
        if [[ -d "$HEYPOGI_ROOT/external/$src/.git" ]]; then
            log_info "External source present: $src"
        else
            log_warn "External source missing: $src"
            # Route through aggregator hierarchy: 3 (blocked) > 2 (usage) > 1 (drift)
            if [[ "$worst" -eq 0 ]]; then worst=1; fi
        fi
    done
    check_downstream "$HEYPOGI_ROOT/tooling/dev-stack/dev-stack.sh" status -q
    if [[ "$worst" -eq 0 ]]; then
        log_ok "Downstream converged."
    elif [[ "$worst" -eq 3 ]]; then
        log_err "Downstream indeterminate/blocked."
    elif [[ "$worst" -eq 2 ]]; then
        log_err "Downstream usage error (bad invocation in a child)."
    else
        log_warn "Downstream drift detected."
    fi
    return "$worst"
}

# --- preflight: things only the user can do, verified before any mutation ---
do_preflight() {
    # Read-only gates. Runs before the confirm prompt and before every
    # step (identically under --dry-run, where it reports blockers with
    # the same exit code but writes nothing). --force never skips these:
    # they are preconditions, not confirmations.
    local block=0

    # 1. Env files must already exist (first-time setup by the user as
    #    TARGET, including secrets only they know). Presence only - Step 0
    #    reconverges content/perms/marker block. Uses exec_as_target (not
    #    as_target): this check is read-only, so it executes for real
    #    even under --dry-run.
    if ! exec_as_target bash -c 'd="$HOME/.config/heypogi"; [[ -f "$d/.env-common" && -f "$d/.env-secrets" ]]'; then
        log_err "Preflight: heypogi env files are not set up for $TARGET_USER."
        log_err "Remediation (once, as $TARGET_USER): bash $HEYPOGI_ROOT/tooling/env/setup-env.sh install"
        log_err "Then fill in secrets in ~/.config/heypogi/.env-secrets and re-run bootstrap."
        block=3
    fi

    # 2. Required secrets for this run's scope. Paseo binds 0.0.0.0, so
    #    its password must exist before the startup/start steps; the
    #    leaves would only fail closed there (exit 3 deep into the run).
    if [[ "$SKIP_PASEO" == false && "$SKIP_SERVICES" == false ]]; then
        if ! exec_as_target bash -c '[[ -n "${PASEO_PASSWORD:-}" ]] && exit 0; f="$HOME/.config/heypogi/.env-secrets"; [[ -f "$f" ]] && grep -qE "^PASEO_PASSWORD=.+" "$f"'; then
            log_err "Preflight: PASEO_PASSWORD is not set for $TARGET_USER, but this run starts Paseo."
            log_err "Remediation: set PASEO_PASSWORD in ~$TARGET_USER/.config/heypogi/.env-secrets, then re-run bootstrap."
            block=3
        fi

        # 3. Linger for the rootless user unit. Only the user (via their
        #    sudo) can grant this; bootstrap never attempts it.
        local linger
        linger="$(loginctl show-user "$TARGET_USER" 2>/dev/null | grep -i '^Linger=' || echo 'Linger=unknown')"
        if [[ "$linger" != "Linger=yes" ]]; then
            log_err "Preflight: linger is off for $TARGET_USER (the user unit would stop at logout)."
            log_err "Remediation (once, requires sudo): sudo loginctl enable-linger $TARGET_USER"
            log_err "Then re-run bootstrap."
            block=3
        fi
    fi

    return "$block"
}

# --- install flow (env-first order, HLD) ---
do_install() {
    if [[ "$DRY_RUN" == true ]]; then
        log_dry "target=$TARGET_USER uid=$TARGET_UID home=$TARGET_HOME xdg=$TARGET_XDG (as-target switch: $NEED_SWITCH)"
        log_dry "order: setup-env -> check-prereqs -> userspace-shims -> agents -> sources -> dev-stack -> skills -> startup+start"
    fi

    do_preflight || return $?

    log_info "AI Agentic Dev VM Bootstrap"
    log_info "  Target user:  $TARGET_USER ($TARGET_HOME)"
    log_info "  Heypogi root: $HEYPOGI_ROOT"
    log_info "  Skip agents:  $SKIP_AGENTS | Skip Paseo: $SKIP_PASEO | Skip dotfiles: $SKIP_DOTFILES | Skip services: $SKIP_SERVICES"

    # Confirm (declared scope only). Quiet never implies consent;
    # non-interactive without --force fails with remediation.
    if [[ "$FORCE" != true && "$DRY_RUN" != true ]]; then
        if [[ -t 0 ]]; then
            printf '%s' "Proceed with bootstrapping? [Y/n] " >&2
            read -r choice
            if [[ "$choice" =~ ^[Nn] ]]; then
                log_info "Aborted."
                return 1
            fi
        else
            log_err "Refusing to bootstrap non-interactively without --force."
            log_err "Remediation: re-run with --force/--dry-run, or run interactively."
            return 1
        fi
    fi

    # Step 0: env first (KTD7). Bootstrap's own pre-env phase is the
    # single guard exception: setup-env creates the env; everything
    # after it is guard-gated inside the leaves.
    if [[ "$SKIP_DOTFILES" == false ]]; then
        run_child "Step 0: environment (setup-env)" \
            "$HEYPOGI_ROOT/tooling/env/setup-env.sh" install || return $?
    else
        log_info "Step 0: skipping setup-env (--skip-dotfiles); requiring pre-existing env..."
        if ! as_target "$HEYPOGI_ROOT/tooling/env/setup-env.sh" status -q; then
            log_err "--skip-dotfiles requires pre-existing env (precondition failure, exit 3)."
            log_err "Remediation: run without --skip-dotfiles, or run setup-env.sh install first."
            return 3
        fi
        log_ok "Pre-existing env verified."
    fi

    # Step 1: system prerequisites (installs curl/git/bwrap/uv via apt,
    #   nvm + Node.js LTS in user space; Docker and AVX are fail-closed
    #   blockers with remediation).
    run_child "Step 1: prerequisites (check-prereqs)" \
        "$HEYPOGI_ROOT/tooling/machine/check-prereqs.sh" install || return $?

    # Step 1b: userspace PATH layout (R32; always runs: cheap,
    # idempotent, outside every --skip-* subset).
    run_child "Step 1b: userspace shims" \
        "$HEYPOGI_ROOT/tooling/bin/userspace-shims.sh" install || return $?

    # Step 2: agent CLIs (R25: --skip-agents covers claude+codex+gh only).
    if [[ "$SKIP_AGENTS" == false ]]; then
        run_child "Step 2a: Claude Code" \
            "$HEYPOGI_ROOT/tooling/machine/install-claude-cli.sh" install || return $?
        run_child "Step 2b: Codex CLI" \
            "$HEYPOGI_ROOT/tooling/machine/install-codex-cli.sh" install || return $?
        run_child "Step 2c: GitHub CLI" \
            "$HEYPOGI_ROOT/tooling/machine/install-gh-cli.sh" install || return $?
    else
        log_info "Step 2: skipping agent CLIs (--skip-agents)"
    fi

    # Step 3: external sources BEFORE skills (R26). Non-interactive
    # converge (-f) is bootstrap-authorized scope.
    if [[ "$DRY_RUN" == true ]]; then
        run_child "Step 3: external sources" \
            "$HEYPOGI_ROOT/tooling/sources/update-external-repos.sh" -f || return $?
    else
        log_info "=== Step 3: external sources ==="
        if [[ "$QUIET" == true ]]; then
            as_target "$HEYPOGI_ROOT/tooling/sources/update-external-repos.sh" -f -q || return $?
        else
            as_target "$HEYPOGI_ROOT/tooling/sources/update-external-repos.sh" -f || return $?
        fi
    fi

    # Step 4: dev-stack install (incl. Paseo additive seed). --skip-paseo
    # narrows the scope to opencode+openchamber.
    if [[ "$SKIP_PASEO" == false ]]; then
        run_child "Step 4: dev stack (dev-stack install)" \
            "$HEYPOGI_ROOT/tooling/dev-stack/dev-stack.sh" install -f || return $?
    else
        log_info "Step 4: dev stack without Paseo (--skip-paseo)"
        run_child "Step 4a: OpenCode" \
            "$HEYPOGI_ROOT/tooling/dev-stack/dev-stack.sh" install -a opencode -f || return $?
        run_child "Step 4b: OpenChamber" \
            "$HEYPOGI_ROOT/tooling/dev-stack/dev-stack.sh" install -a openchamber -f || return $?
    fi

    # Step 5: skills (sources already acquired above; R26).
    run_child "Step 5a: repo skills" \
        "$HEYPOGI_ROOT/tooling/skills/install-skills.sh" install --create-dest || return $?
    run_child "Step 5b: CE skills" \
        "$HEYPOGI_ROOT/tooling/skills/install-ce-skills.sh" install --create-dest || return $?
    run_child "Step 5c: knowledge skills" \
        "$HEYPOGI_ROOT/tooling/skills/install-knowledge-skills.sh" install --create-dest || return $?

    # Step 6: user-unit startup + start (R25: skipped by --skip-services
    # or --skip-paseo).
    if [[ "$SKIP_SERVICES" == false && "$SKIP_PASEO" == false ]]; then
        run_child "Step 6a: Paseo user unit (startup install)" \
            "$HEYPOGI_ROOT/tooling/dev-stack/dev-stack.sh" startup install -a paseo || return $?
        run_child "Step 6b: start services" \
            "$HEYPOGI_ROOT/tooling/dev-stack/dev-stack.sh" start -a paseo || return $?
    else
        log_info "Step 6: skipping systemd startup/start (skip-services=$SKIP_SERVICES skip-paseo=$SKIP_PASEO)"
    fi

    log_ok "Provisioning complete."
}

# --- Main (trap finalizes the run-history marker, R27) ---
main() {
    if [[ "$COMMAND" == "status" ]]; then
        do_status
        return $?
    fi
    local rc=0
    trap 'rc=$?; finalize_marker "$rc"; exit "$rc"' EXIT
    do_install || rc=$?
    if [[ "$rc" -ne 0 ]]; then
        log_err "Bootstrap failed (exit $rc)."
        exit "$rc"
    fi
    exit 0
}

main

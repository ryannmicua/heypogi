---
title: Bootstrap Delegation + Script Contract - Plan
type: feat
date: 2026-09-07
artifact_contract: ce-unified-plan/v1
artifact_readiness: implementation-ready
product_contract_source: legacy-requirements
execution: code
---

## Goal Capsule

**Objective:** Thin `bootstrap/bootstrap.sh` into an orchestrator that delegates to `tooling/`, normalize all scripts to a common CLI/exit/idempotency contract, record bootstrap run history, and fail fast when required env is missing.

**Means:** New `tooling/machine/` installers, `setup-env.sh` as env owner, `dev-stack.sh` as Paseo/config/systemd owner, new bootstrap marker log + `require-env.sh` guard, extension of the existing `script-contract` / `bash-script-contract` skills as the durable standard.

**Authority hierarchy:** This plan owns the delegation map and new-file contracts. `dev-stack.sh` owns Paseo/systemd lifecycle (incl. legacy migration + linger). `setup-env.sh` owns env files. The script-contract skills own future compliance.

**Stop conditions:** Bootstrap contains no inline install logic; every bootstrap-callable script supports `status/install`; marker log records runs (as the intentional idempotency exception); dependents gate on env before mutating; fresh-machine bootstrap converges from zero without self-blocking.

**Tail ownership:** `tooling/` scripts own their state; `bootstrap.sh` owns ordering + `--skip-*` mapping only.

**Review note:** ce-doc-review (2026-09-07) raised 3 P0 + 13 P1 findings against v1 of this plan. All are folded below as R21-R32, KTD6-KTD8, U1-U5 scope corrections, and verification rows. Stable IDs R1-R20 / U1-U5 / KTD1-KTD5 are preserved.

---

## Product Contract

### Summary

`bootstrap.sh` (436 lines, 6 inline steps) duplicates logic that already exists in `tooling/` and drifts from it (bare Codex installer without bwrap, old-style `HEYPOGI_ROOT` export vs `.env-common` system, system vs user systemd unit). This plan moves all install logic into `tooling/`, adds run-history + env-guard infrastructure, and records the script contract in the existing skill family.

### Requirements

**Delegation (settled decisions D1-D8)**

- R1. New `tooling/machine/check-prereqs.sh` owns system checks (node/npm/curl/git/docker/uv/AVX). `check-env.sh` stays env-vars only.
- R2. New `tooling/machine/install-claude-cli.sh` owns Claude install incl. `timeout 90` TUI workaround + manual-fallback message.
- R3. Bootstrap delegates Codex to existing `tooling/machine/install-codex-cli.sh install` (gets bwrap/AppArmor).
- R4. New `tooling/machine/install-gh-cli.sh` owns apt keyring/repo/gh install.
- R5. `tooling/env/setup-env.sh` owns env; bootstrap's inline `HEYPOGI_ROOT` export block is deleted.
- R6. Bootstrap calls all `tooling/skills/install-*.sh` in order (fixes bare-call `--create-dest` failure).
- R7. `dev-stack` owns Paseo config seeding + schema reconcile; bootstrap Step 5 `cp` is deleted.
- R8. Rootless user unit `~/.config/systemd/user/paseo.service` + `linger` + `EnvironmentFile=` wins; bootstrap Step 6 system-unit writer is deleted, replaced by `dev-stack.sh startup install -a paseo` + `start`.

**Script contract (agent recommendation, minimum)**

- R9. Universal: `#!/usr/bin/env bash` + `set -euo pipefail`; `-h/--help` exit 0 side-effect-free; `-q/--quiet` suppresses info only, never consent; `--dry-run` zero writes incl. children/logs; unknown args exit 2; validate before mutating.
- R10. Reconciler profile for bootstrap-callable scripts: `status` (default, read-only) + `install` (converge); `install` takes `-f/--force` (declared targets only, never secrets/wipe/scope expansion) + `--dry-run`; non-interactive never opens `/dev/tty`, fails with remediation.
- R11. Exits: 0 ok/no-op, 1 drift/failed/incomplete, 2 usage error, 3 indeterminate/external-blocked. No `|| true` hiding failure.
- R12. Idempotency: compare-before-write, atomic `mv`, preserve secrets/user-override/runtime state, correct symlink = no-op, never `rm -rf` a conflict.
- R13. Logging: `INFO:/OK:/WARN:/ERROR:/DRY-RUN:` via `printf`, stdout vs stderr split, TTY-only color + `NO_COLOR`, no secrets.

**Bootstrap run history**

- R14. Bootstrap appends one line per run to `~/.config/heypogi/.bootstrap-runs.log`: `ISO8601-ts | user | repo-root | git-sha | args | exit-code`.
- R15. Bootstrap atomically updates `~/.config/heypogi/.bootstrap-last-run` (temp+`mv`) for fast last-run reads. `tail -1` of the log equals this file under single-instance execution (R27).
- R16. Dry-run writes nothing (no marker). Marker writes never affect exit code: marker-write failure is a WARN, never replaces the run's exit code.
- R17. `bootstrap.sh status` reports last run + whether downstream still converges.
- R27. (review P1-9) Marker writes are the intentional, declared exception to "second run no writes". Finalization uses an `ERR`/exit trap so child failure still records the marker with the real exit code; concurrent runs are serialized with `flock` on a lock file so log tail and last-run file cannot disagree.

**Env guard**

- R18. New sourced guard `tooling/env/require-env.sh`: sources `.env-common/override/secrets` when vars unset (covers systemd/cron non-login shells), then fails fast exit 3 with `run setup-env.sh / bootstrap.sh` remediation if `HEYPOGI_ROOT` / `OPENCODE_CONFIG_DIR` missing or `tooling/bin` not on `PATH`. Bootstrap's own pre-env phase is the single explicit exception (see call order): `setup-env install` runs before any guard-dependent installer.
- R19. `dev-stack.sh`, skill installers, and new `install-*.sh` source the guard before any mutation. Secret-dependent paths keep lazy WARNs; only base env is a hard gate.
- R20. Guard is read-only, no prompts, honors `-q` (errors still shown).
- R30. (review P1-13) Guard enforces an allowlisted grammar (`KEY=value`, no `export`, no command substitution, no backticks) and ownership/permission checks (files owned by the target user; common 644, override 640, secrets 600). Malformed or mis-owned files are exit 3 with remediation, never sourced. This bounds the `--user`-from-privileged-shell case (R21).

**Review-folded requirements (ce-doc-review 2026-09-07)**

- R21. (P0-2) Target execution context: `--user TARGET` defines TARGET_UID/HOME (`~TARGET`), XDG (`XDG_RUNTIME_DIR=/run/user/<uid>`), `PATH` (userspace-first), and systemd context (user bus for TARGET, never the caller's). Only `check-prereqs`/`install-gh-cli` (apt) and `loginctl enable-linger` may use `sudo`, each logged before execution and honored by `--dry-run`. Leaf installers are never run wholesale as root; privileged steps `setpriv`/`sudo -u TARGET` down for user-scoped work.
- R22. (P0-3) Legacy migration: `dev-stack.sh startup install -a paseo` detects the legacy system unit (`/etc/systemd/system/paseo.service`, bootstrap.sh:353 era), stops + disables it, verifies the port is free, then installs the user unit. `status` WARNs while a legacy unit exists; verification covers migrated hosts.
- R23. (P1-4) Linger ownership: `dev-stack.sh startup install -a paseo` attempts `loginctl enable-linger TARGET` when privileged and verifies `loginctl show-user TARGET`; when unprivileged and linger is off, it records exit 3 (blocker) with the exact one-time remediation instead of a WARN-only pass.
- R24. (P1-5) Prereq semantics: `check-prereqs install` installs `curl`, `git`, `bubblewrap`, `uv` via apt where missing; verifies `node`/`npm` (22+) and reports AVX. Missing Node/npm/AVX and Docker are exit-3 blockers with remediation (NodeSource instructions, Proxmox `x86-64-v3` CPU note) - the installer does not provision Node or Docker itself. All apt paths use `sudo`, logged, dry-run aware.
- R25. (P1-7) Flag mapping (exhaustive): `--skip-agents` skips `install-{claude,codex,gh}` only; `--skip-paseo` skips dev-stack Paseo + Paseo seed + user-unit startup; `--skip-dotfiles` skips `setup-env install` AND requires pre-existing env (guard exit 3 otherwise, documented as a precondition, not a silent pass); `--skip-services` skips `startup install` + `start` only. `--dry-run` passes through to every child.
- R26. (P1-8) External sources: bootstrap acquires `external/` checkouts (via `tooling/sources/clone-*.sh` / `update-external-repos.sh`) before invoking CE/knowledge skill installers; when sources are absent and unacquirable (offline), skills record WARN + exit 1 (not 0) and the run surfaces it. No clean-bootstrap pass depends on unreachable state.
- R28. (P1-11) Paseo fail-closed: the `0.0.0.0:6767` bind requires `PASEO_PASSWORD` set (exit 3 otherwise - no open remote daemon). The user unit loads a Paseo-specific allowlist (`PASEO_PASSWORD`, `PASEO_HOME`, plus base env), never the whole secrets file with unrelated credentials.
- R29. (P1-12) Schema migration: Paseo seed/reconcile is an additive, versioned merge supporting the tracked template and live 0.4.0+ (`daemon.listen`, no `features.webUi` key): preserves `daemon.auth.password`, provider keys, runtime fields, and user overrides; patches only `listen`/web-UI launch flags. Never overwrites a password-bearing config from template.
- R31. (P1-14) Offline/network contract: registry lookups record exit 3 (not suppressed) when the registry is unreachable; remote installers use HTTPS + `curl -f` + timeouts; apt repos verify keys (existing keyring path); `status` distinguishes drift (1) from indeterminate-offline (3).
- R32. (P1-15) Node path provisioning: `tooling/bin/userspace-shims.sh` (user-owned npm prefix + `~/.local/node-bin` symlinks) runs before the rootless unit install; fresh verification asserts `%h/.local/bin/paseo` resolves. No unit assumes an unprovisioned path.

### Scope Boundaries

**In scope:** New machine installers (incl. `install-codex-cli.sh` retrofit for R9-R11: named verbs, `-f/-q/--dry-run`, no trailing-flag execution, dry-run-safe sudo), bootstrap thinning, marker log + `flock` finalization, env guard + grammar/perms wiring, legacy unit migration + linger, Paseo seed additive merge + fail-closed bind, skills/external-source ordering, contract fixes blocking orchestration (dev-stack status exit, startup parse, dry-run write-free incl. children, skill no-op + rm-rf removal, quiet/JSON consent split, exit-2 normalization, update-external-repos + record-external propagation, /dev/tty hangs), skill-family extension, docs.

**Out of scope:** Windows `*.ps1` parity, Paseo daemon behavior changes, secret rotation, non-bash shells, provisioning Node/Docker themselves (remediation only).

---

## Planning Contract

### Key Technical Decisions

- KTD1. Thin orchestrator: bootstrap keeps arg parsing (`--user/--skip-*/--force/--dry-run`) + ordered calls only; passes `-f/-q/--dry-run` through to every child. (settled: user-directed)
- KTD2. Two-layer contract (universal + reconciler) over forcing `status/install` on every helper; internal recorders stay verb-free. (agent-recommended, adopted)
- KTD3. Marker lives in `~/.config/heypogi/` (owned by setup-env flow, XDG-consistent) not `/var/log` or repo dir. (settled)
- KTD4. Guard is a sourced snippet, not a binary gate, so non-login shells (systemd, cron) self-heal by sourcing env files first - subject to R30 grammar/perm checks. (amended post-review)
- KTD5. User systemd unit wins over system unit: rootless, `EnvironmentFile=` allowlist (R28), `linger` owned per R23, legacy system unit migrated per R22. (D8, amended post-review)
- KTD6. (P0-2) `--user` execution model: resolve TARGET_UID/HOME/XDG at bootstrap start; run leaf installers as TARGET (`sudo -u`/`setpriv`); narrow `sudo` allowlist (apt, linger, legacy-unit removal) logged + dry-run aware. Guard validates post-switch context, not the caller's.
- KTD7. (P0-1) Env-first ordering: `setup-env install` runs before all guard-dependent installers; guard hard-fails everywhere else. Dry-run has no env to source, so children run in plan-only mode and the guard checks argv-declared intent rather than live files.
- KTD8. (P1-10) Skill placement: extend the existing `src/skills/script-contract` (+ `bash-script-contract` for Bash specifics) instead of creating `shell-script-contract`; the agent draft from the 18-script review (source: handoff agent 54d34675, 2026-09-07) is the content input. `AGENTS.md` script-work routing stays canonical.

### High-Level Technical Design

- Call order: `setup-env install -> check-prereqs install -> userspace-shims -> install-{claude,codex,gh} install -> external sources acquire -> dev-stack install (incl. Paseo additive seed) -> skills install-* -> dev-stack startup install (legacy migrate + linger) + start -> write marker`.
- Flag mapping per R25; `--skip-dotfiles` without pre-existing env is exit 3, not a pass.
- Marker write is last via `ERR`/exit trap with `flock` serialization (R27); records exit code on success and failure; skipped under `--dry-run`; marker-write failure is WARN-only (R16).
- Guard sourced at top of each dependent after arg parsing, before state changes; in dry-run plan mode it validates declared intent.

### Product Contract preservation

- Stable IDs R1-R20 / U1-U5 / KTD1-KTD5 preserved; review additions are R21-R32 / KTD6-KTD8 (additive, no renames or deletions).

---

## Implementation Units

### U1. Machine installers + prereq checker
- **Goal:** Fill `tooling/machine/` gaps + retrofit Codex to contract.
- **Requirements:** R1, R2, R3, R4, R9-R13, R21, R24, R31
- **Files:** `tooling/machine/check-prereqs.sh` (new), `tooling/machine/install-claude-cli.sh` (new), `tooling/machine/install-gh-cli.sh` (new), `tooling/machine/install-codex-cli.sh` (retrofit: named verbs, `-f/-q/--dry-run`, trailing-flag rejection, dry-run-safe sudo/`curl|sh`)
- **Approach:** Mirror `install-codex-cli.sh status/install` shape; Claude carries `timeout 90` + remediation; gh carries apt repo logic; prereqs checks bins + AVX, installs curl/git/bwrap/uv, blockers (Node/npm/AVX/Docker) exit 3 with remediation. All honor R21 target-user context.

### U2. Env + guard
- **Goal:** setup-env owns env; dependents gate on it safely.
- **Requirements:** R5, R18, R19, R20, R25, R30
- **Files:** `tooling/env/setup-env.sh` (add `status/install`, keep idempotency), `tooling/env/require-env.sh` (new, grammar + perm checks)
- **Approach:** `status` verifies files + marker block + perms/ownership; `install` = current behavior; guard sources files then checks `HEYPOGI_ROOT`, `OPENCODE_CONFIG_DIR`, `tooling/bin` on `PATH`. Bootstrap calls `setup-env install` first (KTD7).

### U3. Skills + Paseo/dev-stack ownership
- **Goal:** Remove duplication in steps 4-6; own Paseo lifecycle end-to-end.
- **Requirements:** R6, R7, R8, R22, R23, R26, R28, R29, R32
- **Files:** `tooling/sources/clone-*.sh` + `update-external-repos.sh` (acquire ordering, failure propagation), `tooling/skills/install-*.sh` (add `status/install`, correct-symlink no-op, drop `rm -rf`), `tooling/bin/userspace-shims.sh` (provision before unit), `tooling/dev-stack/dev-stack.sh` (Paseo additive seed, legacy migration, linger ownership, `status` exit + `startup` parse + dry-run flag, secrets allowlist)
- **Approach:** External sources before skills; Paseo seed additive-merged (R29), fail-closed bind (R28); legacy system unit migrated (R22); linger owned (R23).

### U4. Bootstrap thinning + marker + target context
- **Goal:** Orchestrator + run history + `--user` model.
- **Requirements:** R14, R15, R16, R17, R21, R25, R27
- **Files:** `bootstrap/bootstrap.sh`
- **Approach:** Env-first ordered calls per HLD; R25 flag mapping; R21 target-context resolution + narrow sudo; `status` verb; `flock`-serialized trap-based marker finalization (skipped under `--dry-run`).

### U5. Contract hardening + skill-family extension + docs
- **Goal:** Baseline compliance + durable standard in the canonical place.
- **Requirements:** R9-R13
- **Files:** `src/skills/script-contract/*` + `src/skills/bash-script-contract/*` (extend from agent-54d34675 draft), `bootstrap/README.md`, `tooling/README.md`, `bootstrap/OPENITEMS.md`, `docs/open_items_register.md`
- **Approach:** Apply contract retrofits enumerated in Scope (dev-stack, skills, update-external-repos/record-external, /dev/tty, quiet/JSON, exit-2); record skill delta; update docs to ownership map. Source draft: handoff agent 54d34675 output (2026-09-07), not an unlinked report.

---

## Verification Contract

| Check | Command | Expected |
|---|---|---|
| Static | `bash -n` all touched scripts (+ ShellCheck where available) | Exit 0 |
| Fresh | `bootstrap.sh --force` on clean VM | Converges from zero, no guard self-block, marker written |
| Fresh offline | no network; `bootstrap.sh --force` | Exit 3 with remediation at first network-dependent unit, no partial mutation past the blocker |
| Skip matrix | each `--skip-*` combo per R25 | Skipped subset untouched; `--skip-dotfiles` on clean env exits 3 |
| Idempotent | run twice | Second run no state writes (marker excepted per R27), exit 0 |
| Dry-run | `bootstrap.sh --dry-run` (+ each child `--dry-run`) | Zero writes incl. marker/logs/children; Codex dry-run performs no sudo/network |
| Status semantics | `<script> status; echo $?` per child | 0 converged / 1 drift / 2 bad invocation / 3 blocked |
| Malformed invocation | unknown flag, missing value per child | Exit 2, no mutation |
| Quiet/consent | `-q` on conflicted state per child | No implicit consent; prompts fail with remediation non-interactively |
| Guard | unset `HEYPOGI_ROOT`; `dev-stack.sh status` | Exit 3 + remediation, no mutation |
| Guard malformed | malformed/mis-owned env file; guarded script | Exit 3, file never sourced |
| Target user | `bootstrap.sh --user X --dry-run` + real run | All user-scoped state lands in `~X`; no root-owned leaves |
| Legacy migration | host with system unit; `startup install -a paseo` | Legacy stopped/disabled, port free, user unit active, `status` clean |
| Linger | unprivileged, linger off; `startup install -a paseo` | Exit 3 + one-time remediation (or owned enable when privileged) |
| Paseo closed | no `PASEO_PASSWORD`; start with `0.0.0.0` | Refuses bind, exit 3; unit loads allowlist only |
| Node path | fresh; `dev-stack.sh startup install -a paseo` | `%h/.local/bin/paseo` resolves before unit enable |
| Skills external | absent `external/`; offline | WARN + exit 1 surfaced, clean failure (no silent pass) |
| Marker | kill -9 a child mid-run; concurrent runs | Marker records real exit; log tail equals last-run file |
| Schema merge | seeded 0.4.0 config with password; reconcile | Password/providers/runtime preserved, `listen` converged |

---

## Definition of Done

- Bootstrap has no inline install logic; all 8 delegation decisions implemented in env-first order with R25 flag mapping and R21 target context.
- Every bootstrap-callable script (incl. retrofitted Codex) supports `status/install` + `-f/-q/--dry-run` + exit 0/1/2/3; no child mutates under dry-run.
- Marker log + last-run file written on every real run via trap + `flock`; `status` surfaces last run; marker is the sole idempotency exception.
- Dependents source `require-env.sh` (grammar + perm checked) and fail fast exit 3 when base env missing; `--skip-dotfiles` without env is a documented precondition failure.
- Legacy system unit migrated; linger owned; Paseo fail-closed with secrets allowlist; schema merge preserves passwords.
- Skill-family extended in canonical paths; READMEs + OPENITEMS + open-items register updated.

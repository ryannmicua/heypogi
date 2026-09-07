---
name: bash-script-contract
description: Apply heypogi's Bash-specific standards when writing, updating, reviewing, or advising on Bash and .sh scripts. Also use when a scripting request may reasonably be implemented in Bash. Use together with the language-independent script-contract skill.
---

# Bash Script Contract

Specialize the general script contract for Bash. Do not apply this profile without the general standard.

## Required preparation

1. Use `script-contract` and read the canonical [general script standard](../../../docs/standards/scripts.md) completely.
2. Read the canonical [Bash script standard](../../../docs/standards/bash-scripts.md) completely.
3. Read the applicable `AGENTS.md`, target script, callers, adjacent documentation, and related tests.

Both standards are normative. Apply the general standard first; the Bash profile adds exact Bash conventions and may strengthen but never weaken it.

## Apply the Bash profile

Determine whether the script is an orchestrator, reconciler, read-only check, or action/helper. Apply the profile's exact CLI spellings, exit codes, read-only default, idempotency, logging, preview, prompt, privilege, quoting, path, subprocess, and destructive-operation rules.

For reconcilers, require the common `status` and `install` interface. Do not add meaningless lifecycle verbs to read-only checks or internal helpers; apply their relevant universal Bash requirements instead.

When writing or updating, validate syntax and run ShellCheck when available, then test behavior proportionally to risk and the user's authorization. Prove that dry-run blocks every mutation and that a second successful install is unchanged.

When reviewing, trace strict-mode edge cases, pipelines, expected failures, subshell scope, argument-value handling, cleanup status, and child failure propagation in addition to the general review. Report findings with file and line evidence.

Do not run an installer, service action, network mutation, or destructive test during a review unless the user explicitly authorized it.

## Heypogi Bash reconciliation profile (bootstrap refactor, 2026-09-07)

Bootstrap-callable reconcilers support exactly:

```bash
script status  [-q|--quiet] [-h|--help]
script install [-f|--force] [-q|--quiet] [--dry-run] [-h|--help]
```

with `status` as the read-only default. Apply these mechanically:

- Parse and validate the full command line before any probe with side
  effects, network access, or mutation. Unknown options, missing values,
  and extra positionals exit 2. Trailing flags after a verb are rejected,
  not silently ignored.
- `-q`/`--quiet` suppresses INFO/OK only (WARN/ERROR still shown) and
  never implies consent. Non-interactive execution without `--force`
  fails promptly with remediation instead of prompting, hanging on
  `/dev/tty`, or assuming yes. Prompts read stdin only when it is a
  terminal and default to no.
- `--dry-run` blocks every mutation through the single execution
  boundary: files, permissions, backups, logs, packages, git operations,
  service changes, credentials, and mutating child scripts (which receive
  `--dry-run`). Sudo and remote installers print instead of running.
- Exit 0/1/2/3 per the general skill's result model. Capture child
  status before summaries or cleanup; no `|| true` around the final
  result. Declining required work is 1; unreachable registries and
  missing unprovisionable prerequisites (Node.js, Docker, AVX, offline)
  are 3 with remediation.
- Correct symlinks are no-ops; conflicting directories are never
  `rm -rf`'d (not even with `-f`); generated files are replaced
  atomically (temp + `mv`); secret-bearing and user-maintained files are
  preserved by default.
- Dependents source `tooling/env/require-env.sh` after arg parsing and
  before mutation. Env files are grammar-checked (`KEY=value`, no
  `export`, no command substitution, no backticks) and
  ownership/permission-checked before sourcing; violations are exit 3
  and the file is never sourced. Under `--dry-run` the guard runs in
  plan-only mode and never fails on missing live files.
- Target-user scripts stay HOME-relative and never elevate wholesale;
  the orchestrator drops privilege (`sudo -u TARGET`) and supplies
  `HOME`, `XDG_RUNTIME_DIR=/run/user/<uid>`, and a userspace-first
  `PATH`. Machine installers log each sudo invocation before execution.

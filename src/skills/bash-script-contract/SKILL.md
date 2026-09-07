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

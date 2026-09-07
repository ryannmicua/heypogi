# Bash Script Standard

This is the normative Bash profile for the repository's [general script standard](scripts.md). Read and apply the general standard first. This document maps its capabilities to exact Bash conventions and adds Bash-specific safety requirements.

## Scope

Apply this profile to:

- Files with a Bash shebang.
- `.sh` command-line scripts unless explicitly written for another shell.
- Shell entrypoints implemented in Bash.
- Proposed automation when Bash is a plausible implementation language.

If portability to POSIX `sh` is required, document that choice and use a separate POSIX-compatible profile rather than silently mixing Bash syntax with `/bin/sh`.

## Runtime baseline

Every Bash command-line script must begin with:

```bash
#!/usr/bin/env bash
set -euo pipefail
```

Strict mode is a baseline, not a substitute for explicit error handling. Commands used as tests, expected-failure probes, pipeline stages, cleanup, or status aggregation must handle their results intentionally.

Resolve script-relative paths from `BASH_SOURCE[0]`, not the caller's current directory. Quote path expansions.

## Exact CLI contract

Every Bash command-line script must accept:

- `-h` and `--help`
- `-q` and `--quiet`
- `--dry-run`

A read-only script may implement `--dry-run` as an explicitly documented no-op. A script that can prompt, overwrite, replace, stop, restart, or delete must also accept:

- `-f` and `--force`

Do not silently accept an option that has no implemented behavior. Do not use quiet as an alias for force or non-interactive consent.

Parse all arguments before performing dependency probes with side effects, network access, or mutations. Before consuming an option value, verify that it exists and is not another option when appropriate. Unexpected positional arguments and invalid combinations exit 2.

The help function must print and return; the caller decides its exit status. This prevents an unknown-argument branch from accidentally exiting 0 through a help function that always terminates successfully.

### Reconciler commands

A Bash reconciler exposes:

```text
script status  [-q|--quiet] [-h|--help]
script install [-f|--force] [-q|--quiet] [--dry-run] [-h|--help]
```

No command defaults to `status`.

- `status` is strictly read-only and covers all intended state owned by the script.
- `install` performs first installation, update, and repair idempotently.
- `update` may be an alias for `install`, but must not have different semantics.
- Additional commands such as `start`, `stop`, `restart`, `fix`, `startup`, and `uninstall` are script-specific.

Bootstrap-callable reconcilers must support the exact common invocations:

```bash
script status --quiet
script install --force --quiet
script install --force --quiet --dry-run
```

## Exit codes

Use this exact map at the public command boundary:

| Code | Meaning |
|---:|---|
| `0` | Requested action succeeded, or status confirms intended state. |
| `1` | Intended state is not met, or the requested mutation failed, was declined, or remained partial. |
| `2` | Invalid command line or input syntax. |
| `3` | Verification is indeterminate or work is blocked by an unavailable external prerequisite. |
| `128+N` | Process terminated by signal `N`. |

Do not use exit 2 for network, dependency, or parsing failures encountered while inspecting otherwise valid input; those are exit 3 when they prevent a reliable determination.

Capture a failing child status before running summaries or cleanup that could replace `$?`. Do not place `|| true` around the final status result. If multiple targets are processed, aggregate their results and return the most relevant nonzero category.

An operator declining required work returns 1. Skipping an optional target may return 0 only when the requested contract remains satisfied.

## Output helpers

Use `printf`, not `echo -e`. Implement semantic helpers whose plain output is stable:

```text
INFO: message
OK: message
WARN: message
ERROR: message
DRY-RUN: command or action
```

- Send `INFO` and `OK` to stdout unless quiet.
- Send `WARN` and `ERROR` to stderr even in quiet mode.
- Send prompts to stderr.
- Enable ANSI color only when the destination file descriptor is a terminal and `NO_COLOR` is unset.
- Do not embed color codes in structured output, redirected output, or logs.
- Quote a displayed command safely, but redact secret-bearing arguments and environment assignments.

If `--json` exists, generate valid JSON with a proper serializer whenever values can contain arbitrary text. JSON stdout must contain JSON only; progress and diagnostics go to stderr. `--json` must not imply overwrite, automatic selection, or force.

## Dry-run implementation

Initialize dry-run before dispatch and route every persistent mutation through a single execution boundary or an equally auditable mechanism. Cover:

- File and directory creation, replacement, permission, and ownership changes.
- Backups, logs, caches, and metadata/status files.
- Package managers and remote installers.
- Git clone, fetch, pull, checkout, reset, and configuration changes.
- Service start, stop, restart, enable, disable, and reload.
- Cron and scheduled-task changes.
- Credential, profile, environment, and global tool configuration.
- Mutating child scripts, which must receive `--dry-run`.

Printing a command without executing it is not sufficient if surrounding setup still writes. A dry run may perform read-only probes, but network probes must be finite and must not download or install artifacts.

## Bash idempotency patterns

- Compare file content before replacement with an appropriate exact comparison.
- Treat a symlink as correct only when its resolved intended target is correct.
- For marker-bounded edits, require exactly one valid start/end pair before replacement. Reject malformed or partial markers rather than appending a duplicate block.
- Reconcile a cron or configuration entry by a stable key and replace changed content instead of merely testing for a substring.
- Avoid rewriting an unchanged target, refreshing its timestamp, or creating a backup.
- Use arrays for commands and repeated values. Do not build a shell command string and execute it with `eval`.
- Use `mktemp` and a trap for temporary artifacts. Prefer a temporary file in the destination directory when atomic replacement must remain on one filesystem.
- Preserve the original exit status in cleanup traps.

## Bash safety

### Quoting and expansion

- Quote parameter, command-substitution, and path expansions unless deliberate word splitting is required and documented.
- Use arrays for commands and arguments.
- Use `--` before path operands where supported.
- Avoid unvalidated globs and unresolved environment variables for destructive targets.
- Validate enumerated inputs with `case`; validate structured input with a real parser.
- Do not source untrusted data as shell code.
- Do not use `eval` to parse JSON, manifests, configuration, or user input.

### Pipelines and expected failures

- Under `pipefail`, explicitly handle probes that may legitimately find nothing.
- Do not append a fallback that converts a required failure into success.
- Capture pipeline output and status separately when both matter.
- Be deliberate about subshell scope when counters or state must survive a loop.

### Paths and deletion

Before `rm`, recursive operations, `mv`, `chmod`, `chown`, or link replacement:

- Resolve the target without relying on `eval` or unsafe textual expansion.
- Confirm it is non-empty and inside the documented managed directory.
- Reject `/`, `$HOME`, the repository root, and the managed directory itself when only a child is expected.
- Inspect whether it is a file, directory, or link and handle only expected kinds.
- Never use `rm -rf` as generic conflict resolution.

### Privilege boundaries

Userspace scripts must not call `sudo`, `su`, or equivalent elevation. This includes environment, skills, source, user-service, and user-level development-stack scripts.

A machine prerequisite installer may call narrowly scoped `sudo` commands. It must document each privileged category, show the action before execution, honor dry-run, and leave subsequent user-owned installation running as the target user.

### External commands

- Check required commands before mutation and report all missing prerequisites where practical.
- Put finite timeouts on network and potentially interactive commands.
- Use fail-fast download options.
- When piping a vendor installer to a shell, document the source, bound the download and installer, and verify the installed executable and required smoke tests afterward.
- A vendor installer timeout or incomplete post-install TUI returns nonzero when required state is absent.

## Prompts

Use the process's existing terminal. Do not read `/dev/tty` to bypass redirected or absent stdin.

If stdin is not interactive:

- Complete only when explicit arguments provide everything required and no unresolved conflict remains.
- Otherwise exit promptly with 1 or 3 as appropriate and print the exact remediation.

Conflict and destructive prompts default to no. `--force` skips only prompts for the declared operation and target. `--quiet` never changes the answer.

## Script-specific options

Keep domain inputs outside the common contract. Examples include application selectors, source paths, usernames, age thresholds, identity settings, and structured-output flags.

- `-a/--app` belongs to a multi-application supervisor.
- `--user` and `--skip-*` belong to an orchestrator.
- `--json` belongs only where a machine-readable consumer exists.
- `--create-dest` is not a baseline option; creating a managed parent directory is normally part of install.
- `--verify-only` and `--status` should become the `status` command on reconcilers.
- `--auto` and `--yes` should normally become explicit `install --force`; quiet remains independent.
- Destructive config removal requires a separate option such as `--wipe-config` in addition to an explicit uninstall target.

## Verification

At minimum, run static validation on every changed Bash script:

```bash
bash -n path/to/script.sh
shellcheck path/to/script.sh
```

If ShellCheck is unavailable, report that explicitly rather than claiming it passed.

Test behavior proportionally to risk:

1. Help and every malformed invocation class.
2. No-command read-only default.
3. Status when compliant, drifted, and indeterminate.
4. Dry-run with filesystem and relevant system state compared before and after.
5. First install and an unchanged second install.
6. Conflict, operator decline, force, and non-interactive execution.
7. Partial failure and child failure propagation.
8. Secret redaction and privilege boundaries.

Do not run a mutating test merely because a script was reviewed. Match test side effects to the user's authorization.

## Bash review checklist

- [ ] General script standard was read and applied first.
- [ ] Bash shebang and strict mode are present.
- [ ] Script-relative paths use `BASH_SOURCE[0]` and quoted expansions.
- [ ] Help, quiet, dry-run, and conditional force have the exact common spellings.
- [ ] Argument values and combinations are validated before mutation.
- [ ] Reconciler defaults to status and exposes exact `status` and `install` commands.
- [ ] Exit 0/1/2/3 semantics are preserved through children, cleanup, and summaries.
- [ ] Quiet does not imply force; JSON or another output mode does not change behavior.
- [ ] All mutations, including logs and child scripts, are blocked in dry-run.
- [ ] A second install performs no unnecessary write, backup, restart, or prompt.
- [ ] User-maintained, secret-bearing, runtime, and generated files are treated differently.
- [ ] Prompts do not use `/dev/tty` and cannot hang non-interactive callers.
- [ ] Userspace operations do not call sudo.
- [ ] Commands use arrays and quoting; untrusted inputs are not sourced or evaluated.
- [ ] Destructive paths are resolved, constrained, and type-checked.
- [ ] Network and interactive subprocesses have finite failure behavior.
- [ ] `bash -n` passes and ShellCheck passes or its absence is reported.

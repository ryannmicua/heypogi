# Script Standard

This is the normative, language-independent standard for command-line scripts in this repository. Language-specific standards inherit it and define exact syntax and platform conventions. They may strengthen this standard but must not weaken it.

The words **must**, **must not**, **should**, and **may** are normative.

## Scope

Apply this standard when writing, updating, or reviewing a script in any language, and when turning commands, setup steps, provisioning, maintenance, or operational behavior into a script.

A file used only as an imported library and not runnable from a command line is exempt from CLI flags, help, and exit-code requirements. It still follows the safety, logging, secret-handling, and idempotency rules that apply to its behavior.

## Classify the script

Classify a script before designing its interface:

- **Orchestrator:** sequences other scripts and owns ordering, selection, aggregation, and summaries. It must not duplicate leaf implementation.
- **Reconciler:** owns durable desired state such as an installation, generated configuration, link, registration, or service.
- **Read-only check:** observes and reports state without changing it.
- **Action/helper:** performs one bounded operation, often for another script.

Classification determines which lifecycle commands make sense. Do not add meaningless lifecycle verbs to a read-only check or internal helper.

## CLI contract

Every command-line script must:

- Provide side-effect-free help.
- Reject unknown options, missing option values, invalid combinations, invalid input syntax, and unexpected positional arguments before mutation begins.
- Keep output control separate from authorization. Quiet or structured-output modes must never imply consent.
- Document its defaults, commands or modes, options, managed paths, network effects, privilege requirements, destructive behavior, and exit semantics.
- Use stable option names within its language ecosystem and maintain backward compatibility deliberately rather than accidentally accepting ignored arguments.

Every command-line script must provide a quiet mode. Quiet mode suppresses informational and success chatter but retains warnings, errors, and a concise final result.

Every mutating command-line script must provide a preview mode. Preview must produce a complete plan without persistent changes. This includes no created directories, files, backups, logs, caches, status records, service changes, package changes, repository updates, credential changes, or mutating child commands. A read-only script may accept preview as a documented no-op when uniform callers benefit from it.

Scripts that may prompt, overwrite, replace, stop, restart, or remove state must provide an explicit force/confirmation-bypass option. Force applies only to the declared targets of the requested operation. It must not broaden scope or implicitly authorize deleting secrets, wiping user configuration, or removing an unexpected object.

### Reconciler lifecycle

A reconciler must expose two semantic operations using the exact spelling defined by its language standard:

- **Status:** read-only verification of all intended state the script owns.
- **Install:** converge first installation, update, and repair to intended state.

No operation supplied must default to the read-only status operation. Additional lifecycle operations such as start, stop, restart, repair, or uninstall are domain-specific.

An orchestrator must call leaf reconcilers through these operations and propagate preview, quiet, force, and failure semantics. It must not reimplement their installation or configuration logic.

## Result semantics

Language profiles must map these outcomes to exact exit codes or the closest native equivalent:

- **Success:** the requested operation completed or status confirmed intended state. An already-correct no-op is success.
- **Drift or failure:** intended state is not met, the requested mutation failed, the operator declined a required change, or work completed only partially.
- **Invocation error:** the CLI or input syntax is invalid.
- **Indeterminate or blocked:** state could not be determined, or an external prerequisite such as network, registry, dependency, privilege, or service availability prevented evaluation.
- **Interrupted:** preserve the platform's conventional signal or cancellation result.

Warnings about optional conditions may still produce success. Required-state failures must not be downgraded to warnings. A final summary, cleanup command, logger, or permissive error handler must not erase a failure.

Preview succeeds when a complete valid plan was produced. It reports drift/failure for a known unresolvable conflict, invocation error for bad input, and indeterminate/blocked when it cannot calculate the plan.

## Idempotency and convergence

Reconciler install operations must be safe to repeat and must converge:

- Compare observed and desired state before writing.
- Treat already-correct state as success without rewriting, restarting, touching timestamps, creating backups, or prompting.
- Make a retry safe after interruption or partial failure.
- Reconcile keyed registrations such as scheduled tasks or cron entries rather than detecting a loose substring or adding duplicates.
- Check installed versions and verify executable behavior when installation success depends on more than file presence.
- Do not use output suppression or unconditional error ignoring to manufacture idempotency.

Classify each managed target:

- **Generated and script-owned:** may be replaced atomically when content differs.
- **User-maintained:** preserve by default; require explicit conflict handling to replace.
- **Secret-bearing:** never overwrite, expose, or derive from a tracked placeholder by default.
- **Runtime state:** preserve unless an explicit lifecycle command targets it.
- **External registration or link:** verify both identity and target before changing it.

Create expected parent directories during install when they fall inside the documented managed scope. Do not require a generic creation flag solely to perform an ordinary part of an authorized install.

Use an atomic replacement where practical: create a temporary object in the destination filesystem, set required permissions, then replace the target. Preserve required ownership and permissions. Back up a user-maintained conflict before an explicitly authorized replacement.

## Logging and output

Human-readable output must have stable semantic levels independent of color:

- `INFO` for progress or context.
- `OK` for successful or already-correct state.
- `WARN` for recoverable or optional concerns.
- `ERROR` for failed required state or operations.
- `DRY-RUN` for actions that would occur in preview mode.

Normal results go to standard output. Warnings, errors, prompts, and diagnostics go to standard error. Color is decoration only, must be disabled for non-interactive output, and must honor `NO_COLOR` where the environment supports it.

Do not print secret values, tokens, passwords, private-key content, credential-bearing URLs, or command lines containing secrets. Debug tracing must be disabled around any sensitive operation.

If a script offers structured output:

- Standard output must contain exactly one valid structured document or stream as documented.
- Diagnostics must go to standard error.
- Color must be disabled.
- Exit semantics must remain unchanged.
- The output mode must not alter target selection, prompting, overwrite, or force behavior.
- Values must be escaped by an appropriate serializer rather than hand-built when input can contain arbitrary text.

Persistent log files are part of the script's managed state. Their location, retention, permissions, and secret policy must be documented. Preview mode must not create or append to them.

## Prompts and non-interactive execution

- Prompt only when an interactive terminal is available.
- Conflict and destructive prompts must default to no.
- Quiet mode must never answer a prompt.
- In non-interactive execution, either complete from explicit inputs or fail promptly with a remediation message.
- Do not open a controlling terminal behind the caller's back.
- Bound vendor installers and other interactive subprocesses with a timeout when they can hang.
- A timeout that leaves required state incomplete is a failure, not a successful warning.

## Safety

### Default and scope

- Default invocation must be read-only.
- Validate the complete request and resolve all targets before making the first change.
- Operate only on documented targets. Force does not authorize scope expansion.
- Avoid destructive defaults. Removal requires an explicit operation and explicit target.
- Deleting user configuration, secrets, or runtime data requires a separate explicit option beyond uninstalling software or registration.

### Paths and destructive operations

- Resolve and validate paths before delete, move, permission, ownership, or recursive operations.
- Reject empty, root, home, repository-root, unresolved-variable, wildcard-expanded, and out-of-scope destructive targets.
- Treat an unexpected file type as a conflict. Do not recursively delete a directory merely to replace it with a file or link.
- Prefer recoverable replacement and targeted deletion over recursive deletion.
- Clean temporary artifacts with a reliable cleanup mechanism without hiding the original exit result.

### Privileges

- Run with the least privilege required.
- A userspace script must not invoke privilege elevation.
- A machine prerequisite installer may use narrowly scoped elevated commands when they are documented, visibly logged, and honored by preview mode.
- Do not run an entire userspace installer as an elevated user because one prerequisite requires elevation.
- Keep root-owned and user-owned changes in separate leaf operations where practical.

### Inputs and subprocesses

- Quote and validate external input according to the implementation language.
- Avoid dynamic code evaluation for configuration or structured data. Use arrays, argument objects, or a real parser.
- Preserve child failure unless deliberately translating it into the documented result model.
- Apply finite timeouts and failure handling to network operations.
- Use authenticated transport. Prefer pinned versions and verified artifacts where feasible.
- When executing a vendor-provided remote installer, document the trust boundary, use fail-fast download behavior and timeouts, and verify the resulting installation.
- Protect concurrent writes with atomic operations or locking when concurrent execution could corrupt shared state.

## Documentation requirements

Help and adjacent documentation must agree with implementation. Document:

- Purpose and ownership boundary.
- Synopsis and examples.
- Commands or modes and their defaults.
- Common and script-specific options.
- Managed files, links, registrations, services, packages, and logs.
- Idempotency and overwrite policy.
- Interactive and non-interactive behavior.
- Privilege and network requirements.
- Exit/result semantics.
- Destructive operations and recovery or backup behavior.

Repository documentation should link to this standard rather than copy it. Language-specific standards should contain only inherited clarifications and language-specific requirements.

## Review checklist

### Interface

- [ ] The script is classified as orchestrator, reconciler, read-only check, or action/helper.
- [ ] Help is accurate, side-effect-free, and successful.
- [ ] Unknown options, missing values, invalid combinations, and extra arguments fail before mutation.
- [ ] Quiet controls output only.
- [ ] Every mutation is blocked in preview mode, including child mutations and persistent logging.
- [ ] Reconciler status and install operations follow the language profile and default to status.
- [ ] Script-specific options remain orthogonal to quiet, preview, force, and output format.

### Results

- [ ] Intended state produces success only when all required checks pass.
- [ ] Drift, declined required work, mutation failure, and partial completion fail.
- [ ] Invocation errors and indeterminate conditions are distinguishable.
- [ ] Child failures propagate or are deliberately translated.
- [ ] Cleanup, summaries, and logs preserve the original result.

### Idempotency

- [ ] A second successful install performs no unnecessary write, backup, restart, prompt, or timestamp change.
- [ ] Correct links, files, packages, services, and registrations are unchanged successes.
- [ ] Generated, user-maintained, secret-bearing, and runtime targets have distinct policies.
- [ ] Writes are atomic where practical and interrupted runs are safely retryable.
- [ ] Registrations are reconciled without duplication.

### Output

- [ ] Standard output, standard error, quiet behavior, and levels are consistent.
- [ ] Color is terminal-aware and optional.
- [ ] Structured output is pure, correctly serialized, and does not change safety behavior.
- [ ] Secrets and sensitive command lines are never logged.

### Safety

- [ ] Default behavior is read-only.
- [ ] Targets and privileges are narrow and documented.
- [ ] Userspace operations do not elevate privileges.
- [ ] Prompts are terminal-aware, default safely, and cannot hang automation.
- [ ] Destructive behavior requires an explicit operation and target.
- [ ] Force cannot implicitly wipe configuration, secrets, or unexpected paths.
- [ ] Paths are resolved and constrained before destructive operations.
- [ ] Dynamic evaluation, unbounded waits, and unverified child success are absent.

### Verification

- [ ] Static syntax and language lint checks pass.
- [ ] Help and malformed invocation are tested.
- [ ] Read-only default and status are tested in compliant, drifted, and indeterminate states.
- [ ] Preview is proven write-free.
- [ ] First install, second install, partial retry, conflict, non-interactive, and child-failure paths are tested proportionally to risk.

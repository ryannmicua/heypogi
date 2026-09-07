---
name: script-contract
description: Write, update, review, or advise on scripts in any language. Use when asked to create or change a script, review an existing script, codify commands or a workflow into a script, automate operational steps, or decide whether something should become a script. Apply the language-independent standard before any language-specific standard.
---

# Script Contract

Apply the repository's language-independent script standard and route to a language-specific profile when one applies.

## Required preparation

1. Read the canonical [general script standard](../../../docs/standards/scripts.md) completely.
2. Locate the target repository root from the target path or version-control metadata.
3. Read the applicable `AGENTS.md`, target script, callers, adjacent documentation, and related tests.
4. Determine the implementation language. If Bash or a `.sh` entrypoint is present or under consideration, also use `bash-script-contract` and read the [Bash script standard](../../../docs/standards/bash-scripts.md) completely.

The standards are normative. Do not duplicate or weaken them in a skill, script, or adjacent document. Script-specific documentation may add compatible domain behavior.

## Apply the standard

Classify the script as an orchestrator, reconciler, read-only check, or action/helper. Identify its callers, managed state, inputs, outputs, failure modes, network effects, privilege boundary, interactive behavior, and destructive scope.

When writing or updating, implement the relevant contract and verify the observable behaviors required by the standard. Preserve the user's language choice unless deciding the language is part of the request.

When reviewing, trace every argument, exit path, mutation, prompt, subprocess, network operation, and privilege change. Report language-independent deviations separately from language-specific deviations, with file and line evidence when available.

When asked whether or how to codify work into a script, first decide whether a script is the right boundary. Prefer a script when the operation needs repeatability, automation, a stable CLI, or reproducible state management. Do not introduce a script when a declarative configuration or existing tool is the clearer owner.

Preserve authorization boundaries: reviewing does not authorize edits or mutating tests, and implementing one script does not authorize unrelated normalization.

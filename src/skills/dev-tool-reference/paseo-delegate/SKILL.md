---
name: paseo-delegate
description: >-
  Delegate a bounded, fully-specified execution task through the Paseo agent
  profile named Implementation. The reverse of paseo-escalate. Use when the reasoning is already done — the plan
  or decision is written down — and the remaining work is implementation that a
  less intelligent model can follow. Not for tasks that still need judgment or
  design decisions.
user-invocable: true
argument-hint: "[execution task or plan reference to delegate]"
---

# Delegate to Execution Workhorse

One Paseo agent using the Implementation profile, fresh context, write-capable. Used when the orchestrator has already done the thinking and hands off bounded execution. The delegated agent does the work; the orchestrator reviews and arbitrates.

This is the **reverse of `paseo-escalate`**: escalate uses Frontier for judgment; delegate uses Implementation for execution.

**User's request:** $ARGUMENTS

## When to use

- **Plan is written, implementation is not** — a plan, spec, or decision artifact exists and the remaining work is mechanical: implement it, verify it, done.
- **Well-bounded implementation** — the task has explicit acceptance criteria, in-scope files, and a defined verify step, with no judgment left to make.
- **Execution handoff** — the caller has chosen to keep judgment in the current session and delegate bounded implementation to the configured Implementation profile.
- **Parallelizable chunks** — independent bounded tasks that can run concurrently without conflicting.

Do NOT use when the task still requires reasoning — if writing the brief would force the executor to make a design decision, the thinking is not done. Resolve it first, then delegate.

## Prerequisites

Read the **paseo** skill. Call `list_profiles`, read each profile's notes,
and select `Implementation`. Use its host-local provider, model, mode, thinking
level, and feature settings. The Paseo skill supplies the asynchronous
creation and notification conventions. Use worktree isolation when multiple
delegated agents run in parallel on the same repo.

## Fixed configuration

- Provider/model and launch settings: use the selected profile. If it has a
  provider but no model, discover an available model for that provider.
- Title: `[Delegate] <topic>`

If `Implementation` is missing, tell the user to run the repository's
`sync-profiles` command (`tooling/dev-stack/dev-stack.sh` or
`tooling/dev-stack/dev-stack.ps1`) on this host, or choose another local
profile. Do not substitute a hardcoded provider or model.

## The delegation brief

The executor has zero context. The brief must be fully self-contained — the executor should never need to make a judgment call. Include:

- **Task** — imperative description of what to implement or change.
- **The plan** — reference the written plan/spec by path and quote its relevant decisions; the executor follows it, it does not re-derive it.
- **Files in scope** — the exact files to create/modify (paths, not prose).
- **Out of scope** — explicit must-not-touch items.
- **Constraints** — conventions to follow (naming, style, structure).
- **Verify step** — the exact command(s) to run and what evidence counts as success (tests, lint, typecheck).
- **Report** — what to return: changed files, verification output, any deviations.

End with an execution authorization, the inverse of the no-edits suffix:

```
This is an execution task. Edit, create, and delete files as needed to complete
the task. Follow the plan exactly. Run the verification steps and report the
evidence.
```

## Launch and review

Create the delegated agent via Paseo with a `[Delegate] <topic>` title, the brief as the initial prompt, and the settings above. Wait for it to finish. Read its response and review the diff **against the plan** — flag drift, skipped pieces, or unverified claims. Apply any needed follow-up yourself or send a follow-up prompt to the same agent. The orchestrator remains the arbiter; the delegated agent does not decide.

Archive the agent when done, or keep it for follow-ups if the task is still open.

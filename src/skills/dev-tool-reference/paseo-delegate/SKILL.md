---
name: paseo-delegate
description: >-
  Delegate a bounded, fully-specified execution task from a frontier-model
  orchestrator down to the mimo-v2.5 workhorse (opencode) via Paseo. The
  reverse of paseo-escalate. Use when the reasoning is already done — the plan
  or decision is written down — and the remaining work is implementation that a
  less intelligent model can follow. Not for tasks that still need judgment or
  design decisions.
user-invocable: true
argument-hint: "[execution task or plan reference to delegate]"
---

# Delegate to Execution Workhorse

One Paseo agent on **opencode mimo-v2.5 at max reasoning**, fresh context, write-capable. Used when the frontier-model orchestrator has already done the thinking and hands the execution to a cheaper, less intelligent model that can follow the written plan. The delegated agent does the work; the orchestrator reviews and arbitrates.

This is the **reverse of `paseo-escalate`**: escalate sends judgment *up* to a frontier model; delegate sends execution *down* to the workhorse.

**User's request:** $ARGUMENTS

## When to use

- **Plan is written, implementation is not** — a plan, spec, or decision artifact exists and the remaining work is mechanical: implement it, verify it, done.
- **Well-bounded implementation** — the task has explicit acceptance criteria, in-scope files, and a defined verify step, with no judgment left to make.
- **Frontier session, execution volume** — you're operating on a frontier model (codex/gpt-5.6-sol, claude fable/opus) and want to keep cheap execution off your expensive session.
- **Parallelizable chunks** — independent bounded tasks that can run concurrently without conflicting.

Do NOT use when the task still requires reasoning — if writing the brief would force the executor to make a design decision, the thinking is not done. Resolve it first, then delegate.

## Prerequisites

Read the **paseo** skill. This skill hardcodes the provider and model, so it does **not** read `~/.paseo/orchestration-preferences.json` (per the paseo skill, preferences are skipped when a provider is explicitly named). Honor the preferences' async conventions: `notifyOnFinish=true`, do not poll. Use worktree isolation (`--isolation worktree`) when multiple delegated agents run in parallel on the same repo.

## Fixed configuration

- Provider: `opencode/opencode-go/mimo-v2.5`
- Thinking: `max` (`settings.thinkingOptionId = "max"`)
- Fast mode + auto-accept: `settings: { features: { "fast_mode": true, "auto_accept": true } }`
- Mode: `build`
- Title: `[Delegate] <topic>`

**Provider routing convention:** This workhorse is a MiMo model, so it stays on `opencode-go`. For any *OpenAI* model, prefer routing via the `codex` provider as `codex/<model>` (e.g. `codex/gpt-5.6-sol`).

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

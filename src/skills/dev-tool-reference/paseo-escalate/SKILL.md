---
name: paseo-escalate
description: >-
  Escalate a judgment call from the deepseek-v4-flash orchestrator to a frontier
  model (codex gpt-5.6-sol at max reasoning) via the Paseo advisor. Use when
  deepseek-v4-flash needs higher reasoning to think for it — high-stakes
  synthesis, planning, or contested tradeoffs. Not for routine questions or work
  deepseek-v4-flash can handle.
user-invocable: true
argument-hint: "[question, tradeoff, or synthesis to escalate]"
---

# Escalate to Frontier Advisor

One Paseo advisor agent on **codex gpt-5.6-sol at max reasoning**, fresh context, read-only. Used when the deepseek-v4-flash orchestrator needs a higher-reasoning model to think for it — high-stakes synthesis, planning, or contested tradeoffs. The advisor decides nothing and edits nothing; the orchestrator makes the call.

**User's request:** $ARGUMENTS

## When to use

- **High-stakes synthesis** — merging divergent committee/agent outputs into one call you can't make confidently on deepseek-v4-flash.
- **Planning** — plan sequencing, scope boundaries, or approach selection where a wrong call is expensive.
- **Contested tradeoffs** — architecture, direction, or cost/quality calls where you want frontier-model reasoning before committing.

Do NOT use for routine questions, mechanical work, or anything deepseek-v4-flash handles fine — this spends limited codex budget.

## Prerequisites

Read the **paseo** skill. This skill hardcodes the provider and model, so it does **not** read `~/.paseo/orchestration-preferences.json` (per the paseo skill, preferences are skipped when a provider is explicitly named). Honor the preferences' async conventions: `notifyOnFinish=true`, do not poll.

## Fixed configuration

- Provider: `codex/gpt-5.6-sol`
- Thinking: `max` (`settings.thinkingOptionId = "max"`)
- Title: `[Escalate] <topic>`

## The briefing

The advisor has zero context. Make it self-contained:

- The question, sharply.
- What you've considered and what you've ruled out.
- Relevant files by path (don't paste — let the agent read).
- Why this call is being escalated (stakes).
- Explicit ask: "give me a recommendation, with reasoning."

End with the no-edits suffix:

```
This is analysis only. Do NOT edit, create, or delete any files. Do NOT write code.
```

## Launch and synthesize

Create the advisor agent via Paseo with a `[Escalate] <topic>` title, the briefing as the initial prompt, and `settings: { thinkingOptionId: "max" }`. Wait for it to finish. Read its response. Synthesize for the user — the advisor's verdict plus your recommendation — then make the call yourself. Do not yield the decision to the advisor.

Archive the agent when done, or keep it for follow-ups if the topic is still open.

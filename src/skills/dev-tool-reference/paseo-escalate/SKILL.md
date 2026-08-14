---
name: paseo-escalate
description: >-
  Escalate a judgment call from the deepseek-v4-flash orchestrator to a frontier
  reasoning model via the Paseo advisor. The escalated model is NOT hardcoded:
  resolve it from ~/.paseo/orchestration-preferences.json (planning category)
  first; if that file is missing, ask the user which model to escalate to,
  offering gpt-5.6-sol, opus 5, or minimax m3 (default). Use when
  deepseek-v4-flash needs higher reasoning to think for it — high-stakes
  synthesis, planning, or contested tradeoffs. Not for routine questions or work
  deepseek-v4-flash can handle.
user-invocable: true
argument-hint: "[question, tradeoff, or synthesis to escalate]"
---

# Escalate to Frontier Advisor

One Paseo advisor agent on a frontier reasoning model, fresh context, read-only. Used when the deepseek-v4-flash orchestrator needs a higher-reasoning model to think for it — high-stakes synthesis, planning, or contested tradeoffs. The advisor decides nothing and edits nothing; the orchestrator makes the call.

**User's request:** $ARGUMENTS

## When to use

- **High-stakes synthesis** — merging divergent committee/agent outputs into one call you can't make confidently on deepseek-v4-flash.
- **Planning** — plan sequencing, scope boundaries, or approach selection where a wrong call is expensive.
- **Contested tradeoffs** — architecture, direction, or cost/quality calls where you want frontier-model reasoning before committing.

Do NOT use for routine questions, mechanical work, or anything deepseek-v4-flash handles fine — this spends limited frontier-model budget.

## Prerequisites

Read the **paseo** skill. Before choosing a provider or creating the agent, read `~/.paseo/orchestration-preferences.json` (an actual file read, never an assumed default — per the paseo skill). Honor the preferences' async conventions: `notifyOnFinish=true`, do not poll.

## Resolving the escalation model (replaces any hardcoded provider)

The escalated provider/model is resolved, never hardcoded:

1. **Read `~/.paseo/orchestration-preferences.json`.** If it exists, escalate using its **`planning`** provider entry — that category is the operator's configured frontier-reasoning route (for this operator it resolves to `opencode/openai/gpt-5.6-sol`). Use the preference's stated `thinkingOptionId` when given; otherwise default to `max`.
2. **If the file does not exist**, ask the user which model to escalate to. Offer these recommendations (all statement-of-thinking frontier models):
   - **gpt-5.6-sol** (`opencode/openai/gpt-5.6-sol`) — strongest forward-looking planning/synthesis.
   - **opus 5** (`claude/claude-opus-5`) — strongest general reasoning / human-skill work.
   - **minimax m3** (`opencode-go/minimax-m3`) — **default**; cross-family contrast for audit/review.
   Use the user's choice; default to minimax m3 if they do not specify.

## Fixed configuration

- Provider/model: resolved above (never a literal hardcoded model id).
- Thinking: the resolved preference's `thinkingOptionId`, else `max` for frontier synthesis (`settings.thinkingOptionId`).
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

## Optional: writing findings to a report

By default the advisor returns its findings in its reply and makes no file writes. If the calling agent wants a durable report, include this instruction in the briefing:

```
Write your findings to a report document. Save it to this exact path:
<absolute path>. Do not write anywhere else.
```

Rules governing report writes:

- **The calling agent specifies the location.** The escalated model never chooses the path. The calling agent must state an exact absolute path in the briefing when a report is wanted.
- **No location, no write.** If the escalated model is told to write findings down but the briefing does not contain an explicit location, it must ask the calling agent where to save the file and wait for the answer before continuing. It must not guess a path, derive one from the repo, or proceed to write.
- **One write exception only.** The escalated model may write a report only to the caller-specified path. All other edits remain prohibited by the no-edits suffix.

## Launch and synthesize

Create the advisor agent via Paseo with a `[Escalate] <topic>` title, the briefing as the initial prompt, and `settings: { modeId: "plan", thinkingOptionId: <resolved> }`. Note: a claude provider agent cannot inherit opencode's `build` mode — pass an explicit `modeId` (use `plan`; read-only, matching the advisor's no-edits role). Wait for it to finish. Read its response (and the report file, if one was requested). Synthesize for the user — the advisor's verdict plus your recommendation — then make the call yourself. Do not yield the decision to the advisor.

Archive the agent when done, or keep it for follow-ups if the topic is still open.
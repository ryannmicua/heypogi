# Distilled OpenAI GPT-5.6 prompting guidance

Source: OpenAI, “Prompting guidance for GPT-5.6 Sol”
Official URL: https://developers.openai.com/api/docs/guides/prompt-guidance-gpt-5p6
Snapshot reviewed: 2026-07-12

Use this as an evaluation reference, not as a substitute for representative application evals.

## Core principle

Define the destination and the completion bar: the user-visible outcome, important constraints, available evidence, required output, and stopping conditions. Leave room for the model to choose an efficient path when the path is not itself a requirement.

## 1. Simplify first

Prefer lean prompts. Remove repeated rules, repeated style or process instructions, examples that do not change behavior, instructions for behavior the model already performs reliably, and tools unrelated to the task.

Retain the outcome, success and stopping conditions, safety and business constraints, evidence and permission rules, context-dependent tool routing, output shape, and validation requirements.

Review the remaining prompt for contradictions. Conflicting instructions can be more destabilizing than missing detail.

## 2. State outcomes and stopping conditions

Describe what good looks like instead of prescribing every step. Include success criteria and what to do when required evidence is missing.

Use absolute terms only for real invariants. For judgment calls, provide decision criteria. Preserve explicit user values. Avoid universal defaults, keyword maps, and broad shortcuts that bypass contextual judgment.

Include retry, fallback, ask, abstain, and stop behavior where relevant.

## 3. Control personality, collaboration, and length separately

Personality governs tone, warmth, formality, directness, empathy, humor, and polish. Collaboration governs initiative, assumptions, questions, tradeoffs, checking work, and uncertainty.

Keep both compact and behaviorally specific. Do not let them replace goals, success criteria, tool rules, or stop rules.

For short outputs, state which information must be preserved and which lower-value detail may be omitted. For editing and rewriting, specify what must remain unchanged before asking for improvements.

Use API `text.verbosity` for a stable default level of detail when applicable, with prompt instructions for task-specific length and structure.

## 4. Define autonomy and approval boundaries

State what the request authorizes. Distinguish inspection, planning, local implementation, external writes, destructive actions, purchases, and material scope expansion.

Name safe local actions explicitly when useful. Keep permission policy in one place and state each rule once. For long work, define the current layer: research, design, implementation, review, or external coordination.

## 5. Route tools deliberately

Expose only relevant tools. Tool descriptions should explain what the tool does, when to use it, important return fields, and error behavior.

State prerequisite discovery, retrieval, and validation. Parallelize independent reads; keep dependent work sequential; synthesize retrieved evidence before acting. When results are empty, partial, or suspiciously narrow, attempt one or two meaningful fallbacks before concluding that no result exists.

## 6. Use programmatic tool calling only for bounded reduction

Programmatic Tool Calling is appropriate for deterministic filtering, joining, sorting, ranking, deduplication, aggregation, batching, repeated validation, or compressing large structured outputs.

Prefer direct calls when one call is enough, intermediate results are small, each result changes the next decision, approval is needed, citations or native artifacts must be preserved, or semantic judgment is required between calls.

When PTC is used, define the bounded stage, eligible tools, compact output schema, retry limit, stop condition, and handoff back to direct judgment. Validate both program output and final assistant response.

## 7. Define grounding and citation behavior

State what needs evidence, what sufficient support means, and how to behave when evidence is absent. Missing evidence is not automatically evidence of absence.

For research, cite only retrieved sources, attach citations to supported claims, separate inference from direct support, state source conflicts, and narrow or abstain rather than guess.

For creative drafting, distinguish sourced facts from creative wording and do not invent names, metrics, dates, status, outcomes, or capabilities.

## 8. Manage long-running workflows and state

For multi-step work, request a brief visible preamble before tool use and sparse outcome-based updates at major phase changes, not narration of routine calls.

Preserve assistant phase values when replaying history. Compact after major milestones. Keep compacted state functionally consistent and treat it as opaque. Use persisted reasoning only while objective, assumptions, and priorities remain stable. Keep reusable prompt prefixes stable when prompt caching matters.

## 9. Tune reasoning effort with evals

Start from the existing baseline. Test the same effort and one level lower. Use higher levels only when representative evals show meaningful quality gains. Before increasing effort, check whether the prompt lacks a success criterion, dependency rule, tool-routing rule, or verification loop.

## 10. Preserve product and visual constraints

For frontend work, preserve the existing design system, tokens, components, responsive behavior, and relevant states. Do not add unrequested features or decoration. Render and inspect the result.

For spatially precise vision, computer use, localization, or OCR work, choose image detail intentionally based on density, precision, cost, and latency.

## 11. Validate before finishing

State the validation that matters and give the model access to appropriate tools.

For code, use targeted tests, type or lint checks, affected builds, or a minimal smoke test. Explain when validation cannot run.

For visual artifacts, render and inspect layout, clipping, spacing, missing content, and consistency. For implementation plans, include requirements, named resources, state or data flow, validation, failure behavior, security or privacy concerns, and material open questions.

## 12. Suggested complex-prompt structure

Use only sections that change behavior:

- Role
- Personality
- Goal
- Success criteria
- Constraints
- Tools
- Output
- Stop rules

## 13. Migration discipline

When moving to GPT-5.6, change the model while preserving the current reasoning baseline, run representative evals, remove obsolete scaffolding and irrelevant tools, make the smallest targeted fix for measured regressions, and rerun the same evals after each change.

Do not rewrite a working prompt stack all at once. Debug regressions with real traces and surgical edits.

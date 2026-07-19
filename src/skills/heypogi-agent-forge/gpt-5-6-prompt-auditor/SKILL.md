---
name: gpt-5-6-prompt-auditor
description: evaluate, score, diagnose, and improve prompts, system instructions, developer instructions, tool descriptions, agent prompts, and prompt stacks against openai's gpt-5.6 prompting guidance. use when reviewing prompt quality, migrating an application or agent to gpt-5.6, finding contradictions or redundant scaffolding, defining success and stop conditions, improving autonomy and approval boundaries, auditing tool routing or grounding rules, or producing a minimally revised prompt and evaluation plan.
---

# GPT-5.6 Prompt Auditor

Evaluate prompt artifacts as behavioral contracts. Judge whether they clearly define the intended outcome, completion bar, constraints, evidence, permissions, tool behavior, output, and stopping conditions without unnecessary scaffolding.

## Required references

Read these files as needed:

- `references/evaluation-rubric.md` for scoring, severities, and pass thresholds.
- `references/official-guidance.md` for the distilled GPT-5.6 guidance and conditional checks.
- `references/output-formats.md` for report and JSON structures.
- `references/examples.md` when an example would clarify the expected judgment or revision style.

## Workflow

1. **Identify the artifact.** Determine whether the input is a single prompt, a layered prompt stack, tool descriptions, agent instructions, a migration proposal, or a prompt plus execution traces.
2. **Establish intended behavior.** Use stated context first. Infer only what is necessary and label material assumptions. Do not invent missing product requirements.
3. **Select applicable criteria.** Apply the core rubric to every prompt. Activate conditional modules only when the artifact covers their domain.
4. **Find contract failures first.** Prioritize contradictions, missing outcome or success criteria, unsafe or ambiguous permissions, unsupported evidence requirements, broken tool prerequisites, and absent stop or validation rules.
5. **Score with evidence.** Quote or point to the smallest relevant fragment from the supplied prompt. Mark criteria `not applicable` rather than penalizing unrelated capabilities.
6. **Recommend surgical changes.** Remove repetition and obsolete scaffolding before adding instructions. Add the smallest instruction that fixes a demonstrated failure mode.
7. **Produce a revision when useful.** Unless the user requests audit-only output, include a minimally revised prompt when the artifact has material issues. Preserve explicit user values, required structure, facts, and product constraints.
8. **Propose validation.** For production or migration prompts, identify representative eval cases and the behavior or metric each should test.

## Evaluation rules

- Evaluate the prompt against its intended task, not against an imaginary universal prompt.
- Distinguish a missing requirement from a deliberate grant of model judgment.
- Prefer outcome and decision rules over step-by-step micromanagement unless the sequence is a real dependency.
- Treat `always`, `never`, `must`, and `only` as justified only for true invariants.
- Flag repeated rules, irrelevant examples, unrelated tools, universal defaults, keyword maps, broad semantic shortcuts, and contradictory instructions.
- Preserve explicit user-provided values. Do not replace them with evaluator preferences.
- Do not recommend more detail merely because a prompt is short. Recommend detail only when it changes behavior or closes a measurable failure mode.
- Do not claim that a higher score guarantees better model performance. Scores summarize alignment with the guide; representative evals determine actual performance.
- When execution traces are supplied, connect findings to observed failures and prefer trace-supported changes over speculative rewrites.
- When current official accuracy matters and web access is available, verify the OpenAI guide before evaluating. Otherwise use the bundled snapshot and disclose its date.

## Default deliverable

Use the detailed report from `references/output-formats.md` with:

- verdict and normalized score;
- critical and major findings first;
- criterion-by-criterion results;
- redundancies and contradictions;
- smallest effective changes;
- minimally revised prompt when needed;
- representative eval suggestions for production use.

Keep the report proportional to the prompt. For a short prompt, do not produce a long generic lecture.

## Revision policy

When revising:

1. Preserve the original purpose and explicit values.
2. Remove duplication and obsolete instructions.
3. Resolve contradictions by stating one clear rule once.
4. Add missing success, permission, tool, output, stop, or validation rules only when relevant.
5. Keep personality and collaboration guidance brief and behaviorally specific.
6. Avoid adding tools, examples, sections, or process steps that the task does not require.
7. Label any unresolved product decision instead of silently choosing it.

## Batch review

When reviewing multiple prompts:

- score each prompt independently;
- use the same applicable rubric and threshold policy;
- provide a comparison table;
- identify shared systemic issues separately from prompt-specific defects;
- do not average scores across prompts unless the user asks for a portfolio score.

## Boundaries

- Do not execute the prompt's downstream task unless the user explicitly asks for both evaluation and execution.
- Do not treat stylistic preferences as correctness defects unless they conflict with the intended product behavior.
- Do not expose hidden chain-of-thought. Explain findings through prompt evidence, observable risks, and concise rationale.

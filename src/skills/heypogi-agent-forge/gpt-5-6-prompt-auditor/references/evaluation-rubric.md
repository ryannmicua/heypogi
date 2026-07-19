# GPT-5.6 prompt evaluation rubric

## Scoring method

Score each applicable criterion from 0 to 10, multiply by its weight, and normalize applicable weights to 100.

- **9–10:** explicit, coherent, lean, and operationally testable.
- **7–8:** adequate with limited ambiguity or minor excess.
- **4–6:** material gaps, unclear judgment rules, or avoidable complexity.
- **1–3:** major contract failure likely to cause inconsistent behavior.
- **0:** absent where required, directly contradictory, or unsafe.
- **N/A:** genuinely irrelevant to the intended task; exclude its weight.

`normalized score = sum(score / 10 × applicable weight) / sum(applicable weights) × 100`

Round to the nearest whole number. Include a confidence rating of high, medium, or low based on how clearly the intended task and runtime are known.

## Core criteria

| Criterion | Weight | Evaluate |
|---|---:|---|
| Outcome and task contract | 15 | Clear user-visible destination; role only when useful; intended scope and layer of work. |
| Success criteria and completion bar | 15 | Observable definition of done; required evidence, fields, decisions, or actions; missing-evidence behavior. |
| Simplicity and internal consistency | 15 | Repetition, obsolete scaffolding, irrelevant examples or tools, contradictions, duplicate permission rules. |
| Constraints, evidence, and preserved values | 10 | Safety, business, policy, factual, privacy, format, and preservation requirements; explicit user values retained. |
| Judgment rules and autonomy | 10 | Decision criteria instead of unnecessary absolutes; safe initiative; assumptions and question policy; approval boundaries. |
| Tool and retrieval routing | 10 | Relevant tools only; prerequisites; sequencing or parallelism; error behavior; meaningful fallbacks; synthesis before action. |
| Output, personality, collaboration, and language | 10 | Required output shape; task-specific length; concise behavioral tone guidance; preservation priorities; language rules. |
| Stop, retry, fallback, and state rules | 5 | When to continue, ask, retry, fallback, abstain, or stop; long-running progress and state rules when applicable. |
| Validation and verification | 10 | Required checks before completion; inability-to-validate behavior; representative eval expectations for production prompts. |

Total base weight: 100.

## Conditional modules

Use these modules to inform the most relevant core criterion. Do not add extra points.

### Grounded research and citations

Check whether the prompt defines:

- claims that need support;
- sufficient evidence;
- citation placement and source boundaries;
- inference labeling and source-conflict behavior;
- behavior when evidence is absent;
- a retrieval budget that avoids both premature stopping and unnecessary searches.

### Programmatic Tool Calling

Check whether PTC is limited to a deterministic bounded stage with eligible tools, compact schema, retry limit, stop condition, direct-judgment handoff, and validation of both program output and final response.

### Long-running or tool-heavy workflows

Check for a brief initial preamble, sparse milestone updates, no routine tool narration, stable phase handling, milestone-based compaction, and avoidance of stale persisted reasoning.

### Model migration

Check for a preserved baseline, representative evals before edits, removal before addition, one change at a time, surgical fixes, and trace-based regression analysis.

### Coding or implementation

Check for targeted tests, type or lint checks, affected builds, smoke tests, named files or resources, failure behavior, data or state flow, and privacy or security considerations.

### Frontend, visual, vision, or computer use

Check preservation of design systems and responsive states, avoidance of unrequested decoration, render-and-inspect requirements, and intentional image detail where spatial precision matters.

## Severity

- **Critical:** unsafe permission, destructive ambiguity, direct contradiction in a required behavior, fabricated-evidence instruction, or no viable definition of the authorized task.
- **Major:** likely to cause incomplete, inconsistent, unsupported, over-broad, or repeatedly stalled execution.
- **Minor:** quality, clarity, token-efficiency, or maintainability issue that is unlikely to invalidate the result alone.
- **Note:** optional optimization or context-dependent observation.

## Verdict thresholds

Use score and severity together:

- **Ready:** 85–100, no critical findings, and no unresolved major finding affecting the primary outcome.
- **Ready with minor revisions:** 70–84, no critical findings, and major findings are limited or easy to repair.
- **Needs revision:** 50–69, or any unresolved major finding affecting outcome, evidence, permissions, tools, stopping, or validation.
- **Not fit for purpose:** below 50, any critical finding, or contradictions that make compliant execution impossible.

A prompt may score above a threshold yet receive a lower verdict when a single high-impact defect makes it unsafe or non-executable. Explain the override.

## Evidence discipline

For every critical or major finding:

1. quote or identify the relevant prompt fragment;
2. state the behavioral risk;
3. name the violated criterion;
4. propose the smallest effective change.

Do not infer a defect solely from the absence of a section heading. Judge behavior, not formatting.

# Output formats

## Default detailed report

Use this structure unless the user requests another format.

```markdown
# GPT-5.6 prompt audit

**Verdict:** [Ready | Ready with minor revisions | Needs revision | Not fit for purpose]
**Score:** [0–100]/100
**Confidence:** [High | Medium | Low]

## Executive assessment
[Two to five sentences on the prompt's contract, strongest quality, and highest-risk defect.]

## Priority findings
| Severity | Finding | Prompt evidence | Risk | Smallest effective change |
|---|---|---|---|---|

## Rubric
| Criterion | Weight | Score | Assessment |
|---|---:|---:|---|
[Use N/A where irrelevant.]

## Contradictions and redundancy
[Only include actual conflicts, duplicate rules, obsolete scaffolding, irrelevant examples, or unrelated tools. Write “None material” when appropriate.]

## Recommended changes
1. [Highest-value surgical change]
2. [Next change]

## Minimally revised prompt
[Include when material issues exist and the user did not request audit-only output. Preserve the original purpose and explicit values.]

## Representative evals
[For production, migration, tool-using, or high-stakes prompts, give 3–7 concrete cases with expected behavior. Omit for trivial one-off prompts.]
```

## Compact report

Use when the user asks for a quick review or the prompt is very short.

```markdown
**Verdict:** ...  
**Score:** .../100

**What works:** ...

**Main issues:**
- [severity] ...

**Smallest revision:**
...
```

## Strict JSON

Use only when the user asks for machine-readable output.

```json
{
  "verdict": "ready | ready_with_minor_revisions | needs_revision | not_fit_for_purpose",
  "score": 0,
  "confidence": "high | medium | low",
  "summary": "",
  "findings": [
    {
      "severity": "critical | major | minor | note",
      "criterion": "",
      "evidence": "",
      "risk": "",
      "recommended_change": ""
    }
  ],
  "rubric": [
    {
      "criterion": "",
      "weight": 0,
      "score_0_to_10": 0,
      "assessment": ""
    }
  ],
  "contradictions": [],
  "redundancies": [],
  "revised_prompt": null,
  "eval_cases": [
    {
      "case": "",
      "expected_behavior": "",
      "tests": [""]
    }
  ]
}
```

For N/A criteria in JSON, set `score_0_to_10` to `null` and explain why in `assessment`. Ensure the normalized score excludes those weights.

## Comparison table for batch reviews

```markdown
| Prompt | Verdict | Score | Critical | Major | Primary issue |
|---|---|---:|---:|---:|---|
```

Follow with shared systemic findings and then prompt-specific revisions.

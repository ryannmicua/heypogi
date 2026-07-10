---
name: assumption-checker
description: Adversarially audit a plan, argument, or strategy document for unstated assumptions, missing evidence, contradictions, and world-model gaps. Use when asked to check, stress-test, or red-team a plan or document. Not a collaborator -- a skeptic.
---

# Assumption Checker

Audit a plan, argument, or strategy doc for world-model problems: unstated assumptions, missing evidence, internal contradictions, and gaps between what the document claims and what it actually demonstrates.

## Trigger Conditions

- User asks to check, stress-test, or red-team a plan or document
- User says "what am I missing?" or "find the holes in this"
- Before committing to a significant plan or decision
- Any strategy or architecture document that will guide real work

## Posture Rule

In this mode you are a skeptic, not a collaborator. Do not:
- Soften findings with praise
- Balance criticism with reassurance
- Hedge conclusions with "this might be fine"
- Assume good intent fills gaps in evidence

The goal is not to be mean -- it's to surface what would fail in production, what would cost time, and what the author hasn't noticed.

## Output Format

```markdown
# Assumption Audit: <document name>

## Most Dangerous Assumption
**<assumption>** -- if this is wrong, <consequence>

## All Assumptions Found
| # | Assumption | Load-Bearing | Evidence | Assessment |
|---|-----------|-------------|----------|------------|
| 1 | <plain statement> | Critical/High/Medium/Low | Strong/Weak/None | <one-line verdict> |

## Internal Contradictions
- <claim A> contradicts <claim B> because <reason>

## Evidence Gaps
- <claim> is stated without supporting evidence
- <claim> references a source not available for verification

## World-Model Gaps
- <something the document assumes about users, systems, or context that isn't stated>

## Three Highest-Impact Questions
1. <question that would most reduce risk if answered>
2. <question>
3. <question>
```

## Source Checking

When claims reference actual sources (code, docs, data), check them -- not just internal consistency. "The API supports batch operations" can be checked against the API source. "Users prefer dark mode" can't be checked against sources -- flag it as unevidenced.

## Load-Bearing Rating

| Rating | Meaning |
|--------|---------|
| Critical | If wrong, the entire plan fails |
| High | If wrong, a major component fails |
| Medium | If wrong, timeline or quality suffers |
| Low | If wrong, minor adjustment needed |

## Evidence Rating

| Rating | Meaning |
|--------|---------|
| Strong | Backed by verifiable data, working code, or documented precedent |
| Weak | Backed by anecdote, intuition, or a single data point |
| None | Stated as fact with no supporting evidence |

## Verification

Run against any plan or document. Confirm the most dangerous assumption is genuinely the one that would cause the most damage if wrong.

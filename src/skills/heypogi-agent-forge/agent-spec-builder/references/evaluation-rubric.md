# Agent Specification Evaluation Rubric

Use this rubric to review a draft specification before returning it or when the user asks to improve an existing spec.

## Pass/Fail Checklist

### 1. Purpose and Scope

Pass if:
- The agent's purpose is stated in one clear paragraph.
- Primary users are identified.
- In-scope and out-of-scope tasks are explicit.
- Success outcomes are measurable or observable.

Fail if:
- The spec describes a generic assistant without a clear job.
- The agent can apparently do everything.
- The spec omits who the agent is for.

### 2. Knowledge and Sources

Pass if:
- Authoritative sources are separated from contextual sources.
- Each major source has a purpose and freshness expectation.
- Citation or source-disclosure rules are defined.
- Conflict and missing-source behavior is defined.

Fail if:
- The spec says “use company data” without naming sources.
- The spec does not explain what to do when sources disagree.
- The spec treats email, memory, and official documents as equally authoritative.

### 3. Tools and Permissions

Pass if:
- Every connector/tool has a stated purpose.
- Read and write actions are separated.
- Confirmation requirements are explicit.
- Failure behavior is defined.

Fail if:
- Tools are listed without operations.
- Write actions are implied but not bounded.
- The spec lets the agent send, delete, update, or publish without a confirmation rule.

### 4. Workflows

Pass if:
- The spec includes normal, exception, escalation, and refusal flows.
- Tool use appears in workflows, not only in a connector list.
- The agent has clear behavior when information is missing.

Fail if:
- The spec is only a prompt or personality description.
- The spec does not explain how the agent should complete typical tasks.

### 5. Safety and Escalation

Pass if:
- Sensitive data, high-risk decisions, and unauthorized actions are bounded.
- Human escalation conditions are clear.
- Refusal and redirect behavior is defined.

Fail if:
- The spec gives broad access without restrictions.
- The agent is allowed to make policy, employment, legal, financial, or security decisions without review.

### 6. Output Formats

Pass if:
- Common response formats are defined.
- The format supports the users' actual workflow.
- The agent knows when to be concise versus detailed.

Fail if:
- Outputs are vague or inconsistent.
- The spec omits formats for the most common tasks.

### 7. Evaluation Tests

Pass if:
- The spec includes happy-path tests.
- The spec includes negative tests for missing sources, unauthorized actions, sensitive requests, and connector failures.
- Pass criteria are observable.

Fail if:
- Evaluation is limited to “answers are accurate.”
- There are no tests for unsafe or out-of-scope behavior.

### 8. Maintenance

Pass if:
- There is an owner or owner role.
- Review cadence is defined.
- Source update and test refresh expectations are defined.

Fail if:
- The spec has no maintenance plan.
- The agent depends on sources that may go stale but has no refresh rule.

## Review Output Format

When reviewing a spec, use this format:

## Assessment

Overall status: Pass / Pass with gaps / Needs revision

## Strengths

- Strength 1
- Strength 2

## Gaps

| Gap | Why it matters | Recommended fix |
|---|---|---|
|  |  |  |

## Revised Sections

Provide only the sections that need revision unless the user asks for a full rewrite.

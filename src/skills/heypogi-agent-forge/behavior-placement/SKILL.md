---
name: behavior-placement
description: Decide whether agent behavior belongs in an agent definition, a skill, or both. Use when decomposing large agent prompts, refactoring opencode or Codex agent definitions, designing broad agents with skill libraries, defining agent-skill boundaries, or reviewing instructions for placement, routing, authority, workflow, and reusable capability.
---

# Behavior Placement

## Objective

Classify an instruction, behavior, or chunk of agent definition into the right home: agent definition, skill, or both. Preserve the agent's identity and judgment while moving reusable methods into skills.

## Core Rule

Use this split:

- **Agent definition**: identity, authority, judgment, always-on behavior, safety boundaries, skill routing, collaboration style.
- **Skill**: repeatable workflows, procedures, checklists, templates, examples, output contracts, reusable or domain-specific capability.
- **Both**: the agent keeps the trigger, principle, or decision rule; the skill holds the method, checklist, examples, and output contract.

## Workflow

1. **Extract the behavior**
   - Rewrite the behavior as one clear statement.
   - Separate goals, triggers, constraints, steps, examples, and output expectations.

2. **Classify its function**
   - Ask whether it defines who the agent is, what it may decide, how it collaborates, or how it chooses work.
   - Ask whether it describes a task-specific method, reusable procedure, artifact, checklist, or example set.

3. **Choose the placement**
   - Put always-on identity, authority, judgment, safety, collaboration, and skill-routing rules in the agent definition.
   - Put task-specific methods, reusable workflows, templates, rubrics, examples, and output contracts in a skill.
   - Use both when an always-on trigger should invoke a detailed method.

4. **Rewrite for the selected home**
   - Agent definition text should be short, durable, and role-shaping.
   - Skill text should be procedural, task-scoped, and reusable across compatible agents.
   - Avoid duplicating the same detailed procedure in both places.

5. **Check the boundary**
   - If removing the behavior would change who the agent is, keep it in the agent definition.
   - If removing the behavior would only remove one capability, move it to a skill.
   - If the agent needs to know when to use it but not all details at all times, split it across both.

## Placement Test

Use these questions:

| Question | Placement |
|---|---|
| Should this apply across nearly every task? | Agent definition |
| Does this define role, authority, judgment, taste, or collaboration style? | Agent definition |
| Does this tell the agent how to choose skills or when to escalate? | Agent definition |
| Is this a step-by-step method, checklist, rubric, or template? | Skill |
| Could multiple agents reuse this behavior? | Skill |
| Does this produce a named artifact? | Skill |
| Does this need examples or reference material? | Skill |
| Is there an always-on trigger plus a detailed repeatable method? | Both |

## Rewrite Patterns

### Agent definition only

Use for durable role behavior:

```text
You preserve delivery quality by choosing the least autonomous mode that can complete the work and escalating when requirements are not testable.
```

### Skill only

Use for reusable task execution:

```text
Use the ticket-to-plan skill to convert rough work into a plan with goal, scope, constraints, acceptance criteria, risks, dependencies, and verification evidence.
```

### Both

Use when the agent needs the trigger but the details belong in a skill:

Agent definition:

```text
When work is ambiguous, convert it into a reviewable plan before implementation.
```

Skill:

```text
Define goal, constraints, scope, non-goals, affected systems, acceptance criteria, risks, dependencies, and verification evidence.
```

## Output Contract

When asked to analyze or decompose behavior, produce:

1. **Placement Decision**: agent definition, skill, or both.
2. **Reason**: the shortest explanation that names the decisive criterion.
3. **Agent Text**: final wording for the agent definition, or `None`.
4. **Skill Text**: final wording for the skill, or `None`.
5. **Notes**: risks, duplication concerns, or follow-up skills to create.

For batches, use a table with columns: `Behavior`, `Placement`, `Reason`, `Agent Text`, `Skill Text`.

## Quality Rules

- Keep agent definitions small and durable.
- Keep skills procedural and reusable.
- Preserve triggers in the agent when the agent must recognize when to invoke a skill.
- Do not hide authority, safety, or escalation rules inside a rarely loaded skill.
- Do not copy full workflows into agent definitions when a skill can own the method.
- Prefer a split placement over duplication when both identity and procedure are present.

---
name: sme-agent-creator
description: create complete subject matter expert agent definitions for repeatable agent-building work. use when asked to design, specify, scaffold, review, or improve an sme agent, expert assistant, domain agent, policy agent, knowledge agent, internal support agent, or ai agent factory. produces operational agent definition packages with domain scope, source map, permissions, decision rules, escalation rules, output formats, evaluation tests, and maintenance plan rather than generic prompts.
---

# SME Agent Creator

## Overview

Create reusable subject matter expert (SME) agent definitions that are operational, testable, and maintainable. Produce an agent definition package, not just a prompt.

## Core Principle

Treat each SME agent as a governed expert workflow with boundaries. Every generated agent must define trusted knowledge, task scope, source priority, permission limits, escalation rules, output contracts, evaluation cases, and maintenance ownership.

## Workflow

### 1. Classify the request

Determine whether the user wants to:

- create a new SME agent definition
- improve an existing SME agent
- review an SME agent for gaps
- create a reusable SME agent factory/template
- generate test cases or governance rules for SME agents

If the request is underspecified, ask only for the missing information needed to produce a useful first draft. Minimum intake fields are domain, users, sources, tools, permissions, and risky decisions.

Use `references/intake_questions.md` when collecting requirements.

### 2. Build the domain model

For each SME agent, define:

- domain and subdomains
- intended users
- common user intents
- terminology and assumptions
- high-risk scenarios
- human owner or review role

Keep the domain narrow. Prefer `employee leave policy assistant` over `hr expert`.

### 3. Map sources and authority

Define source priority before writing behavior rules. Use `references/source_mapping_template.md`.

Source rules must specify:

- authoritative sources
- fallback sources
- deprecated or non-authoritative sources
- source freshness expectations
- how to handle conflict between sources
- citation expectations when answering from documents

### 4. Define scope and permissions

Separate answer, advice, draft, and action capabilities.

Use this permission hierarchy:

1. read and summarize
2. classify or extract
3. recommend
4. draft
5. create records or tickets
6. send messages or modify systems
7. approve, deny, or make binding decisions

Require stronger approval and escalation controls as the permission level increases. SME agents should rarely be allowed to approve exceptions or make irreversible changes without human review.

### 5. Write decision and escalation rules

Use `references/decision_rules_template.md` and `references/escalation_matrix_template.md`.

Rules must require the agent to:

- prefer current approved sources
- distinguish facts, policy, interpretation, and recommendation
- ask for required missing facts
- state uncertainty when sources are insufficient
- refuse or redirect out-of-scope requests
- escalate high-risk or ambiguous cases

### 6. Define output contracts

Choose output formats based on agent purpose. Use `references/output_format_templates.md`.

Common formats:

- standard answer
- policy answer
- risk-aware recommendation
- executive summary
- case note
- email draft
- structured JSON
- ticket summary
- checklist

### 7. Generate evaluation cases

Every SME agent definition must include evaluation tests. Use `references/evaluation_rubric.md`.

Include tests for:

- common in-scope requests
- ambiguous requests
- missing facts
- conflicting sources
- out-of-scope requests
- high-risk decisions
- unsafe approval requests
- tool failures
- old versus current guidance

### 8. Add maintenance plan

Use `references/maintenance_checklist.md`. Define:

- owner
- source update process
- review cadence
- feedback loop
- versioning approach
- audit process
- criteria for retiring or revising the agent

## Default Deliverable

Unless the user requests another format, produce a markdown SME Agent Definition Package with these sections:

1. agent name
2. domain
3. purpose
4. users
5. trusted sources
6. source priority rules
7. in-scope tasks
8. out-of-scope tasks
9. tools and integrations
10. permissions
11. decision rules
12. escalation rules
13. compliance and safety rules
14. output formats
15. example requests and ideal responses
16. evaluation test cases
17. maintenance plan

Use `references/sme_agent_spec_template.md` as the canonical structure.

## Quality Bar

A strong SME agent definition must be:

- narrow enough to be useful
- explicit about authority and source priority
- clear about what the agent cannot do
- conservative with permissions
- specific about escalation
- testable with pass/fail criteria
- maintainable by a named role or team

Do not produce generic advice such as “act like an expert.” Convert expertise into operational constraints, examples, and tests.

## Optional Validation

When the user provides or requests a markdown agent specification file, use `scripts/validate_agent_spec.py` to check for required sections and common governance gaps. Summarize failures and suggest precise fixes.

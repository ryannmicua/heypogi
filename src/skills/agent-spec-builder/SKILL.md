---
name: agent-spec-builder
description: draft, improve, review, or validate implementation-ready specifications for chatgpt agents and internal ai assistants. use when the user asks to create an agent spec, assistant spec, sme agent, support agent, workflow agent, tool-using agent, or agent requirements document, especially when the agent may use sharepoint, outlook email, openai tools, github, or internal knowledge bases.
---

# Agent Spec Builder

## Objective

Turn rough agent ideas into complete, implementation-ready ChatGPT agent specifications. Focus on operational clarity: purpose, scope, users, source map, tools, permissions, workflows, response rules, evaluation tests, and maintenance.

## Default Behavior

When the user asks for an agent specification, produce a structured markdown spec unless another format is requested.

Use the user's rough idea as sufficient input when possible. Do not stall on missing details. Infer reasonable defaults, mark assumptions clearly, and include unresolved items under **Open Questions**.

Ask a focused question only when a missing detail would materially change the specification, such as whether the agent can send email, modify GitHub issues, or access confidential sources.

## Workflow

1. **Clarify the agent intent**
   - Identify the agent type: subject matter expert, support, workflow, coding, audit, administrative, research, or hybrid.
   - Identify the primary users and the job the agent performs.
   - Identify whether the agent is advisory only or can take actions.

2. **Map knowledge and authority**
   - Distinguish authoritative sources from helpful references.
   - Define citation requirements.
   - Specify what the agent must do when sources conflict, are stale, or are unavailable.

3. **Design tool and connector use**
   - For each connector or tool, define purpose, allowed operations, required user confirmation, and failure handling.
   - Default to least privilege and read-only behavior unless the user clearly authorizes write actions.

4. **Specify behavior and workflows**
   - Define normal flow, exception flow, escalation flow, and refusal flow.
   - Include response formats for common tasks.
   - Define tone, concision, citation, and confidence rules.

5. **Add tests and maintenance**
   - Include acceptance tests that prove the agent works.
   - Include negative tests for unsafe, out-of-scope, or under-sourced requests.
   - Define source refresh and owner review expectations.

6. **Validate the draft**
   - Check the final spec against `references/evaluation-rubric.md`.
   - Report gaps or assumptions instead of hiding them.

## Output Contract

For a full specification, use this order:

1. Agent Name
2. Executive Summary
3. Purpose and Outcomes
4. Primary Users
5. In Scope
6. Out of Scope
7. Source Map and Knowledge Rules
8. Tools and Connectors
9. Permissions and Safety Boundaries
10. Core Workflows
11. Conversation Behavior
12. Output Formats
13. Escalation and Refusal Rules
14. Evaluation Tests
15. Maintenance Plan
16. Open Questions

Use `references/agent-spec-template.md` when producing a complete spec.
Use `references/connector-guidance.md` when the agent may use SharePoint, Outlook Email, OpenAI tools, GitHub, or internal knowledge bases.
Use `references/evaluation-rubric.md` when reviewing, improving, or validating an agent spec.

## Connector Defaults

Apply these defaults unless the user states otherwise:

- **SharePoint**: use for source-of-truth documents, policies, procedures, shared files, and team knowledge. Prefer citation-backed answers. Do not assume every SharePoint result is current.
- **Outlook Email**: use for searching, reading, summarizing, drafting, and replying to email only when allowed. Sending email requires explicit user instruction.
- **OpenAI tools**: use for file analysis, web verification, structured reasoning, code execution, artifact creation, retrieval, and evaluation where available.
- **GitHub**: use for repositories, issues, pull requests, code review context, release notes, and engineering work items. Separate read-only analysis from write actions.
- **Internal knowledge bases**: use as authoritative organizational context when available. Cite or name the source when possible and identify gaps when retrieval is insufficient.

## Quality Rules

- Make every tool permission explicit.
- Avoid vague phrases like “uses company data” or “integrates with systems.” Name the source, access level, operation, and guardrail.
- Separate agent behavior from implementation details.
- Include enough tests for another builder to verify the agent without guessing.
- State assumptions plainly.
- Keep the specification concise, but complete enough to hand to a builder, evaluator, or owner.

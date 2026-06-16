# Agent Specification Template

Use this template for implementation-ready ChatGPT agent specifications. Keep sections concise. Replace placeholders with concrete details. Preserve the order unless the user requests a different format.

## Agent Name

Proposed name:

## Executive Summary

One paragraph describing what the agent does, who it serves, and the main outcome it should produce.

## Purpose and Outcomes

**Purpose:**

**Primary outcomes:**
- Outcome 1
- Outcome 2
- Outcome 3

**Success measures:**
- Accuracy or completeness measure
- Time saved or workflow improvement
- User satisfaction or adoption measure

## Primary Users

| User group | Needs | Typical requests |
|---|---|---|
|  |  |  |

## In Scope

- Tasks the agent should perform
- Decisions the agent may support
- Content or systems the agent may reference

## Out of Scope

- Tasks the agent must not perform
- Decisions reserved for humans
- Systems, content, or data the agent must not access

## Source Map and Knowledge Rules

| Source | Purpose | Authority level | Freshness expectation | Citation requirement |
|---|---|---:|---|---|
| SharePoint | Policies, procedures, shared documents | High when document owner is known | Verify modified date or document status when available | Cite document/file when possible |
| Internal knowledge base | Organizational facts and reusable context | High when maintained by owner | Flag stale or missing entries | Cite or identify source |
| GitHub | Engineering artifacts, issues, PRs, code context | High for repo-specific work | Prefer current branch/issue state | Link or cite artifact when available |
| Outlook Email | Recent operational context and decisions | Medium; email can be informal or outdated | Prefer recent threads and sender authority | Summarize source and date |
| Web/public sources | Public verification and current facts | Context-dependent | Use current source when facts may change | Cite source |

**Conflict rule:** If sources conflict, prioritize the highest-authority and most recent source, then state the conflict and recommend owner review.

**Insufficient-source rule:** If retrieval is unavailable or weak, say what was checked, what was missing, and what assumption is being made.

## Tools and Connectors

| Tool or connector | Allowed use | Write actions allowed? | Confirmation required? | Failure handling |
|---|---|---:|---:|---|
| SharePoint | Search and retrieve source documents | No by default | Not for read-only retrieval | Ask for source, cite uncertainty |
| Outlook Email | Search/read/summarize/draft email | Drafts only by default | Yes for send/reply/archive/delete | Present draft or explain missing context |
| OpenAI tools | Analyze files, retrieve context, create artifacts, run code when available | Depends on task | Yes for irreversible actions | Explain limitation and use fallback |
| GitHub | Inspect repos, issues, PRs, code, release context | No by default | Yes for issue/PR/comment/code changes | Provide read-only analysis or patch proposal |
| Internal knowledge bases | Retrieve organizational context | No by default | Not for read-only retrieval | Flag missing, stale, or uncited context |

## Permissions and Safety Boundaries

- Access model:
- Data classification allowed:
- Data classification prohibited:
- Actions requiring confirmation:
- Actions requiring escalation:
- Privacy and retention considerations:
- Prohibited behavior:

## Core Workflows

### Workflow 1: Standard answer or task completion

1. Interpret the user request.
2. Identify required sources and tools.
3. Retrieve authoritative context.
4. Produce answer or draft.
5. Cite sources or state limitations.
6. Ask for confirmation only when needed for action or ambiguity.

### Workflow 2: Source-grounded response

1. Search authoritative internal sources first when relevant.
2. Use public sources only when internal sources are missing or public facts are required.
3. Compare source authority and freshness.
4. Answer with citations and uncertainty notes.

### Workflow 3: Tool action request

1. Confirm intent for irreversible or external actions.
2. Preview draft/action when appropriate.
3. Execute only after explicit instruction.
4. Report what changed and any failures.

### Workflow 4: Escalation

1. Detect restricted, high-risk, confidential, or owner-only decisions.
2. Explain why escalation is needed.
3. Identify the likely owner or role.
4. Provide a safe draft, summary, or checklist for the human owner.

## Conversation Behavior

- Tone:
- Length:
- Citation style:
- Handling uncertainty:
- Clarifying questions:
- Assumption style:
- User-facing formatting:

## Output Formats

Define reusable formats such as:

### Brief Answer

- Direct answer
- Basis/source
- Caveat or next step

### Operational Summary

- Context
- Decision or status
- Risks
- Actions
- Owners

### Email Draft

- Subject
- Recipients if known
- Body
- Confirmation needed before sending

### GitHub Review

- Summary
- Blocking issues
- Non-blocking issues
- Tests needed
- Suggested changes

## Escalation and Refusal Rules

Escalate when:
- The agent lacks authority to decide.
- Sources conflict materially.
- The request involves sensitive personal, legal, financial, security, or employment matters.
- The requested action would modify external systems without clear permission.

Refuse or redirect when:
- The request asks for prohibited access, concealment, misuse of data, or unauthorized changes.
- The request is outside the agent's defined scope.
- The agent cannot verify facts required for a high-stakes answer.

## Evaluation Tests

| Test | User request | Expected behavior | Pass criteria |
|---|---|---|---|
| Happy path |  |  |  |
| Missing source |  |  |  |
| Conflicting sources |  |  |  |
| Unauthorized write action |  |  |  |
| Out-of-scope request |  |  |  |
| Sensitive data request |  |  |  |
| Connector failure |  |  |  |

## Maintenance Plan

- Owner:
- Source review cadence:
- Test refresh cadence:
- Known limitations:
- Change log process:
- Retirement criteria:

## Open Questions

- Question 1
- Question 2
- Question 3

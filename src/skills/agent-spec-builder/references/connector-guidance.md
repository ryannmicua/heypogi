# Connector Guidance for Agent Specifications

Use this reference when the agent specification includes SharePoint, Outlook Email, OpenAI tools, GitHub, or internal knowledge bases. The goal is to define practical tool behavior, not just name integrations.

## General Connector Pattern

For each connector, specify:

1. **Purpose**: why the agent uses it.
2. **Allowed reads**: what the agent may search, retrieve, or summarize.
3. **Allowed writes**: what the agent may create, update, send, delete, label, comment, or archive.
4. **Confirmation rule**: when explicit user confirmation is required.
5. **Authority rule**: whether the connector is a source of truth, contextual evidence, or convenience tool.
6. **Failure rule**: what the agent should say or do when the connector is unavailable or returns weak results.
7. **Citation rule**: how the agent should cite, link, or name the source.

## SharePoint

**Best uses**
- Policies, procedures, SOPs, project documents, templates, handbooks, meeting files, and shared reference material.

**Default permissions**
- Read/search/retrieve only.
- Do not create, edit, move, or delete SharePoint files unless the user explicitly authorizes that capability in the agent design.

**Spec language**
- Define which SharePoint sites, libraries, folders, or document types are in scope.
- Require the agent to check document title, owner, modified date, and status when available.
- Require citations for policy or procedural answers.
- Require uncertainty language when results appear stale, duplicated, draft-only, or conflicting.

## Outlook Email

**Best uses**
- Recent operational context, decisions in threads, meeting follow-ups, stakeholder messages, drafting responses, and summarizing unread or selected mail.

**Default permissions**
- Search, read, summarize, and draft are allowed when the user grants access.
- Sending, replying, forwarding, archiving, labeling, or deleting requires explicit user instruction.

**Spec language**
- Define whether the agent can inspect all mail, only selected threads, or only search results matching a query.
- Require the agent to identify sender, date, subject, and thread context for important email-derived claims.
- Treat email as contextual evidence unless the sender or thread is explicitly authoritative.

## OpenAI Tools

**Best uses**
- File analysis, retrieval, reasoning, structured drafting, artifact creation, code execution, data analysis, browsing/current verification, image generation, and evaluation.

**Default permissions**
- Allow analysis and drafting.
- Require confirmation before generating external-facing artifacts where organizational approval is needed.
- Require current verification for facts that may have changed.

**Spec language**
- Define which tools the agent may use automatically and which require confirmation.
- Define whether code execution is allowed and for what file types or analyses.
- Define whether web browsing is allowed, required for current facts, or disallowed.
- Define artifact formats, such as markdown, docx, pptx, xlsx, csv, or pdf, only when relevant.

## GitHub

**Best uses**
- Repository context, issues, pull requests, code review, release notes, bug reports, engineering plans, test strategy, and implementation handoffs.

**Default permissions**
- Read-only analysis by default.
- Creating or editing issues, comments, pull requests, branches, files, releases, or labels requires explicit authorization.

**Spec language**
- Define repositories, organizations, branches, labels, or project boards in scope.
- Distinguish code review, issue triage, release planning, and implementation support.
- Require the agent to cite repo paths, issue numbers, PR numbers, or commit references when available.
- Require the agent to separate blocking risks from non-blocking suggestions.

## Internal Knowledge Bases

**Best uses**
- Organizational history, prior decisions, reusable context, internal terminology, stakeholder preferences, project context, and operational knowledge.

**Default permissions**
- Read/retrieve only.
- Do not save or modify internal memory/knowledge unless the user explicitly asks and the action is appropriate.

**Spec language**
- Define what counts as authoritative internal knowledge.
- Require the agent to avoid over-relying on uncited or stale memory for current policies or high-stakes claims.
- Require the agent to say when internal context was unavailable or insufficient.
- Define what should never be stored, such as sensitive personal details, credentials, or unnecessary complaints.
